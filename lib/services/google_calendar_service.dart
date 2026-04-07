/// Google Calendar sync service.
///
/// Architecture:
///   All communication is direct device <-> Google API - no intermediate server.
///   Uses AppAuth (system browser OAuth) - no SHA-1, no google-services.json.
///   Tokens are persisted in the device secure storage across restarts.
///   The app works fully offline; sync is optional.
///
/// Setup: see GOOGLE_SETUP.md - create an iOS OAuth client ID (no SHA-1 needed).

import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../db/database.dart';
import '../db/events_dao.dart';
import '../engine/celtic_calendar.dart';

class GoogleCalendarService extends ChangeNotifier {
  // ── OAuth config ────────────────────────────────────────────────────────────
  // The client ID is intentionally embedded in the app binary — PKCE flows
  // treat the client ID as public. Security rests on app signing (Android)
  // and bundle ID (iOS), not client ID secrecy. See GOOGLE_SETUP.md.
  static const _clientId =
      '994680507449-c3pkq1is9vpo7ioohnu5r6j56b4hi3ne.apps.googleusercontent.com';
  static const _redirectUri =
      'com.googleusercontent.apps.994680507449-c3pkq1is9vpo7ioohnu5r6j56b4hi3ne:/oauth2redirect';
  static const _scopes = ['https://www.googleapis.com/auth/calendar'];

  static const _kAccessToken  = 'gcal_access_token';
  static const _kRefreshToken = 'gcal_refresh_token';
  static const _kUserEmail    = 'gcal_user_email';
  static const _kLastSyncTime = 'gcal_last_sync_time';
  static const _syncCooldown  = Duration(minutes: 15);

  final EventsDao _dao;
  final _uuid      = const Uuid();
  final _appAuth   = const FlutterAppAuth();
  final _storage   = const FlutterSecureStorage();
  // Single persistent client — avoids leaking a connection pool per API call.
  final _httpClient = http.Client();

  String?   _accessToken;
  String?   _refreshToken;
  String?   _userEmail;
  bool      _isSyncing = false;
  String?   _lastError;
  DateTime? _lastSyncTime;
  int       _lastSyncCount = 0;
  bool?     _lastSyncSuccess;

  GoogleCalendarService(this._dao) {
    _loadStoredTokens();
  }

  @override
  void dispose() {
    _httpClient.close();
    super.dispose();
  }

  // ─── State accessors ───────────────────────────────────────────────────────

  bool      get isSignedIn      => _accessToken != null;
  bool      get isSyncing       => _isSyncing;
  String?   get lastError       => _lastError;
  String?   get userEmail       => _userEmail;
  DateTime? get lastSyncTime    => _lastSyncTime;
  int       get lastSyncCount   => _lastSyncCount;
  bool?     get lastSyncSuccess => _lastSyncSuccess;

  // ─── Auth ──────────────────────────────────────────────────────────────────

  /// Opens the system browser (Chrome Custom Tab) for Google sign-in.
  /// No SHA-1, no google-services.json — just a standard web OAuth flow.
  Future<void> signIn() async {
    try {
      _lastError = null;
      final result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          _clientId,
          _redirectUri,
          discoveryUrl:
              'https://accounts.google.com/.well-known/openid-configuration',
          scopes: _scopes,
          promptValues: ['select_account'],
        ),
      );
      _accessToken  = result.accessToken;
      _refreshToken = result.refreshToken;
      _userEmail    = _extractEmail(result.idToken);

      await _storage.write(key: _kAccessToken,  value: _accessToken);
      await _storage.write(key: _kRefreshToken, value: _refreshToken);
      if (_userEmail != null) {
        await _storage.write(key: _kUserEmail, value: _userEmail);
      }

