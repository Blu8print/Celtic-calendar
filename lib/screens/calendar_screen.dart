import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/database.dart';
import '../db/events_dao.dart';
import '../engine/celtic_calendar.dart';
import '../theme/app_theme.dart';
import '../widgets/day_grid.dart';
import '../widgets/month_card.dart';
import '../widgets/month_strip.dart';
import '../widgets/year_day_card.dart';
import 'event_detail_screen.dart';
import 'settings_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late int _curYear;

  /// Active month 1-13, or null for Year Day.
  late int? _curMonth;

  @override
  void initState() {
    super.initState();
    _jumpToToday();
  }

  void _jumpToToday() {
    final today = DateTime.now();
    _curYear = celticYearOf(today);
    final info = gregorianToCeltic(today);
    _curMonth = (info.isYearDay || info.isLeapDay) ? null : info.month;
  }

  // ─── Navigation ─────────────────────────────────────────────────────────────

  void _prevMonth() {
    setState(() {
      if (_curMonth == null) {
        _curMonth = 13;
      } else if (_curMonth! > 1) {
        _curMonth = _curMonth! - 1;
      } else {
        _curYear--;
        _curMonth = 13;
      }
    });
  }

  void _nextMonth() {
    setState(() {
      if (_curMonth == 13) {
        _curMonth = null;
      } else if (_curMonth == null) {
        _curYear++;
        _curMonth = 1;
      } else {
        _curMonth = _curMonth! + 1;
      }
    });
  }

  void _prevYear() => setState(() => _curYear--);
  void _nextYear() => setState(() => _curYear++);
  void _goToMonth(int? month) => setState(() => _curMonth = month);

  void _openDay(DateTime date) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EventDetailScreen(date: date)),
    );
  }

  void _openYearDay() => _openDay(yearDayDate(_curYear));

  // ─── Event data helpers ──────────────────────────────────────────────────────

  /// Celtic day numbers that have at least one event — drives grid dots.
  Set<int> _daysWithEvents(List<Event> monthEvents) {
    return monthEvents
        .map((e) => e.celticDay)
        .whereType<int>()
        .toSet();
  }

  /// Up to 3 events on or after today, for the upcoming panel.
  List<UpcomingEvent> _upcomingEvents(List<Event> monthEvents) {
    if (_curMonth == null) return const [];
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    return monthEvents
        .where((e) => !e.gregorianDate.isBefore(today) && e.celticDay != null)
        .take(3)
        .map((e) => UpcomingEvent(
              celticDay: e.celticDay!,
              gregorianDate: e.gregorianDate,
              title: e.title,
            ))
        .toList();
  }

  // ─── Nav label helpers ───────────────────────────────────────────────────────

  String get _prevMonthName {
    if (_curMonth == null) return celticMonths[12].name;
    if (_curMonth! > 1) return celticMonths[_curMonth! - 2].name;
    return '';
  }

  String get _nextMonthName {
    if (_curMonth == 13) return 'Year Day';
    if (_curMonth == null) return celticMonths[0].name;
    return celticMonths[_curMonth!].name;
  }

  String get _monthPosition {
    if (_curMonth == null) return 'Day out of time';
    return 'Month $_curMonth of 13';
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final appBarIconColor = Theme.of(context).appBarTheme.iconTheme?.color ?? c.gold;
    final appBarTitleColor = Theme.of(context).appBarTheme.titleTextStyle?.color ?? c.gold2;
    final dao = context.read<EventsDao>();

    // Stream for the currently viewed month. Key forces a clean rebuild
    // (clears stale data) whenever the user navigates to a different month.
    final stream = _curMonth != null
        ? dao.watchEventsForMonth(_curYear, _curMonth!)
        : dao.watchYearDayEvents(_curYear);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              'Celtic Tree Calendar',
              style: AppTextStyles.cinzelDeco(
                  size: 14, color: appBarTitleColor, letterSpacing: 3),
            ),
            Text(
              'Beth-Luis-Nion · 13 months of 28 days',
              style: AppTextStyles.imFell(
                  size: 11, color: c.dim, italic: true),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined, color: appBarIconColor),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          const threshold = 200.0;
          final v = details.primaryVelocity ?? 0;
          if (v < -threshold) _nextMonth();
          if (v > threshold) _prevMonth();
        },
        child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Year navigation
            _YearNav(
              celticYear: _curYear,
              onPrev: _prevYear,
              onNext: _nextYear,
            ),
            const SizedBox(height: 16),

            // Event-driven section: MonthCard + MonthNav + grid.
            // StreamBuilder key resets snapshot when navigating months so
            // stale dots/events from the previous month never flash.
            StreamBuilder<List<Event>>(
              key: ValueKey('$_curYear-$_curMonth'),
              stream: stream,
              builder: (context, snapshot) {
                final monthEvents = snapshot.data ?? [];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MonthCard(
                      celticYear: _curYear,
                      month: _curMonth,
                      upcomingEvents: _upcomingEvents(monthEvents),
                      onEventTap: _openDay,
                    ),
                    const SizedBox(height: 14),
                    _MonthNav(
                      prevName: _prevMonthName,
                      nextName: _nextMonthName,
                      position: _monthPosition,
                      onPrev: _prevMonth,
                      onNext: _nextMonth,
                      onToday: () => setState(_jumpToToday),
                    ),
                    const SizedBox(height: 14),
                    if (_curMonth != null)
                      DayGrid(
                        celticYear: _curYear,
                        month: _curMonth!,
                        daysWithEvents: _daysWithEvents(monthEvents),
                        onDayTap: _openDay,
                      )
                    else
                      YearDayCard(
                        celticYear: _curYear,
                        onTap: _openYearDay,
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // Month strip (navigation only, no event data needed)
            MonthStrip(
              activeMonth: _curMonth,
              celticYear: _curYear,
              onMonthSelected: _goToMonth,
            ),
          ],
        ),
      ),      // SingleChildScrollView
    ),        // GestureDetector
  );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────


