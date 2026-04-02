/// Google Calendar sync service.
///
/// Architecture:
///   • All communication is direct device ↔ Google API — no intermediate server.
///   • The app works fully offline; sync is optional.
///   • Errors are caught and failures queue the event for the next sync attempt.
///
/// Setup required (see GOOGLE_SETUP.md):
///   1. google-services.json   → android/app/
///   2. GoogleService-Info.plist → ios/Runner/
///   3. OAuth 2.0 client IDs configured in Google Cloud Console.

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../db/database.dart';
import '../db/events_dao.dart';
import '../engine/celtic_calendar.dart';

class GoogleCalendarService extends ChangeNotifier {
  static const _scopes = [gcal.CalendarApi.calendarScope];
  static const _syncCooldown = Duration(minutes: 15);

  final EventsDao _dao;
  final _uuid = const Uuid();

  final GoogleSignIn _signIn = GoogleSignIn(scopes: _scopes);

  GoogleSignInAccount? _currentUser;
  bool _isSyncing = false;
  String? _lastError;
  DateTime? _lastSyncTime;
  int _lastSyncCount = 0;

  GoogleCalendarService(this._dao) {
    _signIn.onCurrentUserChanged.listen((account) {
      final wasSignedIn = _currentUser != null;
      _currentUser = account;
      notifyListeners();
      // Auto-sync immediately after sign-in.
      if (!wasSignedIn && account != null) {
        syncYear(celticYearOf(DateTime.now()));
      }
    });
    // Attempt silent sign-in on startup.
    _signIn.signInSilently();
  }

  // ─── State accessors ───────────────────────────────────────────────────────

  bool get isSignedIn => _currentUser != null;
  bool get isSyncing => _isSyncing;
  String? get lastError => _lastError;
  String? get userEmail => _currentUser?.email;
  DateTime? get lastSyncTime => _lastSyncTime;
  int get lastSyncCount => _lastSyncCount;

  // ─── Auth ──────────────────────────────────────────────────────────────────

  Future<void> signIn() async {
    try {
      _lastError = null;
      await _signIn.signIn();
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _signIn.signOut();
    _currentUser = null;
    notifyListeners();
  }

  // ─── Authenticated HTTP client ─────────────────────────────────────────────

  Future<gcal.CalendarApi?> _calendarApi() async {
    if (_currentUser == null) return null;
    try {
      final auth = await _currentUser!.authentication;
      final client = _AuthClient(auth.accessToken!, http.Client());
      return gcal.CalendarApi(client);
    } catch (e) {
      _lastError = 'Auth error: $e';
      notifyListeners();
      return null;
    }
  }

  // ─── Pull from Google Calendar ─────────────────────────────────────────────

  /// Fetches all Google Calendar events for the given Celtic year (Dec 24 of
  /// [celticYear] through Dec 23 of [celticYear]+1), upserts them into the
  /// local DB, and removes any that were deleted in Google.
  ///
  /// Returns the number of events upserted. Fails silently if offline.
  Future<int> pullYear(int celticYear) async {
    final api = await _calendarApi();
    if (api == null) return 0;

    final timeMin = DateTime(celticYear, 12, 24).toUtc();
    final timeMax = DateTime(celticYear + 1, 12, 24).toUtc(); // exclusive

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
      _lastError = 'Pull error: $e';
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
        id: Value(_uuid.v4()),
        celticYear: Value(celtic.celticYear),
        celticMonth: Value(celtic.month),
        celticDay: Value(celtic.day),
        title: Value(gcEvent.summary ?? '(no title)'),
        description: Value(gcEvent.description ?? ''),
        color: Value(_gcalColorToHex(gcEvent.colorId)),
        gregorianDate: Value(date),
        createdAt: Value(gcEvent.created?.toLocal() ?? DateTime.now()),
        updatedAt: Value(gcEvent.updated?.toLocal() ?? DateTime.now()),
        googleEventId: Value(googleId),
        syncedToGoogle: const Value(true),
      );

      await _dao.upsertGoogleEvent(companion);
      count++;
    }

    // Remove local copies of events that were deleted in Google.
    await _dao.removeStaleGoogleEvents(celticYear, fetchedIds);

    return count;
  }

  // ─── Write to Google Calendar ──────────────────────────────────────────────

  /// Pushes a single local [event] to Google Calendar.
  /// On success, marks it as synced in the database.
  /// Fails silently if offline.
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
      // Fail silently — event remains unsynced and will be retried next sync.
      debugPrint('Google Calendar push failed for ${event.id}: $e');
    }
  }

  // ─── Full bidirectional sync ───────────────────────────────────────────────

  /// Full two-way sync for a Celtic year:
  ///   1. Pull events from Google → upsert into local DB.
  ///   2. Push any local events not yet synced to Google.
  ///
  /// Safe to call at any time — no-ops if not signed in or already syncing.
  Future<void> syncYear(int celticYear) async {
    if (!isSignedIn || _isSyncing) return;
    _isSyncing = true;
    _lastError = null;
    notifyListeners();

    try {
      _lastSyncCount = await pullYear(celticYear);
      await syncPendingEvents();
    } finally {
      _isSyncing = false;
      _lastSyncTime = DateTime.now();
      notifyListeners();
    }
  }

  /// Called on app resume. Syncs if signed in and the cooldown has elapsed.
  Future<void> backgroundSync(int celticYear) async {
    if (!isSignedIn) return;
    final now = DateTime.now();
    if (_lastSyncTime != null &&
        now.difference(_lastSyncTime!) < _syncCooldown) {
      return;
    }
    await syncYear(celticYear);
  }

  // ─── Internal helpers ──────────────────────────────────────────────────────

  /// Pushes all unsynced local events to Google Calendar.
  Future<void> syncPendingEvents() async {
    final unsynced = await _dao.getUnsyncedEvents();
    for (final event in unsynced) {
      await pushEvent(event);
    }
  }

  /// Extracts the event's date from either dateTime or all-day date field.
  DateTime? _eventDate(gcal.Event gcEvent) {
    final dt = gcEvent.start?.dateTime?.toLocal();
    if (dt != null) return DateTime(dt.year, dt.month, dt.day);
    final d = gcEvent.start?.date;
    if (d != null) return DateTime(d.year, d.month, d.day);
    return null;
  }

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  /// Maps a Google Calendar colorId back to a hex string.
  String _gcalColorToHex(String? colorId) {
    switch (colorId) {
      case '5': return '#c9a84c'; // banana → gold
      case '2': return '#33b679'; // sage → green
      case '9': return '#0b8043'; // basil → dark green
      default:  return '#c9a84c'; // default gold
    }
  }

  /// Very rough mapping of hex color to Google Calendar's colorId (1-11).
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
