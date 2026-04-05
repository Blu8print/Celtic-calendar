/// Google Calendar sync service.
///
/// Architecture:
///   All communication is direct device <-> Google API - no intermediate server.
///   Uses AppAuth (system browser OAuth) - no SHA-1, no google-services.json.
///   Tokens are persisted in the device secure storage across restarts.
///   The app works fully offline; sync is optional.
///
/// Setup: see GOOGLE_SETUP.md - create an iOS OAuth client ID (no SHA-1 needed).

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
  // Create an iOS OAuth client in Google Cloud Console (see GOOGLE_SETUP.md).
  // Client ID: the full string ending in .apps.googleusercontent.com
  // e.g. 123456789-abcdef.apps.googleusercontent.com
  static const _clientId =
      '994680507449-c3pkq1is9vpo7ioohnu5r6j56b4hi3ne.apps.googleusercontent.com';
  static const _redirectUri =
      'com.googleusercontent.apps.994680507449-c3pkq1is9vpo7ioohnu5r6j56b4hi3ne:/oauth2redirect';
  static const _scopes = ['https://www.googleapis.com/auth/calendar'];

  static const _kAccessToken  = 'gcal_access_token';
  static const _kRefreshToken = 'gcal_refresh_token';
  static const _kUserEmail    = 'gcal_user_email';
  static const _syncCooldown  = Duration(minutes: 15);

  final EventsDao _dao;
  final _uuid    = const Uuid();
  final _appAuth = const FlutterAppAuth();
  final _storage = const FlutterSecureStorage();

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
      return gcal.CalendarApi(_AuthClient(_accessToken!, http.Client()));
    } catch (e) {
      _lastError = _humaniseError(e.toString());
      notifyListeners();
      return null;
    }
  }

  // ─── Pull from Google Calendar ─────────────────────────────────────────────

  /// Fetches all Google Calendar events for the given Celtic year, upserts
  /// them into the local DB, and removes any deleted in Google.
  /// Returns the number of events upserted. Fails silently if offline.
  Future<int> pullYear(int celticYear) async {
    final api = await _calendarApi();
    if (api == null) return 0;

    final timeMin = DateTime(celticYear, 12, 24).toUtc();
    final timeMax = DateTime(celticYear + 1, 12, 24).toUtc();

    List<gcal.Event> items = [];
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
        items.addAll(result.items ?? []);
        pageToken = result.nextPageToken;
      } while (pageToken != null);
    } catch (e) {
      debugPrint('Google Calendar pull failed: $e');
      _lastError = _humaniseError(e.toString());
      notifyListeners();
      return 0;
    }

    final fetchedIds = <String>{};
    int count = 0;

    for (final gcEvent in items) {
      final googleId = gcEvent.id;
      if (googleId == null) continue;
      final date = _eventDate(gcEvent);
      if (date == null) continue;

      final celtic = gregorianToCeltic(date);
      fetchedIds.add(googleId);

      final companion = EventsCompanion(
        id:             Value(_uuid.v4()),
        celticYear:     Value(celtic.celticYear),
        celticMonth:    Value(celtic.month),
        celticDay:      Value(celtic.day),
        title:          Value(gcEvent.summary ?? '(no title)'),
        description:    Value(gcEvent.description ?? ''),
        color:          Value(_gcalColorToHex(gcEvent.colorId)),
        gregorianDate:  Value(date),
        createdAt:      Value(gcEvent.created?.toLocal() ?? DateTime.now()),
        updatedAt:      Value(gcEvent.updated?.toLocal() ?? DateTime.now()),
        googleEventId:  Value(googleId),
        syncedToGoogle: const Value(true),
      );

      await _dao.upsertGoogleEvent(companion);
      count++;
    }

    await _dao.removeStaleGoogleEvents(celticYear, fetchedIds);
    return count;
  }

  // ─── Write to Google Calendar ──────────────────────────────────────────────

  Future<void> pushEvent(Event event) async {
    final api = await _calendarApi();
    if (api == null) return;

    final gcalEvent = gcal.Event(
      summary: event.title,
      description: event.description.isEmpty ? null : event.description,
      start: gcal.EventDateTime(
        date: _dateOnly(event.gregorianDate),
        timeZone: 'UTC',
      ),
      end: gcal.EventDateTime(
        date: _dateOnly(event.gregorianDate.add(const Duration(days: 1))),
        timeZone: 'UTC',
      ),
      colorId: _hexToGcalColorId(event.color),
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
      _lastSyncCount = await pullYear(celticYear);
      await syncPendingEvents();
      _lastSyncSuccess = _lastError == null;
    } catch (e) {
      _lastError = _humaniseError(e.toString());
      _lastSyncSuccess = false;
    } finally {
      _isSyncing = false;
      _lastSyncTime = DateTime.now();
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

  Future<void> syncPendingEvents() async {
    final unsynced = await _dao.getUnsyncedEvents();
    for (final event in unsynced) {
      await pushEvent(event);
    }
  }

  // ─── Internal helpers ──────────────────────────────────────────────────────

  Future<void> _loadStoredTokens() async {
    _accessToken  = await _storage.read(key: _kAccessToken);
    _refreshToken = await _storage.read(key: _kRefreshToken);
    _userEmail    = await _storage.read(key: _kUserEmail);
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
    if (lower.contains('null check operator')) {
      return 'Authentication failed. Please sign out and sign in again.';
    }
    return raw.length > 120 ? '${raw.substring(0, 120)}...' : raw;
  }

  DateTime? _eventDate(gcal.Event gcEvent) {
    final dt = gcEvent.start?.dateTime?.toLocal();
    if (dt != null) return DateTime(dt.year, dt.month, dt.day);
    final d = gcEvent.start?.date;
    if (d != null) return DateTime(d.year, d.month, d.day);
    return null;
  }

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  String _gcalColorToHex(String? colorId) {
    switch (colorId) {
      case '5': return '#c9a84c';
      case '2': return '#33b679';
      case '9': return '#0b8043';
      default:  return '#c9a84c';
    }
  }

  String? _hexToGcalColorId(String hex) {
    if (hex.toLowerCase().contains('c9a84c') ||
        hex.toLowerCase().contains('e8cc88')) return '5';
    return null;
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
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
