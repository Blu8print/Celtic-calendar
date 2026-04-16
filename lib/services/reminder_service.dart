import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class ReminderService {
  ReminderService._();

  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId   = 'roots_reminders';
  static const _channelName = 'Event Reminders';

  // ── Init ──────────────────────────────────────────────────────────────────

  static Future<void> init() async {
    tz.initializeTimeZones();
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    } catch (_) {
      // Fallback to UTC if we can't detect timezone
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );
  }

  static Future<void> requestPermissions() async {
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestExactAlarmsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (e) {
      debugPrint('ReminderService.requestPermissions: $e');
    }
  }

  // ── Schedule / Cancel ─────────────────────────────────────────────────────

  /// Schedules notifications for an event given raw field values.
  /// Cancels any existing notifications for this eventId first.
  static Future<void> scheduleForEventData({
    required String eventId,
    required String title,
    required DateTime gregorianDate,
    required int? startMinutes,   // null = all-day
    required List<int> reminders, // minute-offsets before event start
  }) async {
    await cancelForEvent(eventId);
    if (reminders.isEmpty) return;

    // Base fire datetime: timed events use exact start; all-day events use 9 AM.
    final baseHour   = startMinutes != null ? startMinutes ~/ 60 : 9;
    final baseMinute = startMinutes != null ? startMinutes % 60  : 0;
    final baseLocal  = DateTime(
      gregorianDate.year, gregorianDate.month, gregorianDate.day,
      baseHour, baseMinute,
    );

    for (var i = 0; i < reminders.length && i < 5; i++) {
      final fireLocal = baseLocal.subtract(Duration(minutes: reminders[i]));
      if (fireLocal.isBefore(DateTime.now())) continue; // skip past fire times

      final fireTz = tz.TZDateTime.from(fireLocal, tz.local);
      final body   = reminders[i] == 0
          ? 'Starting now'
          : '${_offsetLabel(reminders[i])} before';

      try {
        await _plugin.zonedSchedule(
          _id(eventId, i),
          title,
          body,
          fireTz,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: const DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (e) {
        debugPrint('ReminderService.schedule [$i]: $e');
      }
    }
  }

  static Future<void> cancelForEvent(String eventId) async {
    for (var i = 0; i < 5; i++) {
      await _plugin.cancel(_id(eventId, i));
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static int _id(String eventId, int idx) =>
      (eventId.hashCode.abs() % 1000000) * 10 + idx;

  static String _offsetLabel(int minutes) {
    if (minutes < 60)   return '$minutes min';
    if (minutes < 1440) return '${minutes ~/ 60} hr';
    return '${minutes ~/ 1440} day${minutes ~/ 1440 > 1 ? 's' : ''}';
  }

  // ── JSON helpers ──────────────────────────────────────────────────────────

  static List<int> parseReminders(String? json) {
    if (json == null || json.isEmpty) return [];
    try {
      return (jsonDecode(json) as List).cast<int>();
    } catch (_) {
      return [];
    }
  }

  static String encodeReminders(List<int> reminders) =>
      jsonEncode(reminders);
}
