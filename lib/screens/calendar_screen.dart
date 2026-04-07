import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../db/database.dart';
import '../db/events_dao.dart';
import '../engine/celtic_calendar.dart';
import '../engine/celtic_festivals.dart';
import '../engine/moon_phase.dart';
import '../services/google_calendar_service.dart';
import '../theme/app_theme.dart';
import '../theme/moon_settings_notifier.dart';
import '../widgets/day_grid.dart';
import '../widgets/day_view.dart';
import '../widgets/schedule_view.dart';
import '../widgets/week_view.dart';
import '../widgets/year_day_card.dart';
import 'event_detail_screen.dart';
import 'settings_screen.dart';

enum CalendarView { month, threeDay, week, day, schedule }

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late int _curYear;
  late int? _curMonth; // 1-13 or null (Year Day)
  late int _curDay;    // 1-28 within the Celtic month
  late int _curWeek;   // 0-3  within the Celtic month
  CalendarView _curView = CalendarView.month;
  GoogleCalendarService? _gcal;
  String? _lastShownError;
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    _jumpToToday();
    _syncTimer = Timer.periodic(
      const Duration(minutes: 10),
      (_) => _autoSync(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final gcal = context.read<GoogleCalendarService>();
    if (gcal != _gcal) {
      _gcal?.removeListener(_onGcalChanged);
      _gcal = gcal;
      _gcal!.addListener(_onGcalChanged);
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _gcal?.removeListener(_onGcalChanged);
    super.dispose();
  }

  void _autoSync() {
    if (!mounted) return;
    context.read<GoogleCalendarService>().backgroundSync(_curYear);
  }

  void _onGcalChanged() {
    final err = _gcal?.lastError;
    if (err != null && err != _lastShownError && mounted) {
      _lastShownError = err;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (err == null) {
      _lastShownError = null;
    }
  }

  void _jumpToToday() {
    final today = DateTime.now();
    _curYear = celticYearOf(today);
    final info = gregorianToCeltic(today);
    if (info.isYearDay || info.isLeapDay) {
      _curMonth = null;
      _curDay   = 1;
      _curWeek  = 0;
    } else {
      _curMonth = info.month;
      _curDay   = info.day!;
      _curWeek  = (_curDay - 1) ~/ 7;
    }
  }

  // ─── Navigation ──────────────────────────────────────────────────────────────

  void _prevPeriod() {
    setState(() {
      switch (_curView) {
        case CalendarView.month:
        case CalendarView.schedule:
          if (_curMonth == null) {
            _curMonth = 13;
          } else if (_curMonth! > 1) {
            _curMonth = _curMonth! - 1;
          } else {
            _curYear--;
            _curMonth = 13;
          }
          _curWeek = 0;
          _curDay  = 1;
        case CalendarView.week:
          if (_curMonth == null) return;
          if (_curWeek > 0) {
            _curWeek--;
          } else if (_curMonth! > 1) {
            _curMonth = _curMonth! - 1;
            _curWeek  = 3;
          } else {
            _curYear--;
            _curMonth = 13;
            _curWeek  = 3;
          }
          _curDay = _curWeek * 7 + 1;
        case CalendarView.threeDay:
          if (_curMonth == null) return;
          final nd = _curDay - 3;
          if (nd >= 1) {
            _curDay = nd;
          } else if (_curMonth! > 1) {
            _curMonth = _curMonth! - 1;
            _curDay   = 28 + nd; // nd is negative
          } else {
            _curYear--;
            _curMonth = 13;
            _curDay   = 28 + nd;
          }
          if (_curDay < 1) _curDay = 1;
          _curWeek = (_curDay - 1) ~/ 7;
        case CalendarView.day:
          if (_curMonth == null) return;
          if (_curDay > 1) {
            _curDay--;
          } else if (_curMonth! > 1) {
            _curMonth = _curMonth! - 1;
            _curDay   = 28;
          } else {
            _curYear--;
            _curMonth = 13;
            _curDay   = 28;
          }
          _curWeek = (_curDay - 1) ~/ 7;
      }
    });
  }

  void _nextPeriod() {
    setState(() {
      switch (_curView) {
        case CalendarView.month:
        case CalendarView.schedule:
          if (_curMonth == 13) {
            _curMonth = null;
          } else if (_curMonth == null) {
            _curYear++;
            _curMonth = 1;
          } else {
            _curMonth = _curMonth! + 1;
          }
          _curWeek = 0;
          _curDay  = 1;
        case CalendarView.week:
          if (_curMonth == null) return;
          if (_curWeek < 3) {
            _curWeek++;
          } else if (_curMonth! < 13) {
            _curMonth = _curMonth! + 1;
            _curWeek  = 0;
          } else {
            _curMonth = null;
            _curWeek  = 0;
          }
          _curDay = _curWeek * 7 + 1;
        case CalendarView.threeDay:
          if (_curMonth == null) return;
          final nd = _curDay + 3;
          if (nd <= 28) {
            _curDay = nd;
          } else if (_curMonth! < 13) {
            _curMonth = _curMonth! + 1;
            _curDay   = 1;
          } else {
            _curMonth = null;
            _curDay   = 1;
          }
          _curWeek = (_curDay - 1) ~/ 7;
        case CalendarView.day:
          if (_curMonth == null) return;
          if (_curDay < 28) {
            _curDay++;
          } else if (_curMonth! < 13) {
            _curMonth = _curMonth! + 1;
            _curDay   = 1;
          } else {
            _curMonth = null;
            _curDay   = 1;
          }
          _curWeek = (_curDay - 1) ~/ 7;
      }
    });
  }

  void _goToMonth(int? month) => setState(() {
        _curMonth = month;
        _curWeek  = 0;
        _curDay   = 1;
      });

  void _setView(CalendarView v) {
    setState(() {
      _curView = v;
      if (v == CalendarView.week) {
        _curWeek = (_curDay - 1) ~/ 7;
      } else if (v == CalendarView.threeDay) {
        // Default to today's day if we're in the current month, clamped to ≤26
        // so that days 27–28 are still reachable in the 3-day window.
        final tc = gregorianToCeltic(DateTime.now());
        if (!tc.isYearDay && !tc.isLeapDay &&
            tc.celticYear == _curYear && tc.month == _curMonth) {
          _curDay = tc.day!.clamp(1, 26);
        }
        _curWeek = (_curDay - 1) ~/ 7;
      }
    });
  }

  void _openDay(DateTime date, {bool addEvent = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventDetailScreen(date: date, openAddForm: addEvent),
      ),
    );
  }

  void _openYearDay() => _openDay(yearDayDate(_curYear));

  // ─── Label helpers ────────────────────────────────────────────────────────────

  String get _periodTitle {
    if (_curMonth == null) return 'Year Day';
    final mo = celticMonths[_curMonth! - 1];
    switch (_curView) {
      case CalendarView.month:
        return mo.name;
      case CalendarView.threeDay:
        final end = math.min(_curDay + 2, 28);
        return '${mo.name} \u00b7 Days $_curDay\u2013$end';
      case CalendarView.week:
        return '${mo.name} \u00b7 Week ${_curWeek + 1}';
      case CalendarView.day:
        final d = celticToGregorian(_curYear, _curMonth!, _curDay);
        return '${mo.name} \u00b7 ${DateFormat('d MMM').format(d)}';
      case CalendarView.schedule:
        return 'Schedule';
    }
  }

  String get _periodKeyword {
    if (_curMonth == null) return 'Between the worlds';
    final mo = celticMonths[_curMonth! - 1];
    return '${mo.tree} \u00b7 ${mo.keyword}';
  }

  // ─── Event helpers ────────────────────────────────────────────────────────────

  Map<int, Color> _daysWithEvents(List<Event> evs) {
    final map = <int, Color>{};
    for (final e in evs) {
      final day = e.celticDay;
      if (day != null && !map.containsKey(day)) {
        try {
          map[day] = Color(int.parse('FF${e.color.replaceAll('#', '')}', radix: 16));
        } catch (_) {
          map[day] = AppColors.dark.gold;
        }
      }
    }
    return map;
  }

  /// Festival dot colour per Celtic day for the given month.
  Map<int, Color> _daysWithFestivals(int celticYear, int? month) {
    if (month == null) return {};
    final map = <int, Color>{};
    for (final f in CelticFestivalEngine.festivalsForYear(celticYear)) {
      final cd = gregorianToCeltic(f.gregorianDate);
      if (cd.month == month && cd.day != null) {
        map[cd.day!] = f.type == FestivalType.fire
            ? const Color(0xFFb07800)
            : const Color(0xFF4a3080);
      }
    }
    return map;
  }

  /// Festivals that fall in the given Celtic month.
  List<CelticFestival> _festivalsForMonth(int celticYear, int? month) {
    if (month == null) return [];
    return CelticFestivalEngine.festivalsForYear(celticYear)
        .where((f) => gregorianToCeltic(f.gregorianDate).month == month)
        .toList();
  }

  /// Moon symbols per Celtic day, filtered by user settings.
  Map<int, String> _moonSymbols(
      int celticYear, int month, MoonSettingsNotifier settings) {
    final map = <int, String>{};
    final dates = gregorianDatesForMonth(celticYear, month);
    for (int i = 0; i < dates.length; i++) {
      final phase = MoonPhaseCalculator.calculate(dates[i]);
      if ((phase.isFullMoon && settings.showFullMoons) ||
          (phase.isNewMoon  && settings.showNewMoons)) {
        map[i + 1] = phase.symbol;
      }
    }
    return map;
  }

  // ─── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c            = context.colors;
    final dao          = context.read<EventsDao>();
    final moonSettings = context.watch<MoonSettingsNotifier>();

    final isSchedule = _curView == CalendarView.schedule;

    final stream = isSchedule
        ? dao.watchEventsForYear(_curYear)
        : _curMonth != null
            ? dao.watchEventsForMonth(_curYear, _curMonth!)
            : dao.watchYearDayEvents(_curYear);

    return Scaffold(
      backgroundColor: c.bg,
      // ── Drawer ──────────────────────────────────────────────────────────
      drawer: _AppDrawer(
        celticYear: _curYear,
        curMonth: _curMonth,
        curView: _curView,
        onViewSelected: (v) {
          Navigator.pop(context);
          _setView(v);
        },
        onMonthSelected: (m) {
          Navigator.pop(context);
          _goToMonth(m);
        },
        onSettingsTap: () {
          Navigator.pop(context);
          Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()));
        },
      ),
      // ── AppBar ──────────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0.5,
        shadowColor: c.border,
        leading: Builder(builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu),
          color: c.muted,
          onPressed: () => Scaffold.of(ctx).openDrawer(),
          tooltip: 'Menu',
        )),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_periodTitle,
                style: AppTextStyles.cinzel(
                    size: 14, weight: FontWeight.w700, color: c.text),
                overflow: TextOverflow.ellipsis),
            Text(_periodKeyword,
                style: AppTextStyles.imFell(
                    size: 11, color: c.gold, italic: true)),
          ],
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            color: c.muted,
            onPressed: _prevPeriod,
            tooltip: 'Previous',
          ),
          TextButton(
            onPressed: () => setState(_jumpToToday),
            style: TextButton.styleFrom(
              foregroundColor: c.muted,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(48, 44),
            ),
            child: Text('Today',
                style: AppTextStyles.cinzel(
                    size: 11, color: c.muted, letterSpacing: 0.5)),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            color: c.muted,
            onPressed: _nextPeriod,
            tooltip: 'Next',
          ),
        ],
      ),
      // ── FAB ─────────────────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openDay(_fabDate(), addEvent: true),
        backgroundColor: c.muted,
        foregroundColor: c.surface,
        shape: const CircleBorder(),
        child: const Icon(Icons.add),
      ),
      // ── Body ────────────────────────────────────────────────────────────
      body: SafeArea(
        bottom: true,
        child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: (details) {
          final v = details.primaryVelocity ?? 0;
          if (v < -300) _nextPeriod();
          if (v > 300) _prevPeriod();
        },
        child: StreamBuilder<List<Event>>(
        key: ValueKey(isSchedule ? '$_curYear-schedule' : '$_curYear-$_curMonth'),
        stream: stream,
        builder: (context, snapshot) {
          final allEvents   = snapshot.data ?? [];
          final eventsReady = snapshot.hasData;

          // Schedule, Day, Week, 3-Day all manage their own scroll —
          // do not nest them inside a SingleChildScrollView.
          if (_curView == CalendarView.schedule) {
            return ScheduleView(
              celticYear: _curYear,
              events: allEvents,
              onEventTap: _openDay,
            );
          }

          if (_curMonth != null) {
            switch (_curView) {
              case CalendarView.threeDay:
                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: WeekView(
                    celticYear: _curYear,
                    month: _curMonth!,
                    startDay: _curDay,
                    nDays: 3,
                    events: allEvents,
                    onDayTap: (cd) => setState(() {
                      _curDay  = cd;
                      _curView = CalendarView.day;
                    }),
                    onEventTap: _openDay,
                  ),
                );
              case CalendarView.week:
                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: WeekView(
                    celticYear: _curYear,
                    month: _curMonth!,
                    startDay: _curWeek * 7 + 1,
                    nDays: 7,
                    events: allEvents,
                    onDayTap: (cd) => setState(() {
                      _curDay  = cd;
                      _curView = CalendarView.day;
                    }),
                    onEventTap: _openDay,
                  ),
                );
              case CalendarView.day:
                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: DayView(
                    celticYear: _curYear,
                    month: _curMonth!,
                    day: _curDay,
                    events: allEvents
                        .where((e) => e.celticDay == _curDay)
                        .toList(),
                    festivalsForDay: eventsReady
                        ? _festivalsForMonth(_curYear, _curMonth)
                            .where((f) =>
                                gregorianToCeltic(f.gregorianDate).day == _curDay)
                            .toList()
                        : [],
                    onOpenDay: _openDay,
                  ),
                );
              default:
                break;
            }
          }

          // Month and YearDay: content can exceed screen height, use scroll.
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_curMonth == null)
                  YearDayCard(celticYear: _curYear, onTap: _openYearDay)
                else
                  DayGrid(
                    celticYear: _curYear,
                    month: _curMonth!,
                    daysWithEvents:     _daysWithEvents(allEvents),
                    daysWithFestivals:  eventsReady ? _daysWithFestivals(_curYear, _curMonth) : {},
                    moonSymbols:        _moonSymbols(_curYear, _curMonth!, moonSettings),
                    events:             allEvents,
                    festivalsThisMonth: eventsReady ? _festivalsForMonth(_curYear, _curMonth) : [],
                    onDayTap:           _openDay,
                    onDayLongPress:     (d) => _openDay(d, addEvent: true),
                    onEventTap:         _openDay,
                  ),
              ],
            ),
          );
        },
        ),
        ),
      ),
    );
  }

  DateTime _fabDate() {
    if (_curMonth == null) return yearDayDate(_curYear);
    if (_curView == CalendarView.day) {
      return celticToGregorian(_curYear, _curMonth!, _curDay);
    }
    final today = DateTime.now();
    final tc = gregorianToCeltic(today);
    if (!tc.isYearDay && !tc.isLeapDay &&
        tc.celticYear == _curYear && tc.month == _curMonth) {
      return DateTime(today.year, today.month, today.day);
    }
    return celticToGregorian(_curYear, _curMonth!, 1);
  }
}

