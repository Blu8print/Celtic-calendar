import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../db/database.dart';
import '../engine/celtic_calendar.dart';
import '../theme/app_theme.dart';

/// Chronological list of all events in the Celtic year, grouped by month then day.
class ScheduleView extends StatefulWidget {
  final int celticYear;
  final List<Event> events;
  final void Function(DateTime date) onEventTap;

  const ScheduleView({
    super.key,
    required this.celticYear,
    required this.events,
    required this.onEventTap,
  });

  @override
  State<ScheduleView> createState() => _ScheduleViewState();
}

class _ScheduleViewState extends State<ScheduleView> {
  final _scroll = ScrollController();
  // Key per day group for scrolling to today
  final Map<String, GlobalKey> _dayKeys = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToToday());
  }

  void _scrollToToday() {
    final todayC = gregorianToCeltic(DateTime.now());
    if (todayC.isYearDay || todayC.isLeapDay) return;
    if (todayC.celticYear != widget.celticYear) return;
    final key = '${todayC.month}-${todayC.day}';
    final gk  = _dayKeys[key];
    if (gk?.currentContext == null) return;
    Scrollable.ensureVisible(gk!.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        alignment: 0.0);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c      = context.colors;
    final today  = DateTime.now();
    final todayC = gregorianToCeltic(today);

    // Group: month → day → events
    final Map<int, Map<int, List<Event>>> byMonth = {};
    for (final e in widget.events) {
      if (e.celticDay == null || e.celticMonth == null) continue;
      byMonth.putIfAbsent(e.celticMonth!, () => {});
      byMonth[e.celticMonth!]!
          .putIfAbsent(e.celticDay!, () => [])
          .add(e);
    }

    if (byMonth.isEmpty) {
      return Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(32),
        child: Text(
          'No events this year',
          style: AppTextStyles.imFell(size: 14, color: c.dim, italic: true),
        ),
      );
    }

    final items = <Widget>[];
    final sortedMonths = byMonth.keys.toList()..sort();

    for (final m in sortedMonths) {
      final mo = celticMonths[m - 1];
      // Month divider
      items.add(_MonthDivider(mo: mo, colors: c));

      final sortedDays = byMonth[m]!.keys.toList()..sort();
      for (final d in sortedDays) {
        final isToday = !todayC.isYearDay && !todayC.isLeapDay &&
            todayC.celticYear == widget.celticYear &&
            todayC.month == m && todayC.day == d;

        final gregDate = celticToGregorian(widget.celticYear, m, d);
        final dayKey   = '$m-$d';
        final gk       = GlobalKey();
        _dayKeys[dayKey] = gk;

        items.add(_DayBlock(
          key: gk,
          celticDay: d,
          month: mo.name,
          gregDate: gregDate,
          isToday: isToday,
          events: byMonth[m]![d]!,
          onEventTap: widget.onEventTap,
          colors: c,
        ));
      }
    }

    return SingleChildScrollView(
      controller: _scroll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: items,
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _MonthDivider extends StatelessWidget {
  final CelticMonth mo;
  final AppColors colors;

  const _MonthDivider({required this.mo, required this.colors});

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Container(
      color: c.surface2,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Text(
        '${mo.name.toUpperCase()} \u00b7 ${mo.tree.toUpperCase()} \u00b7 ${mo.keyword.toUpperCase()}',
        style: AppTextStyles.cinzel(
            size: 9, color: c.dim, letterSpacing: 1.0, weight: FontWeight.w600),
      ),
    );
  }
}

class _DayBlock extends StatelessWidget {
  final int celticDay;
  final String month;
  final DateTime gregDate;
  final bool isToday;
  final List<Event> events;
  final void Function(DateTime) onEventTap;
  final AppColors colors;

  const _DayBlock({
    super.key,
    required this.celticDay,
    required this.month,
    required this.gregDate,
    required this.isToday,
    required this.events,
    required this.onEventTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.border, width: 1.0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Day header
          Container(
            color: isToday ? c.todayBg : null,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                // Day circle / number
                isToday
                    ? Container(
                        width: 30, height: 30,
                        decoration: BoxDecoration(
                            color: c.muted, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: Text('$celticDay',
                            style: AppTextStyles.cinzel(
                                size: 13, weight: FontWeight.w700, color: c.surface)),
                      )
                    : SizedBox(
                        width: 30,
                        child: Text('$celticDay',
                            style: AppTextStyles.cinzel(
                                size: 18, weight: FontWeight.w700, color: c.muted),
                            textAlign: TextAlign.center),
                      ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(DateFormat('d MMM').format(gregDate),
                        style: AppTextStyles.cinzel(size: 10, color: c.dim)),
                    Text(month,
                        style: AppTextStyles.imFell(
                            size: 11, color: c.dim, italic: true)),
                  ],
                ),
              ],
            ),
          ),
          // Event rows
          ...events.map((e) {
            final col     = _parseHex(e.color);
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
              onTap: () => onEventTap(e.gregorianDate),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: c.border, width: 0.5)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 3, height: 36,
                      decoration: BoxDecoration(
                        color: col, borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(width: 12),
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
