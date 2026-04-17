import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../db/database.dart';
import '../engine/celtic_calendar.dart';
import '../theme/app_theme.dart';
import 'time_grid_shared.dart';

const double _kApproxHeaderH = 50.0; // day-names header overhead for auto-fit

/// N-day time grid view (nDays=7 for week, nDays=3 for 3-day).
/// [startDay] is the first Celtic day shown (1-28).
class WeekView extends StatefulWidget {
  final int celticYear;
  final int month;
  final int startDay;
  final int nDays;
  final List<Event> events;
  final void Function(int celticDay) onDayTap;
  final void Function(DateTime date) onEventTap;
  final double initialScale;
  final ValueChanged<double>? onScaleChanged;
  final void Function(DateTime date, TimeOfDay time)? onSlotLongPress;

  const WeekView({
    super.key,
    required this.celticYear,
    required this.month,
    required this.startDay,
    required this.nDays,
    required this.events,
    required this.onDayTap,
    required this.onEventTap,
    this.initialScale = 0.0,
    this.onScaleChanged,
    this.onSlotLongPress,
  });

  @override
  State<WeekView> createState() => _WeekViewState();
}

class _WeekViewState extends State<WeekView> {
  final _scroll         = ScrollController();
  double _scale         = 0.0;
  double _baseScale     = 1.0;
  int    _pointers      = 0;
  bool   _fittingScheduled = false;

  @override
  void initState() {
    super.initState();
    _scale = widget.initialScale;
    // Only scroll-to-now once a real scale is known (> 0).
    // When scale is 0 (auto-fit), _scrollToNow is called from the fit callback.
    if (widget.initialScale > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToNow());
    }
  }

  @override
  void didUpdateWidget(WeekView old) {
    super.didUpdateWidget(old);
    if (old.startDay != widget.startDay || old.month != widget.month) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToNow());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToNow() {
    if (_scale == 0.0 || !_scroll.hasClients) return;
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
    final c         = context.colors;
    final startDay  = widget.startDay;
    final nDays     = widget.nDays;
    final startWday = monthStartWeekday(widget.celticYear);
    const wdNames   = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

    final today  = DateTime.now();
    final todayC = gregorianToCeltic(today);
    final todayInView = !todayC.isYearDay && !todayC.isLeapDay &&
        todayC.celticYear == widget.celticYear &&
        todayC.month == widget.month &&
        todayC.day! >= startDay &&
        todayC.day! < startDay + nDays;
    final nowH = today.hour + today.minute / 60.0;

    final rangeEnd  = startDay + nDays - 1;
    final visEvs    = widget.events.where((e) =>
        e.celticDay != null &&
        e.celticDay! >= startDay &&
        e.celticDay! <= rangeEnd).toList();
    final allDayEvs = visEvs.where((e) => e.startMinutes == null).toList();
    final timedEvs  = visEvs.where((e) => e.startMinutes != null).toList();

    return LayoutBuilder(builder: (context, constraints) {
      final totalColW = constraints.maxWidth - kTimeGutterW;
      final colW      = totalColW / nDays;

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
        height: constraints.maxHeight,
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          children: [
            // Day headers
            Container(
              decoration: BoxDecoration(
                color: c.surface2,
                border: Border(bottom: BorderSide(color: c.border)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: kTimeGutterW,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(right: BorderSide(color: c.border, width: 0.5)),
                      ),
                    ),
                  ),
                  ...List.generate(nDays, (i) {
                    final dayNum = startDay + i;
                    if (dayNum > 28) return const Expanded(child: SizedBox());
                    final gregDate = celticToGregorian(widget.celticYear, widget.month, dayNum);
                    final wdName   = wdNames[(startWday + dayNum - 1) % 7];
                    final isToday  = todayInView && todayC.day == dayNum;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => widget.onDayTap(dayNum),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: isToday ? c.todayBg : null,
                            border: Border(
                              right: i < nDays - 1
                                  ? BorderSide(color: c.border, width: 0.5)
                                  : BorderSide.none,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(wdName,
                                  style: AppTextStyles.cinzel(
                                      size: 9, color: c.dim, letterSpacing: 0.4)),
                              const SizedBox(height: 2),
                              isToday
                                  ? Container(
                                      width: 22, height: 22,
                                      decoration: BoxDecoration(
                                          color: c.muted, shape: BoxShape.circle),
                                      alignment: Alignment.center,
                                      child: Text('$dayNum',
                                          style: AppTextStyles.cinzel(
                                              size: 10, color: c.surface)),
                                    )
                                  : Text('$dayNum',
                                      style: AppTextStyles.cinzel(
                                          size: 10, color: c.text)),
                              Text(DateFormat('d/M').format(gregDate),
                                  style: AppTextStyles.cinzel(size: 8, color: c.dim)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),

            // All-day strip — one cell per day column so pills stay aligned
            if (allDayEvs.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  color: c.surface2,
                  border: Border(bottom: BorderSide(color: c.border)),
                ),
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: kTimeGutterW,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4, top: 2),
                        child: Text('All\nday',
                            style: AppTextStyles.cinzel(size: 7, color: c.dim),
                            textAlign: TextAlign.right),
                      ),
                    ),
                    ...List.generate(nDays, (i) {
                      final dayNum = startDay + i;
                      final dayEvs = allDayEvs
                          .where((e) => e.celticDay == dayNum)
                          .toList();
                      return Container(
                        width: colW,
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          border: Border(
                            right: i < nDays - 1
                                ? BorderSide(color: c.border, width: 0.5)
                                : BorderSide.none,
                          ),
                        ),
                        child: dayEvs.isEmpty
                            ? const SizedBox(height: 20)
                            : Wrap(
                                spacing: 2, runSpacing: 2,
                                children: dayEvs
                                    .map((e) => _EventPill(
                                        event: e,
                                        onTap: () =>
                                            widget.onEventTap(e.gregorianDate)))
                                    .toList(),
                              ),
                      );
                    }),
                  ],
                ),
              ),

            // Time grid
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
                  final dayIdx = ((dx - kTimeGutterW) / colW)
                      .floor()
                      .clamp(0, widget.nDays - 1);
                  final celticDay = widget.startDay + dayIdx;
                  if (celticDay > 28) return;
                  final date = celticToGregorian(
                      widget.celticYear, widget.month, celticDay);
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
                              right: BorderSide(color: c.border, width: 0.5)),
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
                      // Day columns
                      SizedBox(
                        width: totalColW,
                        height: totalH,
                        child: Stack(
                          children: [
                            // Slot grid
                            Column(
                              children: hours
                                  .map((h) => Row(
                                        children: List.generate(
                                          nDays,
                                          (ci) => Container(
                                            width: colW,
                                            height: slotH,
                                            decoration: BoxDecoration(
                                              border: Border(
                                                bottom: BorderSide(
                                                    color: c.border,
                                                    width: 0.5),
                                                right: ci < nDays - 1
                                                    ? BorderSide(
                                                        color: c.border,
                                                        width: 0.5)
                                                    : BorderSide.none,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ))
                                  .toList(),
                            ),
                            // Event blocks
                            ...timedEvs.map((e) {
                              final ci = e.celticDay! - startDay;
                              if (ci < 0 || ci >= nDays) {
                                return const SizedBox.shrink();
                              }
                              final top = e.startMinutes! / 60.0 * slotH -
                                  kHourStart * slotH;
                              final height = math.max(
                                  (e.durationMinutes ?? 60) / 60.0 * slotH,
                                  18.0);
                              return Positioned(
                                top: top,
                                left: ci * colW + 1,
                                width: colW - 2,
                                child: SizedBox(
                                  height: height,
                                  child: GestureDetector(
                                    onTap: () =>
                                        widget.onEventTap(e.gregorianDate),
                                    child: _EventBlock(event: e),
                                  ),
                                ),
                              );
                            }),
                            // Now line
                            if (todayInView &&
                                nowH >= kHourStart &&
                                nowH <= kHourEnd)
                              Positioned(
                                top: (nowH - kHourStart) * slotH - 1,
                                left: (todayC.day! - startDay) * colW,
                                width: colW,
                                child: const TimeGridNowLine(),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),          // closes SingleChildScrollView
          ),            // closes GestureDetector
          ),            // closes Listener
          ],
        ),
      );
    });
  }
}