// ── Drawer ────────────────────────────────────────────────────────────────────

class _AppDrawer extends StatelessWidget {
  final int celticYear;
  final int? curMonth;
  final CalendarView curView;
  final void Function(CalendarView) onViewSelected;
  final void Function(int?) onMonthSelected;
  final VoidCallback onSettingsTap;

  const _AppDrawer({
    required this.celticYear,
    required this.curMonth,
    required this.curView,
    required this.onViewSelected,
    required this.onMonthSelected,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    final c     = context.colors;
    final today = DateTime.now();
    final todayC = gregorianToCeltic(today);

    return Drawer(
      backgroundColor: c.surface,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
              decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: c.border))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Roots Calendar',
                      style: AppTextStyles.cinzel(
                          size: 15,
                          weight: FontWeight.w700,
                          color: c.muted,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 3),
                  Text('Celtic Tree Calendar \u00b7 13 months',
                      style: AppTextStyles.imFell(
                          size: 12, color: c.dim, italic: true)),
                ],
              ),
            ),

            // View section
            _DrawerSection(label: 'View', colors: c),
            _ViewBtn(label: '\u263d  Month',    view: CalendarView.month,    curView: curView, colors: c, onTap: onViewSelected),
            _ViewBtn(label: '\u29c4  3 Days',   view: CalendarView.threeDay, curView: curView, colors: c, onTap: onViewSelected),
            _ViewBtn(label: '\u25a6  Week',     view: CalendarView.week,     curView: curView, colors: c, onTap: onViewSelected),
            _ViewBtn(label: '\u25c8  Day',      view: CalendarView.day,      curView: curView, colors: c, onTap: onViewSelected),
            _ViewBtn(label: '\u2630  Schedule', view: CalendarView.schedule, curView: curView, colors: c, onTap: onViewSelected),

            // Months section
            _DrawerSection(label: 'Months', colors: c),
            ...celticMonths.map((mo) {
              final isActive = curMonth == mo.number;
              final containsToday = !todayC.isYearDay &&
                  !todayC.isLeapDay &&
                  todayC.celticYear == celticYear &&
                  todayC.month == mo.number;
              return _MonthBtn(
                mo: mo,
                celticYear: celticYear,
                isActive: isActive,
                containsToday: containsToday,
                colors: c,
                onTap: () => onMonthSelected(mo.number),
              );
            }),
            // Year Day
            _MonthBtnYD(
              isActive: curMonth == null,
              containsToday: todayC.isYearDay && todayC.celticYear == celticYear,
              colors: c,
              onTap: () => onMonthSelected(null),
            ),

            // Settings
            _DrawerSection(label: 'Settings', colors: c),
            InkWell(
              onTap: onSettingsTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined, size: 18, color: c.dim),
                    const SizedBox(width: 12),
                    Text('Settings',
                        style: AppTextStyles.cinzel(size: 13, color: c.gold2)),
                    const Spacer(),
                    Icon(Icons.chevron_right, size: 18, color: c.dim),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _DrawerSection extends StatelessWidget {
  final String label;
  final AppColors colors;
  const _DrawerSection({required this.label, required this.colors});

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Container(
      color: c.bg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(label.toUpperCase(),
          style: AppTextStyles.cinzel(
              size: 9, color: c.dim, letterSpacing: 1.2, weight: FontWeight.w600)),
    );
  }
}