class _YearNav extends StatelessWidget {
  final int celticYear;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _YearNav({
    required this.celticYear,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _NavButton(label: '◄', onTap: onPrev),
        const SizedBox(width: 12),
        Text(
          'Celtic Year $celticYear – ${celticYear + 1}',
          style: AppTextStyles.cinzel(
              size: 12, color: c.muted, letterSpacing: 2),
        ),
        const SizedBox(width: 12),
        _NavButton(label: '►', onTap: onNext),
      ],
    );
  }
}

class _MonthNav extends StatelessWidget {
  final String prevName;
  final String nextName;
  final String position;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;

  const _MonthNav({
    required this.prevName,
    required this.nextName,
    required this.position,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Expanded(
          child: _MNavButton(
            label: prevName.isEmpty ? '◄' : '◄ $prevName',
            onTap: onPrev,
          ),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                position,
                style: AppTextStyles.cinzel(
                    size: 11, color: c.dim, letterSpacing: 0.8),
              ),
              const SizedBox(height: 4),
              _TodayButton(onTap: onToday),
            ],
          ),
        ),
        Expanded(
          child: _MNavButton(
            label: nextName.isEmpty ? '►' : '$nextName ►',
            onTap: onNext,
            alignRight: true,
          ),
        ),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _NavButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(label,
            style: AppTextStyles.cinzel(size: 14, color: c.gold)),
      ),
    );
  }
}

class _MNavButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool alignRight;

  const _MNavButton({
    required this.label,
    required this.onTap,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: AppTextStyles.cinzel(
              size: 11, color: c.muted, letterSpacing: 0.8),
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _TodayButton extends StatelessWidget {
  final VoidCallback onTap;

  const _TodayButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(color: c.dim),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          '☽ Today',
          style: AppTextStyles.cinzel(
              size: 10, color: c.dim, letterSpacing: 1),
        ),
      ),
    );
  }
}