// ── Shared small widgets ──────────────────────────────────────────────────────

class _EventBlock extends StatelessWidget {
  final Event event;
  const _EventBlock({required this.event});

  @override
  Widget build(BuildContext context) {
    final c    = context.colors;
    final col  = parseHexColor(event.color);
    final bg   = col.withValues(alpha: 0.15);
    final sMin = event.startMinutes ?? 0;
    final eMin = sMin + (event.durationMinutes ?? 60);
    final ts   =
        '${(sMin ~/ 60).toString().padLeft(2, '0')}:${(sMin % 60).toString().padLeft(2, '0')}'
        '\u2013${(eMin ~/ 60).toString().padLeft(2, '0')}:${(eMin % 60).toString().padLeft(2, '0')}';

    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(3),
        border: Border(left: BorderSide(color: col, width: 3)),
      ),
      child: Container(
        color: bg,
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(event.title,
              style: AppTextStyles.cinzel(size: 8.5, color: c.text),
              overflow: TextOverflow.clip),
          if ((event.durationMinutes ?? 60) > 29)
            Text(ts,
                style: AppTextStyles.imFell(size: 7.5, color: c.muted),
                overflow: TextOverflow.ellipsis,
                maxLines: 1),
        ],
      ),
      ),
    );
  }
}

class _EventPill extends StatelessWidget {
  final Event event;
  final VoidCallback onTap;
  const _EventPill({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final col = parseHexColor(event.color);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: col.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: col.withValues(alpha: 0.4)),
        ),
        child: Text(event.title,
            style: AppTextStyles.cinzel(size: 8, color: col),
            overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