      notifyListeners();
      syncYear(celticYearOf(DateTime.now())); // auto-sync on sign-in
    } catch (e) {
      _lastError = _humaniseError(e.toString());
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _accessToken  = null;
    _refreshToken = null;
    _userEmail    = null;
    await _storage.deleteAll();
    notifyListeners();
  }

  // ─── Authenticated HTTP client ─────────────────────────────────────────────

  /// Refreshes the access token once and returns a [gcal.CalendarApi] backed
  /// by the single persistent [_httpClient]. Callers that run a full sync
  /// should obtain the api once and pass it through — do not call this per
  /// event to avoid redundant refresh round-trips.
  Future<gcal.CalendarApi?> _calendarApi() async {
    if (_accessToken == null) return null;

    // Refresh the access token if we have a refresh token.
    if (_refreshToken != null) {
      try {
        final refreshed = await _appAuth.token(
          TokenRequest(
            _clientId,
            _redirectUri,
            discoveryUrl:
                'https://accounts.google.com/.well-known/openid-configuration',
            refreshToken: _refreshToken,
            scopes: _scopes,
          ),
        );
        if (refreshed.accessToken != null) {
          _accessToken = refreshed.accessToken;
          await _storage.write(key: _kAccessToken, value: _accessToken);
        }
      } catch (_) {
        // Ignore — try with existing token.
      }
    }

    try {
      return gcal.CalendarApi(_AuthClient(_accessToken!, _httpClient));
    } catch (e) {
      _lastError = _humaniseError(e.toString());
      notifyListeners();
      return null;
    }
  }

  // ─── Pull from Google Calendar ─────────────────────────────────────────────

  /// Fetches all Google Calendar events for the given Celtic year, upserts
  /// them into the local DB page-by-page, and removes any deleted in Google.
  /// Returns the number of events upserted. Fails silently if offline.
  Future<int> pullYear(int celticYear, [gcal.CalendarApi? api]) async {
    api ??= await _calendarApi();
    if (api == null) return 0;

    final timeMin = DateTime(celticYear, 12, 24).toUtc();
    final timeMax = DateTime(celticYear + 1, 12, 24).toUtc();

    final fetchedIds = <String>{};
    int count = 0;

    try {
      String? pageToken;
      do {
        final result = await api.events.list(
          'primary',
          timeMin: timeMin,
          timeMax: timeMax,
          singleEvents: true,
          orderBy: 'startTime',
          pageToken: pageToken,
        );
        // Process and upsert each page immediately to avoid accumulating
        // the full year of events in memory before writing.
        for (final gcal.Event gcEvent in result.items ?? const <gcal.Event>[]) {
          final googleId = gcEvent.id;
          if (googleId == null) continue;
          final date = _eventDate(gcEvent);
          if (date == null) continue;

          final celtic = gregorianToCeltic(date);
          fetchedIds.add(googleId);

          // Extract start time / duration for timed events.
          int? startMinutes;
          int? durationMinutes;
          if (gcEvent.start?.dateTime != null) {
            final s = gcEvent.start!.dateTime!.toLocal();
            startMinutes = s.hour * 60 + s.minute;
            final e = gcEvent.end?.dateTime?.toLocal();
            if (e != null) durationMinutes = e.difference(s).inMinutes;
          }

          // Attendees — exclude self to avoid resending your own invite.
          String? attendees;
          final att = gcEvent.attendees
              ?.where((a) => a.self != true)
              .map((a) => a.email ?? '')
              .where((e) => e.isNotEmpty)
              .toList();
          if (att != null && att.isNotEmpty) attendees = jsonEncode(att);

          final companion = EventsCompanion(
            id:               Value(_uuid.v4()),
            celticYear:       Value(celtic.celticYear),
            celticMonth:      Value(celtic.month),
            celticDay:        Value(celtic.day),
            title:            Value(gcEvent.summary ?? '(no title)'),
            description:      Value(gcEvent.description ?? ''),
            color:            Value(_gcalColorToHex(gcEvent.colorId)),
            gregorianDate:    Value(date),
            createdAt:        Value(gcEvent.created?.toLocal() ?? DateTime.now()),
            updatedAt:        Value(gcEvent.updated?.toLocal() ?? DateTime.now()),
            googleEventId:    Value(googleId),
            syncedToGoogle:   const Value(true),
            startMinutes:     Value(startMinutes),
            durationMinutes:  Value(durationMinutes),
            attendees:        Value(attendees),
            location:         Value(gcEvent.location),
          );

          await _dao.upsertGoogleEvent(companion);
          count++;
        }
        pageToken = result.nextPageToken;
      } while (pageToken != null);
    } catch (e) {
      debugPrint('Google Calendar pull failed: $e');
      _lastError = _humaniseError(e.toString());
      notifyListeners();
      return count;
    }

    await _dao.removeStaleGoogleEvents(celticYear, fetchedIds);
    return count;
  }

  // ─── Write to Google Calendar ──────────────────────────────────────────────

  Future<void> pushEvent(Event event, [gcal.CalendarApi? api]) async {
    api ??= await _calendarApi();
    if (api == null) return;

    // Build start/end: timed event uses dateTime, all-day uses date.
    final gcal.EventDateTime startDt;
    final gcal.EventDateTime endDt;
    if (event.startMinutes != null) {
      // gregorianDate is stored as UTC midnight of the LOCAL calendar date.
      // Convert back to local to recover the correct calendar date, then add
      // wall-clock minutes so the event lands at the right local time.
      final localDate = event.gregorianDate.toLocal();
      final localMidnight = DateTime(localDate.year, localDate.month, localDate.day);
      final start = localMidnight.add(Duration(minutes: event.startMinutes!));
      final end   = start.add(Duration(minutes: event.durationMinutes ?? 60));
      startDt = gcal.EventDateTime(dateTime: start.toUtc());
      endDt   = gcal.EventDateTime(dateTime: end.toUtc());
    } else {
      startDt = gcal.EventDateTime(date: _dateOnly(event.gregorianDate));
      endDt   = gcal.EventDateTime(date: _dateOnly(event.gregorianDate.add(const Duration(days: 1))));
    }

    // Attendees.
    List<gcal.EventAttendee>? attendees;
    if (event.attendees != null) {
      try {
        final emails = (jsonDecode(event.attendees!) as List).cast<String>();
        attendees = emails.map((e) => gcal.EventAttendee(email: e)).toList();
      } catch (e) {
        debugPrint('Failed to parse attendees for event ${event.id}: $e');
      }
    }

    final gcalEvent = gcal.Event(
      summary:     event.title,
      description: event.description.isEmpty ? null : event.description,
      location:    event.location,
      start:       startDt,
      end:         endDt,
      colorId:     _hexToGcalColorId(event.color),
      attendees:   attendees,
    );

    try {
      final created = await api.events.insert(gcalEvent, 'primary');
      if (created.id != null) {
        await _dao.markSynced(event.id, created.id!);
      }
    } catch (e) {
      debugPrint('Google Calendar push failed for ${event.id}: $e');
    }
  }

  // ─── Full bidirectional sync ───────────────────────────────────────────────

  Future<void> syncYear(int celticYear) async {
    if (!isSignedIn || _isSyncing) return;
    _isSyncing = true;
    _lastError = null;
    notifyListeners();

    try {
      // Obtain API (and refresh token) once for the entire sync cycle.
      final api = await _calendarApi();
      if (api != null) {
        _lastSyncCount = await pullYear(celticYear, api);
        await syncPendingEvents(api);
      }
      _lastSyncSuccess = _lastError == null;
    } catch (e) {
      _lastError = _humaniseError(e.toString());
      _lastSyncSuccess = false;
    } finally {
      _isSyncing = false;
      _lastSyncTime = DateTime.now();
      // Persist so the cooldown survives app restarts.
      await _storage.write(
        key: _kLastSyncTime,
        value: _lastSyncTime!.millisecondsSinceEpoch.toString(),
      );
      notifyListeners();
    }
  }

  Future<void> backgroundSync(int celticYear) async {
    if (!isSignedIn) return;
    final now = DateTime.now();
    if (_lastSyncTime != null &&
        now.difference(_lastSyncTime!) < _syncCooldown) {
      return;
    }
    await syncYear(celticYear);
  }

  /// Syncs immediately, bypassing the 15-minute cooldown.
  /// Use for manual sync button triggers.
  Future<void> syncNow(int celticYear) => syncYear(celticYear);

  Future<void> syncPendingEvents([gcal.CalendarApi? api]) async {
    final unsynced = await _dao.getUnsyncedEvents();
    for (final event in unsynced) {
      await pushEvent(event, api);
    }
  }

  // ─── Internal helpers ──────────────────────────────────────────────────────

  Future<void> _loadStoredTokens() async {
    _accessToken  = await _storage.read(key: _kAccessToken);
    _refreshToken = await _storage.read(key: _kRefreshToken);
    _userEmail    = await _storage.read(key: _kUserEmail);
    final rawMs   = await _storage.read(key: _kLastSyncTime);
    if (rawMs != null) {
      final ms = int.tryParse(rawMs);
      if (ms != null) _lastSyncTime = DateTime.fromMillisecondsSinceEpoch(ms);
    }
    if (_accessToken != null) notifyListeners();
  }

  /// Decodes the email claim from a JWT ID token (no signature check needed —
  /// the token was just issued by Google and we trust the response).
  String? _extractEmail(String? idToken) {
    if (idToken == null) return null;
    try {
      final parts = idToken.split('.');
      if (parts.length < 2) return null;
      var payload = parts[1];
      payload += '=' * ((4 - payload.length % 4) % 4);
      final json = utf8.decode(
        base64Url.decode(payload.replaceAll('-', '+').replaceAll('_', '/')),
      );
      final map = jsonDecode(json) as Map<String, dynamic>;
      return map['email'] as String?;
    } catch (_) {
      return null;
    }
  }

  String _humaniseError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('403') || lower.contains('insufficientpermissions') ||
        lower.contains('forbidden')) {
      return 'Calendar access denied. Sign out and sign in again to grant calendar permissions.';
    }
    if (lower.contains('401') || lower.contains('invalid_token') ||
        lower.contains('unauthenticated')) {
      return 'Session expired. Please sign out and sign in again.';
    }
    if (lower.contains('socketexception') || lower.contains('network') ||
        lower.contains('host lookup') || lower.contains('connection refused')) {
      return 'No internet connection. Will retry on next sync.';
    }
    if (lower.contains('timeoutexception') || lower.contains('timed out')) {
      return 'Request timed out. Check your connection and try again.';
    }
    if (lower.contains('null check operator')) {
      return 'Authentication failed. Please sign out and sign in again.';
    }
    return raw.length > 120 ? '${raw.substring(0, 120)}...' : raw;
  }

  DateTime? _eventDate(gcal.Event gcEvent) {
    final dt = gcEvent.start?.dateTime?.toLocal();
    // Use UTC midnight of the LOCAL calendar date so the stored timestamp
    // never straddles day boundaries regardless of the device timezone.
    if (dt != null) return DateTime.utc(dt.year, dt.month, dt.day);
    final d = gcEvent.start?.date;
    if (d != null) return DateTime.utc(d.year, d.month, d.day);
    return null;
  }

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  String _gcalColorToHex(String? colorId) {
    switch (colorId) {
      case '1':  return '#7986cb'; // Lavender
      case '2':  return '#33b679'; // Sage
      case '3':  return '#8e24aa'; // Grape
      case '4':  return '#e67c73'; // Flamingo
      case '5':  return '#f6bf26'; // Banana
      case '6':  return '#f4511e'; // Tangerine
      case '7':  return '#039be5'; // Peacock
      case '8':  return '#3f51b5'; // Blueberry
      case '9':  return '#0b8043'; // Basil
      case '10': return '#d50000'; // Tomato
      default:   return '#c9a84c'; // App gold (default)
    }
  }

  String? _hexToGcalColorId(String hex) {
    switch (hex.toLowerCase().replaceAll('#', '')) {
      case '7986cb': return '1';
      case '33b679': return '2';
      case '8e24aa': return '3';
      case 'e67c73': return '4';
      case 'f6bf26': return '5';
      case 'c9a84c': return '5'; // App gold → Banana (closest)
      case 'e8cc88': return '5';
      case 'f4511e': return '6';
      case '039be5': return '7';
      case '3f51b5': return '8';
      case '0b8043': return '9';
      case 'd50000': return '10';
      default: return null;
    }
  }
}

// ─── Internal authenticated HTTP client ───────────────────────────────────────

class _AuthClient extends http.BaseClient {
  final String _accessToken;
  final http.Client _inner;

  _AuthClient(this._accessToken, this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_accessToken';
    return _inner.send(request).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw TimeoutException(
        'Google Calendar request timed out after 30 s',
      ),
    );
  }

  @override
  void close() {
    // Do NOT close _inner here — it is the shared _httpClient owned by
    // GoogleCalendarService and must outlive individual API calls.
    super.close();
  }
}