class _ViewBtn extends StatelessWidget {
  final String label;
  final CalendarView view;
  final CalendarView curView;
  final AppColors colors;
  final void Function(CalendarView) onTap;

  const _ViewBtn({
    required this.label,
    required this.view,
    required this.curView,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c        = colors;
    final isActive = view == curView;
    return InkWell(
      onTap: () => onTap(view),
      child: Container(
        color: isActive ? c.todayBg : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          label,
          style: AppTextStyles.cinzel(
              size: 13,
              color: isActive ? c.muted : c.gold2,
              weight: isActive ? FontWeight.w700 : FontWeight.w400,
              letterSpacing: 0.3),
        ),
      ),
    );
  }
}

class _MonthBtn extends StatelessWidget {
  final CelticMonth mo;
  final int celticYear;
  final bool isActive;
  final bool containsToday;
  final AppColors colors;
  final VoidCallback onTap;

  static final _fmt = DateFormat('d MMM');

  const _MonthBtn({
    required this.mo,
    required this.celticYear,
    required this.isActive,
    required this.containsToday,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final dates = gregorianDatesForMonth(celticYear, mo.number);
    final range = '${_fmt.format(dates.first)} – ${_fmt.format(dates.last)}';
    return InkWell(
      onTap: onTap,
      child: Container(
        color: isActive ? c.todayBg : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              child: Text('${mo.number}',
                  style: AppTextStyles.cinzel(size: 10, color: c.dim),
                  textAlign: TextAlign.right),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mo.name,
                      style: AppTextStyles.cinzel(
                          size: 13,
                          color: isActive ? c.muted : c.gold2,
                          weight: isActive ? FontWeight.w700 : FontWeight.w400)),
                  Text(range,
                      style: AppTextStyles.cinzel(size: 9, color: c.dim)),
                ],
              ),
            ),
            Text(mo.keyword,
                style: AppTextStyles.imFell(size: 11, color: c.dim, italic: true)),
            const SizedBox(width: 6),
            if (containsToday)
              Container(
                width: 7, height: 7,
                decoration: BoxDecoration(
                    color: c.muted, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}

class _MonthBtnYD extends StatelessWidget {
  final bool isActive;
  final bool containsToday;
  final AppColors colors;
  final VoidCallback onTap;

  const _MonthBtnYD({
    required this.isActive,
    required this.containsToday,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return InkWell(
      onTap: onTap,
      child: Container(
        color: isActive ? c.todayBg : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(
          children: [
            const SizedBox(width: 30),
            Text('Year Day',
                style: AppTextStyles.cinzel(
                    size: 13,
                    color: isActive ? c.muted : c.gold2,
                    weight: isActive ? FontWeight.w700 : FontWeight.w400)),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Between the worlds',
                  style: AppTextStyles.imFell(
                      size: 11, color: c.dim, italic: true),
                  overflow: TextOverflow.ellipsis),
            ),
            if (containsToday)
              Container(
                width: 7, height: 7,
                decoration: BoxDecoration(
                    color: c.muted, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}
