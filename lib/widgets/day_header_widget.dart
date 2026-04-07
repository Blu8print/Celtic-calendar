import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../db/database.dart';
import '../engine/celtic_calendar.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  DayHeaderWidget
//
//  compact: true  → compact row header (used in bottom sheet / day tap panel)
//  compact: false → full header (used in DayView screen)
//
//  The live clock StreamBuilder is only mounted when isToday == true.
// ─────────────────────────────────────────────────────────────────────────────

class DayHeaderWidget extends StatelessWidget {
  final bool compact;
  final int celticDay;
  final CelticMonth celticMonth;
  final DateTime gregorianDate;
  final bool isToday;
  final List<Event> events;
  final void Function(Event) onEventTap;
  final VoidCallback onAddEvent;

  const DayHeaderWidget({
    super.key,
    required this.compact,
    required this.celticDay,
    required this.celticMonth,
    required this.gregorianDate,
    required this.isToday,
    required this.events,
    required this.onEventTap,
    required this.onAddEvent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        compact
            ? _CompactHeader(
                celticDay: celticDay,
                celticMonth: celticMonth,
                gregorianDate: gregorianDate,
                isToday: isToday,
              )
            : _FullHeader(
                celticDay: celticDay,
                celticMonth: celticMonth,
                gregorianDate: gregorianDate,
                isToday: isToday,
              ),
        _EventList(
          events: events,
          isToday: isToday,
          gregorianDate: gregorianDate,
          onEventTap: onEventTap,
          onAddEvent: onAddEvent,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _CompactHeader
//  Row: [big day num] [Expanded: month·tree / date·keyword] [clock?]
// ─────────────────────────────────────────────────────────────────────────────

class _CompactHeader extends StatelessWidget {
  final int celticDay;
  final CelticMonth celticMonth;
  final DateTime gregorianDate;
  final bool isToday;

  const _CompactHeader({
    required this.celticDay,
    required this.celticMonth,
    required this.gregorianDate,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final gregStr = DateFormat('EEEE d MMMM').format(gregorianDate);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border, width: 1.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Day number
          Text(
            '$celticDay',
            style: AppTextStyles.cinzel(
              size: 26,
              weight: FontWeight.w700,
              color: c.muted,
            ),
          ),
          const SizedBox(width: 12),
          // Month · Tree + date · keyword
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${celticMonth.name} · ${celticMonth.tree}',
                  style: AppTextStyles.cinzel(
                    size: 15,
                    weight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 1),
                RichText(
                  text: TextSpan(
                    style: AppTextStyles.imFell(
                        size: 11, color: c.dim, italic: true),
                    children: [
                      TextSpan(text: '$gregStr · '),
                      TextSpan(
                        text: celticMonth.keyword.toUpperCase(),
                        style: AppTextStyles.cinzel(
                          size: 10,
                          color: c.gold,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Live clock — only on today
          if (isToday) ...[
            const SizedBox(width: 12),
            _LiveClock(fontSize: 20),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _FullHeader
//  Used as sticky header in DayView screen.
// ─────────────────────────────────────────────────────────────────────────────

class _FullHeader extends StatelessWidget {
  final int celticDay;
  final CelticMonth celticMonth;
  final DateTime gregorianDate;
  final bool isToday;

  const _FullHeader({
    required this.celticDay,
    required this.celticMonth,
    required this.gregorianDate,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border, width: 1.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: left block + clock
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // "CELTIC TREE CALENDAR · DAY"
                    Text(
                      'CELTIC TREE CALENDAR · DAY',
                      style: AppTextStyles.cinzel(
                        size: 10,
                        color: c.dim,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Day number + month name baseline-aligned
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$celticDay',
                          style: AppTextStyles.cinzel(
                            size: 38,
                            weight: FontWeight.w700,
                            color: c.muted,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          celticMonth.name,
                          style: AppTextStyles.cinzel(
                            size: 22,
                            weight: FontWeight.w600,
                            color: c.text,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Ogham · tree · keyword row
                    Row(
                      children: [
                        Text(
                          celticMonth.ogham,
                          style: AppTextStyles.imFell(size: 19, color: c.gold),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          celticMonth.tree,
                          style: AppTextStyles.imFell(
                              size: 13, color: c.dim, italic: true),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '·',
                          style: AppTextStyles.cinzel(size: 10, color: c.border),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          celticMonth.keyword.toUpperCase(),
                          style: AppTextStyles.cinzel(
                            size: 11,
                            color: c.gold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Live clock — only on today
              if (isToday) ...[
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: _LiveClock(fontSize: 28),
                ),
              ],
            ],
          ),
          // Gregorian date divider
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: c.border, width: 1)),
            ),
            child: Text(
              DateFormat.yMMMMEEEEd().format(gregorianDate),
              style: AppTextStyles.imFell(size: 12, color: c.dim),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _LiveClock
//  StreamBuilder updating every minute. Respects system 12/24h preference.
// ─────────────────────────────────────────────────────────────────────────────

class _LiveClock extends StatefulWidget {
  final double fontSize;
  const _LiveClock({required this.fontSize});

  @override
  State<_LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<_LiveClock> {
  late final StreamController<DateTime> _controller;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _controller = StreamController<DateTime>.broadcast();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      _controller.add(DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final use24 = MediaQuery.of(context).alwaysUse24HourFormat;
    final fmt = use24 ? DateFormat('HH:mm') : DateFormat('h:mm a');

    return StreamBuilder<DateTime>(
      stream: _controller.stream,
      initialData: DateTime.now(),
      builder: (ctx, snap) {
        return Text(
          fmt.format(snap.data ?? DateTime.now()),
          style: AppTextStyles.cinzel(
            size: widget.fontSize,
            weight: FontWeight.w700,
            color: c.muted,
            letterSpacing: 0.03 * widget.fontSize,
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _EventList
//  All-day section + upcoming timed events + empty state.
//  If isToday: only timed events ending after now.
//  If not today: all timed events.
// ─────────────────────────────────────────────────────────────────────────────

class _EventList extends StatelessWidget {
  final List<Event> events;
  final bool isToday;
  final DateTime gregorianDate;
  final void Function(Event) onEventTap;
  final VoidCallback onAddEvent;

  const _EventList({
    required this.events,
    required this.isToday,
    required this.gregorianDate,
    required this.onEventTap,
    required this.onAddEvent,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final now = DateTime.now();

    final allDay = events.where((e) => e.startMinutes == null).toList();

    List<Event> timed;
    if (isToday) {
      timed = events.where((e) {
        if (e.startMinutes == null) return false;
        final endMin = e.startMinutes! + (e.durationMinutes ?? 60);
        final endTime = DateTime(gregorianDate.year, gregorianDate.month,
            gregorianDate.day, endMin ~/ 60, endMin % 60);
        return endTime.isAfter(now);
      }).toList();
    } else {
      timed = events.where((e) => e.startMinutes != null).toList();
    }
    timed.sort((a, b) => (a.startMinutes ?? 0).compareTo(b.startMinutes ?? 0));

    final isEmpty = allDay.isEmpty && timed.isEmpty;

    return Container(
      color: c.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isEmpty)
            _EmptyState(onAddEvent: onAddEvent)
          else ...[
            if (allDay.isNotEmpty) ...[
              _SectionLabel('ALL DAY', first: true),
              ...allDay.map((e) => _AllDayTile(event: e, onTap: () => onEventTap(e))),
            ],
            if (timed.isNotEmpty) ...[
              _SectionLabel(
                isToday ? 'UPCOMING' : 'EVENTS',
                first: allDay.isEmpty,
              ),
              ...timed.map((e) => _TimedTile(event: e, onTap: () => onEventTap(e))),
            ],
          ],
          // Add event link
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onAddEvent,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '+ Add event',
                style: AppTextStyles.cinzel(
                  size: 11,
                  color: c.gold,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final bool first;
  const _SectionLabel(this.label, {this.first = false});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.fromLTRB(4, first ? 0 : 10, 4, 6),
      child: Text(
        label,
        style: AppTextStyles.cinzel(
          size: 10,
          color: c.dim,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _AllDayTile extends StatelessWidget {
  final Event event;
  final VoidCallback onTap;
  const _AllDayTile({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final col = _parseHex(event.color);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: col.withValues(alpha: 0.10),
          border: Border.all(color: col.withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 32,
              decoration: BoxDecoration(
                color: col,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: AppTextStyles.imFell(size: 13, color: c.text),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'All day',
                    style: AppTextStyles.cinzel(
                        size: 9, color: c.dim, letterSpacing: 0.6),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimedTile extends StatelessWidget {
  final Event event;
  final VoidCallback onTap;
  const _TimedTile({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final col = _parseHex(event.color);
    final sMin = event.startMinutes ?? 0;
    final eMin = sMin + (event.durationMinutes ?? 60);
    final ts =
        '${(sMin ~/ 60).toString().padLeft(2, '0')}:${(sMin % 60).toString().padLeft(2, '0')}'
        '\u2013${(eMin ~/ 60).toString().padLeft(2, '0')}:${(eMin % 60).toString().padLeft(2, '0')}';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 36,
              decoration: BoxDecoration(
                color: col,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: AppTextStyles.imFell(size: 13, color: c.text),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ts,
                    style: AppTextStyles.imFell(size: 11, color: c.dim),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAddEvent;
  const _EmptyState({required this.onAddEvent});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No events today',
              style: AppTextStyles.imFell(
                  size: 13, color: c.dim, italic: true),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onAddEvent,
              child: Text(
                '+ Add event',
                style: AppTextStyles.cinzel(
                  size: 11,
                  color: c.gold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

Color _parseHex(String hex) {
  try {
    return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
  } catch (_) {
    return AppColors.dark.gold;
  }
}
