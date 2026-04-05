import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../db/database.dart';
import '../engine/celtic_calendar.dart';
import '../theme/app_theme.dart';

/// 7-column × 4-row grid of the 28 days in a Celtic month,
/// followed by an "Events this month" list.
class DayGrid extends StatelessWidget {
  final int celticYear;
  final int month;

  /// Celtic day numbers (1-28) that have at least one event — shown with a dot.
  final Set<int> daysWithEvents;

  /// Full month events (unfiltered) — used for the upcoming events list.
  final List<Event> events;

  /// Called when a day cell is tapped. Receives the Gregorian [DateTime].
  final void Function(DateTime date)? onDayTap;

  /// Called when an event row in the list is tapped.
  final void Function(DateTime date)? onEventTap;

  static const _weekdays = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

  const DayGrid({
    super.key,
    required this.celticYear,
    required this.month,
    this.daysWithEvents = const {},
    this.events = const [],
    this.onDayTap,
    this.onEventTap,
  });

  @override
  Widget build(BuildContext context) {
    final c        = context.colors;
    final dates    = gregorianDatesForMonth(celticYear, month);
    final startDow = monthStartWeekday(celticYear);
    final today    = DateTime.now();
    final headers  = List.generate(7, (i) => _weekdays[(startDow + i) % 7]);

    // Sort events by celtic day for the list
    final sortedEvs = [...events]..sort((a, b) =>
        (a.celticDay ?? 0).compareTo(b.celticDay ?? 0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Weekday header row ──────────────────────────────────────────
        Row(
          children: headers
              .map((wd) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(wd,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.cinzel(size: 9, color: c.dim)),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 4),

        // ── 28-day grid ──────────────────────────────────────────────────
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: 56,
            crossAxisSpacing: 0,
            mainAxisSpacing: 0,
          ),
          itemCount: 28,
          itemBuilder: (context, index) {
            final celticDay = index + 1;
            final date = dates[index];
            final isToday = date.year == today.year &&
                date.month == today.month &&
                date.day == today.day;
            final hasEvent = daysWithEvents.contains(celticDay);
            return _DayCell(
              celticDay: celticDay,
              gregDate: date,
              isToday: isToday,
              hasEvent: hasEvent,
              onTap: () => onDayTap?.call(date),
            );
          },
        ),

        const SizedBox(height: 12),

        // ── Events this month ────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Section header
              Container(
                color: c.surface2,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 7),
                child: Text(
                  'EVENTS THIS MONTH',
                  style: AppTextStyles.cinzel(
                      size: 9,
                      color: c.dim,
                      letterSpacing: 1.0,
                      weight: FontWeight.w600),
                ),
              ),
              if (sortedEvs.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text('No events this month',
                      style: AppTextStyles.imFell(
                          size: 13, color: c.dim, italic: true)),
                )
              else
                ...sortedEvs.map((e) {
                  final col = _parseHex(e.color);
                  final isAllDay = e.startMinutes == null;
                  String timeStr;
                  if (isAllDay) {
                    timeStr = 'All day';
                  } else {
                    final sMin = e.startMinutes!;
                    final eMin = sMin + (e.durationMinutes ?? 60);
                    timeStr =
                        '${(sMin ~/ 60).toString().padLeft(2, '0')}:${(sMin % 60).toString().padLeft(2, '0')}'
                        '\u2013${(eMin ~/ 60).toString().padLeft(2, '0')}:${(eMin % 60).toString().padLeft(2, '0')}';
                  }
                  return InkWell(
                    onTap: () => onEventTap?.call(e.gregorianDate),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border(
                            top: BorderSide(color: c.border, width: 0.5)),
                      ),
                      child: Row(
                        children: [
                          // Day badge
                          SizedBox(
                            width: 32,
                            child: Column(
                              children: [
                                Text(
                                  '${e.celticDay ?? ''}',
                                  style: AppTextStyles.cinzel(
                                      size: 15,
                                      weight: FontWeight.w700,
                                      color: c.muted),
                                ),
                                Text(
                                  DateFormat('d/M').format(e.gregorianDate),
                                  style: AppTextStyles.cinzel(
                                      size: 8, color: c.dim),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Color bar
                          Container(
                            width: 3,
                            height: 36,
                            decoration: BoxDecoration(
                              color: col,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Title + time
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(e.title,
                                    style: AppTextStyles.imFell(
                                        size: 14, color: c.text),
                                    overflow: TextOverflow.ellipsis),
                                Text(timeStr,
                                    style: AppTextStyles.cinzel(
                                        size: 10, color: c.dim)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  final int celticDay;
  final DateTime gregDate;
  final bool isToday;
  final bool hasEvent;
  final VoidCallback? onTap;

  const _DayCell({
    required this.celticDay,
    required this.gregDate,
    required this.isToday,
    required this.hasEvent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isToday ? c.todayBg : null,
          border: Border.all(color: c.border, width: 0.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            isToday
                ? Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                        color: c.muted, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text('$celticDay',
                        style: AppTextStyles.cinzel(
                            size: 13,
                            weight: FontWeight.w700,
                            color: c.surface)),
                  )
                : Text('$celticDay',
                    style: AppTextStyles.cinzel(size: 13, color: c.text)),
            const SizedBox(height: 2),
            Container(
              width: 5, height: 5,
              decoration: BoxDecoration(
                color: hasEvent ? c.muted : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _parseHex(String hex) {
  try {
    return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
  } catch (_) {
    return AppColors.dark.gold;
  }
}
