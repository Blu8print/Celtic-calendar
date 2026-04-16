import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import '../db/database.dart' show Event;
import '../db/events_dao.dart';
import '../engine/celtic_calendar.dart';

/// Pushes today's Celtic date, upcoming events, and theme preference to the
/// Android home screen widget. Call this on app startup and whenever events
/// or the theme change.
class HomeWidgetService {
  HomeWidgetService._();

  static const _storage = FlutterSecureStorage();
  static final _dateFmt = DateFormat('d MMM');

  static Future<void> updateTodayWidget(EventsDao dao) async {
    try {
      final now        = DateTime.now();
      final celticDate = gregorianToCeltic(now);

      // Read app theme so the widget can match it instead of the system theme.
      final themeVal = await _storage.read(key: 'app_theme');
      final isLight  = themeVal != 'dark'; // default: light

      // Fetch up to 5 upcoming events from today onwards.
      final upcoming = await dao.getUpcomingEvents(now, limit: 5);

      if (celticDate.isYearDay || celticDate.isLeapDay) {
        await _push(
          celticDay: 0,
          monthName: 'Year Day',
          tree:      '',
          keyword:   '',
          gregDate:  DateFormat('EEE, d MMM').format(now),
          events:    upcoming,
          now:       now,
          isLight:   isLight,
        );
      } else {
        final month = celticMonths[celticDate.month! - 1];
        await _push(
          celticDay: celticDate.day ?? 0,
          monthName: month.name,
          tree:      month.tree,
          keyword:   month.keyword,
          gregDate:  DateFormat('EEE, d MMM').format(now),
          events:    upcoming,
          now:       now,
          isLight:   isLight,
        );
      }

      await HomeWidget.updateWidget(androidName: 'RootsDayWidget');
    } catch (_) {
      // Widget update is best-effort — never crash the app.
    }
  }

  // ─────────────────────────────────────────────────────────────────────────

  static Future<void> _push({
    required int      celticDay,
    required String   monthName,
    required String   tree,
    required String   keyword,
    required String   gregDate,
    required List<Event> events,
    required DateTime now,
    required bool     isLight,
  }) async {
    final saves = <Future>[
      HomeWidget.saveWidgetData<int>   ('celtic_day',        celticDay),
      HomeWidget.saveWidgetData<String>('celtic_month_name', monthName),
      HomeWidget.saveWidgetData<String>('celtic_tree',       tree),
      HomeWidget.saveWidgetData<String>('celtic_keyword',    keyword),
      HomeWidget.saveWidgetData<String>('greg_date',         gregDate),
      HomeWidget.saveWidgetData<bool>  ('is_light',          isLight),
    ];

    // Write slots 1–5; unused slots get empty strings so the widget hides them.
    for (var i = 0; i < 5; i++) {
      final e = events.length > i ? events[i] : null;
      final n = i + 1;
      saves.addAll([
        HomeWidget.saveWidgetData<String>('event_${n}_title',  e?.title ?? ''),
        HomeWidget.saveWidgetData<String>('event_${n}_time',   _timeLabel(e, now)),
        HomeWidget.saveWidgetData<String>('event_${n}_color',  e?.color ?? ''),
        HomeWidget.saveWidgetData<bool>  ('event_${n}_allday', e != null && e.startMinutes == null),
      ]);
    }

    await Future.wait(saves);
  }

  /// Returns a date-aware label: "Today · 14:30", "Tomorrow · All day", "12 Apr · 09:00".
  static String _timeLabel(Event? e, DateTime now) {
    if (e == null) return '';
    final eDate  = DateTime(e.gregorianDate.year, e.gregorianDate.month, e.gregorianDate.day);
    final today  = DateTime(now.year, now.month, now.day);
    final diff   = eDate.difference(today).inDays;
    final prefix = diff == 0 ? 'Today'
        : diff == 1 ? 'Tomorrow'
        : _dateFmt.format(e.gregorianDate);
    final time   = e.startMinutes == null ? 'All day' : _fmt(e.startMinutes!);
    return '$prefix · $time';
  }

  static String _fmt(int min) =>
      '${(min ~/ 60).toString().padLeft(2, '0')}'
      ':${(min % 60).toString().padLeft(2, '0')}';
}
