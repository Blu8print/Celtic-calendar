import 'package:drift/drift.dart';

import 'database.dart';

part 'events_dao.g.dart';

@DriftAccessor(tables: [Events])
class EventsDao extends DatabaseAccessor<AppDatabase> with _$EventsDaoMixin {
  EventsDao(super.db);

  /// All events whose [gregorianDate] falls on the given calendar [date].
  Future<List<Event>> getEventsForDay(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return (select(events)
          ..where(
            (e) =>
                e.gregorianDate.isBiggerOrEqualValue(start) &
                e.gregorianDate.isSmallerThanValue(end),
          )
          ..orderBy([(e) => OrderingTerm.asc(e.createdAt)]))
        .get();
  }

  /// All events for a given Celtic month.
  Future<List<Event>> getEventsForMonth(int celticYear, int month) {
    return (select(events)
          ..where(
            (e) =>
                e.celticYear.equals(celticYear) &
                e.celticMonth.equals(month),
          )
          ..orderBy([(e) => OrderingTerm.asc(e.gregorianDate)]))
        .get();
  }

  /// Inserts a new event. Returns the event's ID.
  Future<String> insertEvent(EventsCompanion event) async {
    await into(events).insert(event);
    return event.id.value;
  }

  /// Replaces an existing event row entirely.
  Future<bool> updateEvent(Event event) {
    return update(events).replace(event);
  }

  /// Deletes the event with the given [id]. Returns the number of rows deleted.
  Future<int> deleteEvent(String id) {
    return (delete(events)..where((e) => e.id.equals(id))).go();
  }

  /// Deletes every event row. Used by the "Reset App" feature.
  Future<int> deleteAllEvents() => delete(events).go();

  /// Events from [from] day onwards, ordered by date then start time.
  /// All-day events (startMinutes IS NULL) sort before timed events on the same day.
  Future<List<Event>> getUpcomingEvents(DateTime from, {int limit = 10}) {
    final start = DateTime(from.year, from.month, from.day);
    return (select(events)
          ..where((e) => e.gregorianDate.isBiggerOrEqualValue(start))
          ..orderBy([
            (e) => OrderingTerm.asc(e.gregorianDate),
            (e) => OrderingTerm.asc(e.startMinutes),
          ])
          ..limit(limit))
        .get();
  }

  /// Returns all events that have not yet been pushed to Google Calendar.
  Future<List<Event>> getUnsyncedEvents() {
    return (select(events)
          ..where((e) => e.syncedToGoogle.equals(false)))
        .get();
  }

  /// Marks an event as synced and stores the Google Calendar event ID.
  Future<void> markSynced(String id, String googleEventId) async {
    await (update(events)..where((e) => e.id.equals(id))).write(
      EventsCompanion(
        googleEventId: Value(googleEventId),
        syncedToGoogle: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Watch events for a day (reactive stream).
  Stream<List<Event>> watchEventsForDay(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return (select(events)
          ..where(
            (e) =>
                e.gregorianDate.isBiggerOrEqualValue(start) &
                e.gregorianDate.isSmallerThanValue(end),
          )
          ..orderBy([(e) => OrderingTerm.asc(e.createdAt)]))
        .watch();
  }

  /// Reactive stream of all events for a Celtic month, ordered by date.
  /// Used to drive dot indicators and the upcoming events panel.
  Stream<List<Event>> watchEventsForMonth(int celticYear, int month) {
    return (select(events)
          ..where(
            (e) =>
                e.celticYear.equals(celticYear) &
                e.celticMonth.equals(month),
          )
          ..orderBy([(e) => OrderingTerm.asc(e.gregorianDate)]))
        .watch();
  }

  /// Inserts a Google Calendar event if new, or updates it if the
  /// [googleEventId] already exists in the DB.
  Future<void> upsertGoogleEvent(EventsCompanion event) async {
    final googleId = event.googleEventId.value;
    if (googleId == null) return;

    final existing = await (select(events)
          ..where((e) => e.googleEventId.equals(googleId)))
        .getSingleOrNull();

    if (existing == null) {
      await into(events).insert(event);
    } else {
      // Do not overwrite the local primary key — only update content fields.
      await (update(events)..where((e) => e.googleEventId.equals(googleId)))
          .write(EventsCompanion(
        celticYear: event.celticYear,
        celticMonth: event.celticMonth,
        celticDay: event.celticDay,
        title: event.title,
        description: event.description,
        color: event.color,
        gregorianDate: event.gregorianDate,
        updatedAt: event.updatedAt,
        syncedToGoogle: event.syncedToGoogle,
        googleEventId: event.googleEventId,
        reminders: event.reminders,
      ));
    }
  }

  /// Removes Google-sourced events (googleEventId != null) for [celticYear]
  /// whose googleEventId is NOT in [activeIds].
  /// Called after a pull to clean up events deleted in Google Calendar.
  Future<void> removeStaleGoogleEvents(
      int celticYear, Set<String> activeIds) async {
    final yearStart = DateTime(celticYear, 12, 24);
    final yearEnd = DateTime(celticYear + 1, 12, 23, 23, 59, 59);
    await (delete(events)
          ..where(
            (e) =>
                e.googleEventId.isNotNull() &
                e.gregorianDate.isBetweenValues(yearStart, yearEnd) &
                e.googleEventId.isNotIn(activeIds),
          ))
        .go();
  }

  /// All events for a Celtic year, ordered by date. Used by schedule view.
  Stream<List<Event>> watchEventsForYear(int celticYear) {
    return (select(events)
          ..where((e) => e.celticYear.equals(celticYear))
          ..orderBy([(e) => OrderingTerm.asc(e.gregorianDate)]))
        .watch();
  }

  /// Looks up a single event by its Google Calendar event ID.
  Future<Event?> getEventByGoogleId(String googleId) {
    return (select(events)
          ..where((e) => e.googleEventId.equals(googleId)))
        .getSingleOrNull();
  }

  /// All events belonging to the same recurring series.
  Future<List<Event>> getEventsByRecurrenceId(String recurrenceId) {
    return (select(events)
          ..where((e) => e.recurrenceId.equals(recurrenceId)))
        .get();
  }

  /// Reactive stream of all events in a Gregorian calendar year (Jan 1 – Dec 31).
  Stream<List<Event>> watchEventsForGregorianYear(int year) {
    final start = DateTime(year, 1, 1);
    final end   = DateTime(year + 1, 1, 1);
    return (select(events)
          ..where((e) =>
              e.gregorianDate.isBiggerOrEqualValue(start) &
              e.gregorianDate.isSmallerThanValue(end))
          ..orderBy([(e) => OrderingTerm.asc(e.gregorianDate)]))
        .watch();
  }

  /// Reactive stream of Year Day / Leap Day events for a Celtic year.
  Stream<List<Event>> watchYearDayEvents(int celticYear) {
    return (select(events)
          ..where(
            (e) => e.celticYear.equals(celticYear) & e.celticMonth.isNull(),
          )
          ..orderBy([(e) => OrderingTerm.asc(e.gregorianDate)]))
        .watch();
  }
}
