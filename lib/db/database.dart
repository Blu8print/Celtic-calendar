import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'events_dao.dart';

part 'database.g.dart';

// ─── Events table ─────────────────────────────────────────────────────────────

class Events extends Table {
  /// UUID v4 primary key.
  TextColumn get id => text()();

  /// Celtic year that this event belongs to.
  IntColumn get celticYear => integer()();

  /// Celtic month (1-13). Null for Year Day or Leap Day events.
  IntColumn get celticMonth => integer().nullable()();

  /// Celtic day (1-28). Null for Year Day or Leap Day events.
  IntColumn get celticDay => integer().nullable()();

  TextColumn get title => text()();
  TextColumn get description => text().withDefault(const Constant(''))();

  /// Hex color string, e.g. '#c9a84c'.
  TextColumn get color => text().withDefault(const Constant('#c9a84c'))();

  /// Gregorian date the event falls on (midnight UTC).
  DateTimeColumn get gregorianDate => dateTime()();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  /// The Google Calendar event ID, set after a successful sync push.
  TextColumn get googleEventId => text().nullable()();

  /// Whether this event has been pushed to Google Calendar.
  BoolColumn get syncedToGoogle =>
      boolean().withDefault(const Constant(false))();

  /// Minutes from midnight for the start time (e.g. 9*60 = 540 → 09:00).
  /// Null means the event is all-day.
  IntColumn get startMinutes => integer().nullable()();

  /// Duration in minutes (e.g. 60 = 1 hour). Null when all-day.
  IntColumn get durationMinutes => integer().nullable()();

  /// JSON-encoded list of attendee email strings.
  /// e.g. '["alice@example.com","bob@example.com"]'. Null = no attendees.
  TextColumn get attendees => text().nullable()();

  /// Free-text location string. Null = no location.
  TextColumn get location => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ─── Database ─────────────────────────────────────────────────────────────────

@DriftDatabase(tables: [Events], daos: [EventsDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.database.customStatement(
          'ALTER TABLE events ADD COLUMN start_minutes INTEGER',
        );
        await m.database.customStatement(
          'ALTER TABLE events ADD COLUMN duration_minutes INTEGER',
        );
        await m.database.customStatement(
          'ALTER TABLE events ADD COLUMN attendees TEXT',
        );
        await m.database.customStatement(
          'ALTER TABLE events ADD COLUMN location TEXT',
        );
      }
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'roots_calendar.db'));
    return NativeDatabase.createInBackground(file);
  });
}
