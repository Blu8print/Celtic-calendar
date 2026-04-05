import 'package:flutter/material.dart';

import '../engine/celtic_calendar.dart';
import '../theme/app_theme.dart';

/// 7-column × 4-row grid of the 28 days in a Celtic month.
class DayGrid extends StatelessWidget {
  final int celticYear;
  final int month;

  /// Celtic day numbers (1-28) that have at least one event — shown with a gold dot.
  final Set<int> daysWithEvents;

  /// Called when a day cell is tapped. Receives the Gregorian [DateTime] of that cell.
  final void Function(DateTime date)? onDayTap;

  static const _weekdays = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

  const DayGrid({
    super.key,
    required this.celticYear,
    required this.month,
    this.daysWithEvents = const {},
    this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dates = gregorianDatesForMonth(celticYear, month);
    final startDow = monthStartWeekday(celticYear);
    final today = DateTime.now();

    final headers = List.generate(7, (i) => _weekdays[(startDow + i) % 7]);

    return Column(
      children: [
        Row(
          children: headers
              .map(
                (wd) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      wd,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.cinzel(size: 9, color: c.dim),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: 44,
            crossAxisSpacing: 1,
            mainAxisSpacing: 1,
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
              isToday: isToday,
              hasEvent: hasEvent,
              onTap: () => onDayTap?.call(date),
            );
          },
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  final int celticDay;
  final bool isToday;
  final bool hasEvent;
  final VoidCallback? onTap;

  const _DayCell({
    required this.celticDay,
    required this.isToday,
    required this.hasEvent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: isToday ? c.todayBg : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: isToday ? Border.all(color: c.gold, width: 1) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$celticDay',
              style: AppTextStyles.cinzel(
                size: 13,
                color: isToday ? c.gold2 : c.text,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: hasEvent ? c.gold : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
