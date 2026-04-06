import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../db/database.dart';
import '../engine/celtic_calendar.dart';
import '../engine/celtic_festivals.dart';
import '../engine/moon_phase.dart';
import '../theme/app_theme.dart';

const double _kSlotH     = 52.0;
const int    _kHourStart  = 0;
const int    _kHourEnd    = 24;
const double _kGutterW    = 44.0;

/// Full-day view: compact header + all-day events + timed event timeline.
class DayView extends StatefulWidget {
  final int celticYear;
  final int month;   // 1-13
  final int day;     // 1-28
  final List<Event> events;           // already filtered to this day
  final List<CelticFestival> festivalsForDay; // read-only, not editable
  final void Function(DateTime date) onOpenDay; // open EventDetailScreen

  const DayView({
    super.key,
    required this.celticYear,
    required this.month,
    required this.day,
    required this.events,
    this.festivalsForDay = const [],
    required this.onOpenDay,
  });

  @override
  State<DayView> createState() => _DayViewState();
}

class _DayViewState extends State<DayView> {
  final _scroll = ScrollController();

  bool get _isToday {
    final tc = gregorianToCeltic(DateTime.now());
    return !tc.isYearDay && !tc.isLeapDay &&
        tc.celticYear == widget.celticYear &&
        tc.month == widget.month &&
        tc.day == widget.day;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToNow());
  }

  @override
  void didUpdateWidget(DayView old) {
    super.didUpdateWidget(old);
    if (old.day != widget.day || old.month != widget.month) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToNow());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _showFestivalInfo(BuildContext context, AppColors c,
      CelticFestival f, DateTime gregDate) {
    final cd = gregorianToCeltic(gregDate);
    final mo = celticMonths[cd.month! - 1];
    final barColor = f.type == FestivalType.fire
        ? const Color(0xFFb07800)
        : const Color(0xFF4a3080);
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${f.symbol}  ${f.name}',
                style: AppTextStyles.cinzel(
                    size: 18, weight: FontWeight.w700, color: barColor)),
            const SizedBox(height: 6),
            Text(
              '${DateFormat('MMMM d').format(gregDate)} · ${mo.name} Day ${cd.day}',
              style: AppTextStyles.cinzel(size: 11, color: c.dim),
            ),
            const SizedBox(height: 12),
            Text(f.description,
                style: AppTextStyles.imFell(
                    size: 14, color: c.text, italic: true)),
            const SizedBox(height: 8),
            Text(f.flavour,
                style: AppTextStyles.imFell(size: 13, color: c.muted)),
            const SizedBox(height: 16),
            Text('Celtic Festival — read only',
                style: AppTextStyles.cinzel(size: 9, color: c.dim,
                    letterSpacing: 0.8)),
          ],
        ),
      ),
    );
  }

  void _scrollToNow() {
    if (!_isToday || !_scroll.hasClients) return;
    final now = DateTime.now();
    final h = now.hour + now.minute / 60.0;
    if (h < _kHourStart) return;
    _scroll.animateTo(
      math.max(0, (h - _kHourStart) * _kSlotH - 100),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c        = context.colors;
    final mo       = celticMonths[widget.month - 1];
    final gregDate = celticToGregorian(widget.celticYear, widget.month, widget.day);
    final isToday  = _isToday;
    final phase     = MoonPhaseCalculator.calculate(gregDate);
    final allDayEvs = widget.events.where((e) => e.startMinutes == null).toList();
    final timedEvs  = widget.events.where((e) => e.startMinutes != null).toList();
    final hours  = List.generate(_kHourEnd - _kHourStart, (i) => _kHourStart + i);
    final totalH = hours.length * _kSlotH;
    final now    = DateTime.now();
    final nowH   = now.hour + now.minute / 60.0;

    return LayoutBuilder(builder: (context, constraints) {
      final colW = constraints.maxWidth - _kGutterW;

      return Container(
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Compact day header ────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: isToday ? c.todayBg : c.surface2,
                border: Border(bottom: BorderSide(color: c.border)),
              ),
              child: Row(
                children: [
                  // Gutter blank
                  Container(
                    width: _kGutterW,
                    decoration: BoxDecoration(
                      border: Border(right: BorderSide(color: c.border, width: 0.5)),
                    ),
                  ),
                  // Date info
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${DateFormat('d MMMM').format(gregDate)} \u00b7 ${mo.name} Day ${widget.day}',
                            style: AppTextStyles.cinzel(
                                size: 13,
                                weight: FontWeight.w700,
                                color: c.text),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${mo.tree} \u00b7 ${mo.keyword}',
                            style: AppTextStyles.imFell(
                                size: 11, color: c.dim, italic: true),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── All-day row ───────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: c.surface2,
                border: Border(bottom: BorderSide(color: c.border)),
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Text('All day',
                      style: AppTextStyles.cinzel(size: 9, color: c.dim)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: (allDayEvs.isEmpty && widget.festivalsForDay.isEmpty)
                        ? Text('\u2014',
                            style: AppTextStyles.imFell(
                                size: 12, color: c.dim, italic: true))
                        : Wrap(
                            spacing: 4, runSpacing: 2,
                            children: [
                              // Festival pills first (read-only)
                              ...widget.festivalsForDay.map((f) {
                                final barColor = f.type == FestivalType.fire
                                    ? const Color(0xFFb07800)
                                    : const Color(0xFF4a3080);
                                return GestureDetector(
                                  onLongPress: () =>
                                      _showFestivalInfo(context, c, f, gregDate),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: barColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                          color: barColor.withValues(alpha: 0.5)),
                                    ),
                                    child: Text('${f.symbol}  ${f.name}',
                                        style: AppTextStyles.cinzel(
                                            size: 9, color: barColor)),
                                  ),
                                );
                              }),
                              // User event pills
                              ...allDayEvs.map((e) {
                                final col = _parseHex(e.color);
                                return GestureDetector(
                                  onTap: () => widget.onOpenDay(gregDate),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: col.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                          color: col.withValues(alpha: 0.5)),
                                    ),
                                    child: Text(e.title,
                                        style: AppTextStyles.cinzel(
                                            size: 9, color: col)),
                                  ),
                                );
                              }),
                            ],
                          ),
                  ),
                ],
              ),
            ),

            // ── Moon phase line ───────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: c.surface2,
                border: Border(bottom: BorderSide(color: c.border)),
              ),
              child: Row(
                children: [
                  Container(
                    width: _kGutterW,
                    decoration: BoxDecoration(
                      border: Border(
                          right: BorderSide(color: c.border, width: 0.5)),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      child: Text(
                        '${phase.symbol}  ${phase.name}',
                        style: AppTextStyles.imFell(
                            size: 11, color: c.dim, italic: true),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Time grid ────────────────────────────────────────────────
            SizedBox(
              height: 380,
              child: SingleChildScrollView(
                controller: _scroll,
                child: SizedBox(
                  height: totalH,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Time gutter
                      Container(
                        width: _kGutterW,
                        decoration: BoxDecoration(
                          color: c.surface2,
                          border: Border(
                              right: BorderSide(
                                  color: c.border, width: 0.5)),
                        ),
                        child: Column(
                          children: hours
                              .map((h) => SizedBox(
                                    height: _kSlotH,
                                    child: Align(
                                      alignment: Alignment.topRight,
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.only(
                                                right: 6, top: 3),
                                        child: Text(
                                          '${h.toString().padLeft(2, '0')}:00',
                                          style: AppTextStyles.cinzel(
                                              size: 8, color: c.dim),
                                        ),
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                      // Event column
                      SizedBox(
                        width: colW,
                        height: totalH,
                        child: Stack(
                          children: [
                            Column(
                              children: hours
                                  .map((h) => Container(
                                        width: colW,
                                        height: _kSlotH,
                                        decoration: BoxDecoration(
                                          border: Border(
                                              bottom: BorderSide(
                                                  color: c.border,
                                                  width: 0.5)),
                                        ),
                                      ))
                                  .toList(),
                            ),
                            // Timed events
                            ...timedEvs.map((e) {
                              final top =
                                  e.startMinutes! / 60.0 * _kSlotH -
                                      _kHourStart * _kSlotH;
                              final height = math.max(
                                  (e.durationMinutes ?? 60) /
                                      60.0 *
                                      _kSlotH,
                                  22.0);
                              return Positioned(
                                top: top,
                                left: 4,
                                right: 4,
                                child: SizedBox(
                                  height: height,
                                  child: GestureDetector(
                                    onTap: () =>
                                        widget.onOpenDay(gregDate),
                                    child: _DayEventBlock(event: e),
                                  ),
                                ),
                              );
                            }),
                            // Now line
                            if (isToday &&
                                nowH >= _kHourStart &&
                                nowH <= _kHourEnd)
                              Positioned(
                                top: (nowH - _kHourStart) * _kSlotH - 1,
                                left: 0, right: 0,
                                child: const _NowLine(),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Add / view button ─────────────────────────────────────────
            GestureDetector(
              onTap: () => widget.onOpenDay(gregDate),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: c.border)),
                ),
                child: Text(
                  '+ Add event  \u00b7  View all events',
                  style: AppTextStyles.cinzel(
                      size: 11, color: c.muted, letterSpacing: 0.5),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

// ── Private widgets ───────────────────────────────────────────────────────────

class _DayEventBlock extends StatelessWidget {
  final Event event;
  const _DayEventBlock({required this.event});

  @override
  Widget build(BuildContext context) {
    final col  = _parseHex(event.color);
    final bg   = col.withValues(alpha: 0.12);
    final sMin = event.startMinutes ?? 0;
    final eMin = sMin + (event.durationMinutes ?? 60);
    final ts   =
        '${(sMin ~/ 60).toString().padLeft(2, '0')}:${(sMin % 60).toString().padLeft(2, '0')}'
        '\u2013${(eMin ~/ 60).toString().padLeft(2, '0')}:${(eMin % 60).toString().padLeft(2, '0')}';

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border(left: BorderSide(color: col, width: 3)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(event.title,
              style: AppTextStyles.cinzel(size: 11, color: col),
              overflow: TextOverflow.ellipsis,
              maxLines: 1),
          Text(ts,
              style: AppTextStyles.imFell(
                  size: 9, color: col.withValues(alpha: 0.8))),
        ],
      ),
    );
  }
}

class _NowLine extends StatelessWidget {
  const _NowLine();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8, height: 8,
          decoration: const BoxDecoration(
              color: Color(0xFFcc2020), shape: BoxShape.circle),
        ),
        Expanded(child: Container(height: 2, color: const Color(0xFFcc2020))),
      ],
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
