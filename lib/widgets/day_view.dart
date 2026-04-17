import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../db/database.dart';
import '../engine/celtic_calendar.dart';
import '../engine/celtic_festivals.dart';
import '../engine/moon_phase.dart';
import '../theme/app_theme.dart';
import 'time_grid_shared.dart';

const double _kApproxHeaderH = 80.0; // all-day + moon + compact header overhead

/// Full-day view: compact header + all-day events + timed event timeline.
class DayView extends StatefulWidget {
  final int celticYear;
  final int month;   // 1-13
  final int day;     // 1-28
  final List<Event> events;           // already filtered to this day
  final List<CelticFestival> festivalsForDay; // read-only, not editable
  final void Function(DateTime date) onOpenDay; // open EventDetailScreen
  final double initialScale;
  final ValueChanged<double>? onScaleChanged;
  final void Function(DateTime date, TimeOfDay time)? onSlotLongPress;

  const DayView({
    super.key,
    required this.celticYear,
    required this.month,
    required this.day,
    required this.events,
    this.festivalsForDay = const [],
    required this.onOpenDay,
    this.initialScale = 0.0,
    this.onScaleChanged,
    this.onSlotLongPress,
  });

  @override
  State<DayView> createState() => _DayViewState();
}

class _DayViewState extends State<DayView> {
  final _scroll             = ScrollController();
  double _scale             = 0.0;
  double _baseScale         = 1.0;
  int    _pointers          = 0;
  bool   _fittingScheduled  = false;

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
    _scale = widget.initialScale;
    if (widget.initialScale > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToNow());
    }
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
    if (_scale == 0.0 || !_isToday || !_scroll.hasClients) return;
    final now = DateTime.now();
    final h = now.hour + now.minute / 60.0;
    if (h < kHourStart) return;
    final slotH = (kTimeSlotH * _scale).clamp(20.0, 200.0);
    _scroll.animateTo(
      math.max(0, (h - kHourStart) * slotH - 100),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c        = context.colors;
    final gregDate = celticToGregorian(widget.celticYear, widget.month, widget.day);
    final isToday  = _isToday;
    final phase     = MoonPhaseCalculator.calculate(gregDate);
    final allDayEvs = widget.events.where((e) => e.startMinutes == null).toList();
    final timedEvs  = widget.events.where((e) => e.startMinutes != null).toList();
    final now  = DateTime.now();
    final nowH = now.hour + now.minute / 60.0;

    return LayoutBuilder(builder: (context, constraints) {
      final colW = constraints.maxWidth - kTimeGutterW;

      // Auto-fit: on first build with no saved scale, compute zoom so 07:00–23:00
      // (16 hours) fills the visible viewport, then bake it in via setState.
      double effectiveScale = _scale;
      if (_scale == 0.0 && !_fittingScheduled) {
        _fittingScheduled = true;
        final gridH = constraints.maxHeight - _kApproxHeaderH;
        effectiveScale = (gridH / (16 * kTimeSlotH)).clamp(0.4, 4.0);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _scale = effectiveScale);
          widget.onScaleChanged?.call(effectiveScale);
          _scrollToNow();
        });
      }

      final slotH  = (kTimeSlotH * effectiveScale).clamp(20.0, 200.0);
      final hours  = List.generate(kHourEnd - kHourStart, (i) => kHourStart + i);
      final totalH = hours.length * slotH;

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
            // ── All-day row ───────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: c.surface2,
                border: Border(bottom: BorderSide(color: c.border)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: kTimeGutterW,
                    decoration: BoxDecoration(
                      border: Border(
                          right: BorderSide(color: c.border, width: 0.5)),
                    ),
                    padding: const EdgeInsets.only(right: 4, top: 1),
                    child: Text('All\nday',
                        style: AppTextStyles.cinzel(size: 7, color: c.dim),
                        textAlign: TextAlign.right),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
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
                                final col = parseHexColor(e.color);
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
                    width: kTimeGutterW,
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
            Expanded(
              child: Listener(
                onPointerDown:   (_) => setState(() => _pointers++),
                onPointerUp:     (_) => setState(() => _pointers = math.max(0, _pointers - 1)),
                onPointerCancel: (_) => setState(() => _pointers = math.max(0, _pointers - 1)),
                child: GestureDetector(
                  onScaleStart: (_) => _baseScale = _scale,
                  onScaleUpdate: (d) {
                    if (_pointers < 2) return;
                    final newScale = (_baseScale * d.scale).clamp(0.4, 4.0);
                    if (newScale == _scale) return;
                    final oldTotal = kTimeSlotH * _scale * (kHourEnd - kHourStart);
                    final ratio = _scroll.hasClients && oldTotal > 0
                        ? _scroll.offset / oldTotal
                        : 0.0;
                    setState(() => _scale = newScale);
                    widget.onScaleChanged?.call(newScale);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!_scroll.hasClients) return;
                      final newTotal = kTimeSlotH * _scale * (kHourEnd - kHourStart);
                      _scroll.jumpTo((ratio * newTotal)
                          .clamp(0, _scroll.position.maxScrollExtent));
                    });
                  },
                  onLongPressStart: widget.onSlotLongPress == null ? null : (details) {
                    final dx = details.localPosition.dx;
                    if (dx < kTimeGutterW) return;
                    final contentY = details.localPosition.dy +
                        (_scroll.hasClients ? _scroll.offset : 0);
                    final hour = (kHourStart + contentY / slotH)
                        .floor()
                        .clamp(kHourStart, kHourEnd - 1);
                    final date = celticToGregorian(
                        widget.celticYear, widget.month, widget.day);
                    widget.onSlotLongPress!(date, TimeOfDay(hour: hour, minute: 0));
                  },
                  child: SingleChildScrollView(
                    controller: _scroll,
                    physics: _pointers >= 2
                        ? const NeverScrollableScrollPhysics()
                        : null,
                    child: SizedBox(
                      height: totalH,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Time gutter
                          Container(
                            width: kTimeGutterW,
                            decoration: BoxDecoration(
                              color: c.surface2,
                              border: Border(
                                  right: BorderSide(
                                      color: c.border, width: 0.5)),
                            ),
                            child: Column(
                              children: hours
                                  .map((h) => SizedBox(
                                        height: slotH,
                                        child: Align(
                                          alignment: Alignment.topRight,
                                          child: Padding(
                                            padding: const EdgeInsets.only(
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
                                            height: slotH,
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
                                  final top = e.startMinutes! / 60.0 * slotH -
                                      kHourStart * slotH;
                                  final height = math.max(
                                      (e.durationMinutes ?? 60) / 60.0 * slotH,
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
                                    nowH >= kHourStart &&
                                    nowH <= kHourEnd)
                                  Positioned(
                                    top: (nowH - kHourStart) * slotH - 1,
                                    left: 0, right: 0,
                                    child: const TimeGridNowLine(),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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
    final col  = parseHexColor(event.color);
    final bg   = col.withValues(alpha: 0.12);
    final sMin = event.startMinutes ?? 0;
    final eMin = sMin + (event.durationMinutes ?? 60);
    final ts   =
        '${(sMin ~/ 60).toString().padLeft(2, '0')}:${(sMin % 60).toString().padLeft(2, '0')}'
        '\u2013${(eMin ~/ 60).toString().padLeft(2, '0')}:${(eMin % 60).toString().padLeft(2, '0')}';

    final c = context.colors;
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border(left: BorderSide(color: col, width: 3)),
      ),
      child: Container(
        color: bg,
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
      ),
    );
  }
}

