import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../db/database.dart';
import '../theme/app_theme.dart';

/// Displays all 12 Gregorian months for [gregYear] in a scrollable grid,
/// styled to match the dark/light forest theme. Each day cell shows a
/// colored event dot if events exist for that day.
class GregorianYearView extends StatelessWidget {
  final int gregYear;
  final List<Event> events;
  final void Function(DateTime date)? onDayTap;
  final void Function(DateTime date)? onDayLongPress;

  const GregorianYearView({
    super.key,
    required this.gregYear,
    this.events = const [],
    this.onDayTap,
    this.onDayLongPress,
  });

  @override
  Widget build(BuildContext context) {
    // Build a map of date → first event color for quick lookup.
    final eventMap = <DateTime, Color>{};
    for (final e in events) {
      final key = DateTime(
        e.gregorianDate.year,
        e.gregorianDate.month,
        e.gregorianDate.day,
      );
      if (!eventMap.containsKey(key)) {
        try {
          eventMap[key] =
              Color(int.parse('FF${e.color.replaceAll('#', '')}', radix: 16));
        } catch (_) {
          eventMap[key] = AppColors.dark.gold;
        }
      }
    }

    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int m = 1; m <= 12; m++) ...[
            _GregorianMonthCard(
              year: gregYear,
              month: m,
              eventMap: eventMap,
              todayKey: todayKey,
              onDayTap: onDayTap,
              onDayLongPress: onDayLongPress,
            ),
            if (m < 12) const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

// ── Single month card ──────────────────────────────────────────────────────────

class _GregorianMonthCard extends StatelessWidget {
  final int year;
  final int month;
  final Map<DateTime, Color> eventMap;
  final DateTime todayKey;
  final void Function(DateTime)? onDayTap;
  final void Function(DateTime)? onDayLongPress;

  static const _weekdayLabels = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

  const _GregorianMonthCard({
    required this.year,
    required this.month,
    required this.eventMap,
    required this.todayKey,
    this.onDayTap,
    this.onDayLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final monthName = DateFormat('MMMM').format(DateTime(year, month));
    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    // Dart weekday: 1=Mon … 7=Sun. Offset = (weekday - 1) so Monday aligns col 0.
    final firstOffset = DateTime(year, month, 1).weekday - 1;
    final totalCells = firstOffset + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Container(
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Month header ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              monthName,
              style: AppTextStyles.cinzel(
                  size: 12, weight: FontWeight.w700, color: c.gold),
              textAlign: TextAlign.center,
            ),
          ),
          // ── Weekday header row ─────────────────────────────────────────
          Row(
            children: _weekdayLabels
                .map((lbl) => Expanded(
                      child: Text(
                        lbl,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.cinzel(size: 9, color: c.dim),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 4),
          // ── Day grid ───────────────────────────────────────────────────
          for (int row = 0; row < rows; row++) ...[
            Row(
              children: List.generate(7, (col) {
                final cellIndex = row * 7 + col;
                final dayNum = cellIndex - firstOffset + 1;
                if (dayNum < 1 || dayNum > daysInMonth) {
                  return const Expanded(child: SizedBox());
                }
                final date = DateTime(year, month, dayNum);
                final isToday = date == todayKey;
                final eventColor = eventMap[date];

                return Expanded(
                  child: GestureDetector(
                    onTap: onDayTap != null ? () => onDayTap!(date) : null,
                    onLongPress: onDayLongPress != null
                        ? () => onDayLongPress!(date)
                        : null,
                    child: Container(
                      margin: const EdgeInsets.all(1.5),
                      decoration: isToday
                          ? BoxDecoration(
                              color: c.todayBg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: c.gold, width: 1),
                            )
                          : BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                            ),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$dayNum',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.cinzel(
                              size: 11,
                              color: isToday ? c.gold : c.text,
                              weight: isToday
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 2),
                          // Event dot — always reserve space so cells stay uniform
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: eventColor ?? Colors.transparent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }
}
