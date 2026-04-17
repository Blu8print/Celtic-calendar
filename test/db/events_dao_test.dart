import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roots_calendar/db/database.dart';
import 'package:roots_calendar/db/events_dao.dart';

/// Opens an in-memory Drift database — no file I/O, fully isolated per test.
AppDatabase _openTestDb() {
  return AppDatabase.forTesting(NativeDatabase.memory());
}

/// Convenience: builds a minimal [EventsCompanion] with required fields only.
EventsCompanion _event({
  required String id,
  required String title,
  required DateTime gregorianDate,
  int celticYear = 2024,
  int? celticMonth = 1,
  int? celticDay = 1,
}) {
  return EventsCompanion.insert(
    id: id,
    title: title,
    gregorianDate: gregorianDate,
    celticYear: celticYear,
    celticMonth: Value(celticMonth),
    celticDay: Value(celticDay),
  );
}

void main() {
  late AppDatabase db;
  late EventsDao dao;

  setUp(() {
    db  = _openTestDb();
    dao = db.eventsDao;
  });

  tearDown(() async => db.close());

  // ── insertEvent / getEventsForDay ─────────────────────────────────────────

  group('insertEvent + getEventsForDay', () {
    test('inserted event is returned for its date', () async {
      final date = DateTime.utc(2025, 1, 10);
      await dao.insertEvent(_event(id: 'a', title: 'Test', gregorianDate: date));

      final events = await dao.getEventsForDay(date);
      expect(events.length, 1);
      expect(events.first.title, 'Test');
    });

    test('event is not returned for a different date', () async {
      await dao.insertEvent(_event(
        id: 'b', title: 'Other', gregorianDate: DateTime.utc(2025, 1, 11)));

      final events = await dao.getEventsForDay(DateTime.utc(2025, 1, 10));
      expect(events, isEmpty);
    });

    test('multiple events on the same day are all returned', () async {
      final date = DateTime.utc(2025, 2, 1);
      await dao.insertEvent(_event(id: 'c1', title: 'A', gregorianDate: date));
      await dao.insertEvent(_event(id: 'c2', title: 'B', gregorianDate: date));

      final events = await dao.getEventsForDay(date);
      expect(events.length, 2);
    });
  });

  // ── updateEvent ───────────────────────────────────────────────────────────

  group('updateEvent', () {
    test('updated title is reflected in subsequent reads', () async {
      final date = DateTime.utc(2025, 3, 5);
      await dao.insertEvent(_event(id: 'd', title: 'Old', gregorianDate: date));

      final existing = (await dao.getEventsForDay(date)).first;
      await dao.updateEvent(existing.copyWith(title: 'New'));

      final updated = (await dao.getEventsForDay(date)).first;
      expect(updated.title, 'New');
    });
  });

  // ── deleteEvent ───────────────────────────────────────────────────────────

  group('deleteEvent', () {
    test('deleted event is no longer returned', () async {
      final date = DateTime.utc(2025, 4, 1);
      await dao.insertEvent(_event(id: 'e', title: 'Gone', gregorianDate: date));

      await dao.deleteEvent('e');
      expect(await dao.getEventsForDay(date), isEmpty);
    });

    test('deleting a non-existent event returns 0', () async {
      final rows = await dao.deleteEvent('does-not-exist');
      expect(rows, 0);
    });
  });

  // ── getEventsForMonth ─────────────────────────────────────────────────────

  group('getEventsForMonth', () {
    test('returns events in the correct Celtic month', () async {
      await dao.insertEvent(_event(
        id: 'f1', title: 'Month1', gregorianDate: DateTime.utc(2025, 1, 1),
        celticYear: 2024, celticMonth: 1, celticDay: 1,
      ));
      await dao.insertEvent(_event(
        id: 'f2', title: 'Month2', gregorianDate: DateTime.utc(2025, 2, 1),
        celticYear: 2024, celticMonth: 2, celticDay: 1,
      ));

      final month1 = await dao.getEventsForMonth(2024, 1);
      expect(month1.length, 1);
      expect(month1.first.title, 'Month1');
    });
  });

  // ── getUnsyncedEvents / markSynced ────────────────────────────────────────

  group('getUnsyncedEvents + markSynced', () {
    test('newly inserted event is unsynced by default', () async {
      await dao.insertEvent(_event(
        id: 'g', title: 'Unsynced', gregorianDate: DateTime.utc(2025, 5, 1)));

      final unsynced = await dao.getUnsyncedEvents();
      expect(unsynced.any((e) => e.id == 'g'), isTrue);
    });

    test('markSynced removes event from unsynced list', () async {
      await dao.insertEvent(_event(
        id: 'h', title: 'ToSync', gregorianDate: DateTime.utc(2025, 6, 1)));

      await dao.markSynced('h', 'google-id-123');
      final unsynced = await dao.getUnsyncedEvents();
      expect(unsynced.any((e) => e.id == 'h'), isFalse);
    });

    test('markSynced stores the google event id', () async {
      await dao.insertEvent(_event(
        id: 'i', title: 'Sync2', gregorianDate: DateTime.utc(2025, 7, 1)));
      await dao.markSynced('i', 'gid-xyz');

      final event = await dao.getEventByGoogleId('gid-xyz');
      expect(event, isNotNull);
      expect(event!.googleEventId, 'gid-xyz');
      expect(event.syncedToGoogle, isTrue);
    });
  });

  // ── upsertGoogleEvent ─────────────────────────────────────────────────────

  group('upsertGoogleEvent', () {
    test('inserts a new google event', () async {
      await dao.upsertGoogleEvent(_event(
        id: 'j', title: 'GCal Event', gregorianDate: DateTime.utc(2025, 8, 1),
      ).copyWith(googleEventId: const Value('gcal-1')));

      final found = await dao.getEventByGoogleId('gcal-1');
      expect(found, isNotNull);
      expect(found!.title, 'GCal Event');
    });

    test('updates existing google event without changing local id', () async {
      await dao.upsertGoogleEvent(_event(
        id: 'k', title: 'Original', gregorianDate: DateTime.utc(2025, 9, 1),
      ).copyWith(googleEventId: const Value('gcal-2')));

      await dao.upsertGoogleEvent(_event(
        id: 'k-new', title: 'Updated', gregorianDate: DateTime.utc(2025, 9, 1),
      ).copyWith(googleEventId: const Value('gcal-2')));

      final found = await dao.getEventByGoogleId('gcal-2');
      expect(found!.title, 'Updated');
      // Local id must NOT change to 'k-new' — only content fields update.
      expect(found.id, 'k');
    });
  });

  // ── removeStaleGoogleEvents ───────────────────────────────────────────────

  group('removeStaleGoogleEvents', () {
    test('removes google events not in activeIds', () async {
      final date = DateTime.utc(2025, 1, 15);
      await dao.upsertGoogleEvent(_event(
        id: 'l', title: 'Stale', gregorianDate: date,
      ).copyWith(googleEventId: const Value('old-gcal-id')));

      await dao.removeStaleGoogleEvents(2024, {'some-other-id'});
      final found = await dao.getEventByGoogleId('old-gcal-id');
      expect(found, isNull);
    });

    test('keeps google events that are still in activeIds', () async {
      final date = DateTime.utc(2025, 2, 10);
      await dao.upsertGoogleEvent(_event(
        id: 'm', title: 'Active', gregorianDate: date,
      ).copyWith(googleEventId: const Value('active-gcal-id')));

      await dao.removeStaleGoogleEvents(2024, {'active-gcal-id'});
      final found = await dao.getEventByGoogleId('active-gcal-id');
      expect(found, isNotNull);
    });

    test('never removes events without a googleEventId', () async {
      final date = DateTime.utc(2025, 3, 1);
      await dao.insertEvent(_event(id: 'n', title: 'Local Only', gregorianDate: date));

      await dao.removeStaleGoogleEvents(2024, {});
      final events = await dao.getEventsForDay(date);
      expect(events, isNotEmpty);
    });
  });

  // ── deleteAllEvents ───────────────────────────────────────────────────────

  group('deleteAllEvents', () {
    test('removes every event', () async {
      await dao.insertEvent(_event(id: 'o1', title: 'A', gregorianDate: DateTime.utc(2025, 1, 1)));
      await dao.insertEvent(_event(id: 'o2', title: 'B', gregorianDate: DateTime.utc(2025, 2, 1)));

      await dao.deleteAllEvents();
      expect(await dao.getUnsyncedEvents(), isEmpty);
    });
  });
}
