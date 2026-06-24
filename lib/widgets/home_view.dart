import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../db/database.dart';
import '../engine/astronomy.dart';
import '../engine/celtic_calendar.dart';
import '../engine/moon_phase.dart';
import '../services/location_helper.dart';
import '../theme/app_theme.dart';
import '../theme/sky_settings_notifier.dart';
import 'time_grid_shared.dart';

// ── Formatters (module-level, created once) ───────────────────────────────────
final _timeFmt = DateFormat('HH:mm');
final _gregFmt = DateFormat('d MMM');
final _dayFmt   = DateFormat('d');
final _dateFmt  = DateFormat('d MMM');
final _gregShortFmt = DateFormat('d/M');

// ─────────────────────────────────────────────────────────────────────────────

/// Home dashboard: moon card, data grid, calendar, phase strip, events.
class HomeView extends StatefulWidget {
  final int celticYear;
  final int? celticMonth;
  final DateTime selectedDate;
  final List<Event> events;
  final void Function(DateTime) onDayTap;

  const HomeView({
    super.key,
    required this.celticYear,
    required this.celticMonth,
    required this.selectedDate,
    required this.events,
    required this.onDayTap,
  });

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureLocation());
  }

  Future<void> _ensureLocation() async {
    if (!mounted) return;
    final sky = context.read<SkySettingsNotifier>();
    if (sky.latitude != null) return;
    await LocationHelper.requestAndSave(context);
  }

  double _equationOfTime(DateTime date) {
    final n = date.difference(DateTime(date.year, 1, 1)).inDays.toDouble();
    final b = (360 / 365) * (n - 81) * (math.pi / 180);
    return 9.87 * math.sin(2 * b) - 7.53 * math.cos(b) - 1.5 * math.sin(b);
  }

  double _solarTime(DateTime now, double longitudeDeg) {
    final utcH = now.toUtc().hour +
        now.toUtc().minute / 60.0 +
        now.toUtc().second / 3600.0;
    final lmst = utcH + (longitudeDeg / 15.0);
    return lmst + _equationOfTime(now) / 60.0;
  }

  @override
  Widget build(BuildContext context) {
    final c         = context.colors;
    final sky       = context.watch<SkySettingsNotifier>();
    final today     = DateTime.now();
    final sel       = widget.selectedDate;
    final phase     = MoonPhaseCalculator.calculate(sel);
    final zodiac    = AstronomyEngine.zodiacForDate(sel);
    final sun       = (sky.latitude != null && sky.longitude != null)
        ? AstronomyEngine.sunTimesFor(sel, sky.latitude!, sky.longitude!)
        : null;
    final proximity = AstronomyEngine.lunarProximityFraction(sel);
    final distKm    = AstronomyEngine.lunarDistanceKm(proximity);

    // Solar time is always "now" — it's a live clock
    String? solarStr;
    if (sky.longitude != null) {
      final h        = _solarTime(today, sky.longitude!) % 24;
      final totalSec = (h * 3600).round();
      final hh       = (totalSec ~/ 3600).toString().padLeft(2, '0');
      final mm       = ((totalSec % 3600) ~/ 60).toString().padLeft(2, '0');
      solarStr       = '$hh:$mm';
    }

    final bio = AstronomyEngine.biodynamicForZodiac(zodiac);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MoonHeroCard(phase: phase, zodiac: zodiac, solarStr: solarStr, c: c, southernHemisphere: sky.latitude != null && sky.latitude! < 0),
          const SizedBox(height: 16),
          _DataGrid(sun: sun, distKm: distKm, bio: bio, c: c),
          const SizedBox(height: 20),
          _HomeCalGrid(
            selectedDate: sel,
            today: today,
            events: widget.events,
            onDayTap: widget.onDayTap,
            c: c,
          ),
          const SizedBox(height: 16),
          _MoonPhaseStrip(date: sel, c: c, southernHemisphere: sky.latitude != null && sky.latitude! < 0),
          const SizedBox(height: 20),
          _EventsList(events: widget.events, onDayTap: widget.onDayTap, c: c),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ── Moon hero card ─────────────────────────────────────────────────────────────

class _MoonHeroCard extends StatelessWidget {
  final MoonPhase phase;
  final MoonZodiac zodiac;
  final String? solarStr;
  final AppColors c;
  final bool southernHemisphere;

  const _MoonHeroCard({
    required this.phase,
    required this.zodiac,
    required this.solarStr,
    required this.c,
    this.southernHemisphere = false,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (phase.illumination * 100).round();
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.border),
      ),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        children: [
          Container(
            width: 130,
            height: 130,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: c.gold.withValues(alpha: 0.22),
                  blurRadius: 28,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: CustomPaint(
              painter: _MoonPainter(age: phase.age, c: c, southernHemisphere: southernHemisphere),
            ),
          ),
          Text(
            phase.name,
            style: AppTextStyles.cinzelDeco(size: 20, color: c.text),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: c.gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: c.gold.withValues(alpha: 0.30)),
            ),
            child: Text(
              '$pct% ILLUMINATED',
              style: AppTextStyles.cinzel(
                  size: 10,
                  color: c.gold,
                  letterSpacing: 0.12,
                  weight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 22),
          IntrinsicHeight(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Stat(label: 'Solar Time', value: solarStr ?? '—', c: c),
                VerticalDivider(width: 40, thickness: 1, color: c.border),
                _Stat(
                  label: 'Sign',
                  value: '${zodiac.symbol} ${zodiac.label}',
                  c: c,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final AppColors c;

  const _Stat({required this.label, required this.value, required this.c});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: AppTextStyles.cinzel(
              size: 9,
              color: c.muted,
              letterSpacing: 0.14,
              weight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.cinzel(
              size: 15, color: c.text, weight: FontWeight.w600),
        ),
      ],
    );
  }
}

// ── Moon painter ───────────────────────────────────────────────────────────────

class _MoonPainter extends CustomPainter {
  final double age;
  final AppColors c;
  // Southern Hemisphere observers see the lit side mirrored left↔right.
  final bool southernHemisphere;

  const _MoonPainter({required this.age, required this.c, this.southernHemisphere = false});

  @override
  void paint(Canvas canvas, Size size) {
    final r      = size.width / 2;
    final center = Offset(r, r);
    final frac   = age / 29.53;
    // Southern Hemisphere observers see the lit side mirrored: waxing appears on
    // the left instead of the right.
    final waxing = southernHemisphere ? frac > 0.5 : frac <= 0.5;

    // 1. Dark base circle
    canvas.drawCircle(center, r, Paint()..color = c.bg);

    // 2. Clip and draw lit portion
    canvas.save();
    canvas.clipPath(Path()
      ..addOval(Rect.fromCircle(center: center, radius: r)));

    final litPath = _litPath(r, center, frac, waxing);

    final shader = RadialGradient(
      center: const Alignment(-0.25, -0.3),
      colors: [c.cream, c.gold, const Color(0xFF7a5c20)],
      stops: const [0.0, 0.45, 1.0],
    ).createShader(Rect.fromCircle(center: center, radius: r));

    canvas.drawPath(litPath, Paint()..shader = shader);

    // 3. Crater texture on the lit area
    final craterPaint = Paint()
      ..color = c.bg.withValues(alpha: 0.18)
      ..style  = PaintingStyle.fill;
    canvas.drawCircle(Offset(center.dx + r * 0.20, center.dy - r * 0.26), r * 0.12, craterPaint);
    canvas.drawCircle(Offset(center.dx + r * 0.38, center.dy + r * 0.11), r * 0.09, craterPaint);
    canvas.drawCircle(Offset(center.dx - r * 0.05, center.dy + r * 0.33), r * 0.07, craterPaint);
    canvas.drawCircle(Offset(center.dx + r * 0.17, center.dy - r * 0.43), r * 0.055, craterPaint);
    canvas.drawCircle(Offset(center.dx + r * 0.48, center.dy - r * 0.10), r * 0.065, craterPaint);

    canvas.restore();
  }

  Path _litPath(double r, Offset center, double frac, bool waxing) {
    // New moon: nothing lit
    if (frac < 0.02) return Path();

    // Full moon: complete circle
    if (frac > 0.48 && frac < 0.52) {
      return Path()..addOval(Rect.fromCircle(center: center, radius: r));
    }

    // Semicircle on the correct side
    final halfPath = Path();
    if (waxing) {
      // Right half — arc from top, sweeping π radians clockwise
      halfPath.moveTo(center.dx, center.dy - r);
      halfPath.arcTo(
          Rect.fromCircle(center: center, radius: r), -math.pi / 2, math.pi, false);
      halfPath.close();
    } else {
      // Left half — arc from bottom, sweeping π radians clockwise
      halfPath.moveTo(center.dx, center.dy + r);
      halfPath.arcTo(
          Rect.fromCircle(center: center, radius: r), math.pi / 2, math.pi, false);
      halfPath.close();
    }

    // Ellipse terminator: |cos(2π·frac)| = 1 at new/full moon, 0 at both quarters.
    // This is the correct geometric relationship: the terminator ellipse collapses
    // to a straight line (rx=0) at first/last quarter, giving an exact half-circle.
    final adjustFrac = math.cos(2 * math.pi * frac).abs();
    final ellipseRx  = r * adjustFrac;
    if (ellipseRx < 1) return halfPath;

    final ellipsePath = Path()
      ..addOval(Rect.fromCenter(
          center: center, width: ellipseRx * 2, height: r * 2));

    if (waxing) {
      // Crescent: remove shadow ellipse; gibbous: add lit ellipse
      return frac < 0.25
          ? Path.combine(PathOperation.difference, halfPath, ellipsePath)
          : Path.combine(PathOperation.union, halfPath, ellipsePath);
    } else {
      // Waning gibbous: add; waning crescent: remove
      return frac < 0.75
          ? Path.combine(PathOperation.union, halfPath, ellipsePath)
          : Path.combine(PathOperation.difference, halfPath, ellipsePath);
    }
  }

  @override
  bool shouldRepaint(_MoonPainter old) =>
      old.age != age || old.c != c || old.southernHemisphere != southernHemisphere;
}

// ── 2×2 data grid ─────────────────────────────────────────────────────────────

class _DataGrid extends StatelessWidget {
  final SunTimes? sun;
  final int distKm;
  final BiodynamicType bio;
  final AppColors c;

  const _DataGrid({
    required this.sun,
    required this.distKm,
    required this.bio,
    required this.c,
  });

  String _fmtKm(int km) {
    final t = km ~/ 1000;
    final rem = (km % 1000).toString().padLeft(3, '0');
    return '$t,$rem km';
  }

  @override
  Widget build(BuildContext context) {
    final sunriseStr = sun != null ? _timeFmt.format(sun!.sunrise.toLocal()) : '—';
    final sunsetStr  = sun != null ? _timeFmt.format(sun!.sunset.toLocal())  : '—';

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.5,
      children: [
        _DataCard(
          icon: Icon(Icons.wb_twilight_outlined, color: c.gold, size: 18),
          label: 'Sunrise',
          value: sunriseStr,
          c: c,
        ),
        _DataCard(
          icon: Icon(Icons.nights_stay_outlined, color: c.gold, size: 18),
          label: 'Sunset',
          value: sunsetStr,
          c: c,
        ),
        _DataCard(
          icon: Icon(Icons.radio_button_unchecked, color: c.gold, size: 18),
          label: 'Distance',
          value: _fmtKm(distKm),
          c: c,
        ),
        _DataCard(
          icon: Text(bio.symbol,
              style: const TextStyle(fontSize: 16, height: 1)),
          label: 'Sowing',
          value: bio.label,
          c: c,
        ),
      ],
    );
  }
}

class _DataCard extends StatelessWidget {
  final Widget icon;
  final String label;
  final String value;
  final AppColors c;

  const _DataCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: c.surface2,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(child: icon),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label.toUpperCase(),
                  style: AppTextStyles.cinzel(
                      size: 7,
                      color: c.muted,
                      letterSpacing: 0.14,
                      weight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTextStyles.cinzel(
                      size: 13, color: c.text, weight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Compact calendar grid ──────────────────────────────────────────────────────

class _HomeCalGrid extends StatelessWidget {
  final DateTime selectedDate;
  final DateTime today;
  final List<Event> events;
  final void Function(DateTime) onDayTap;
  final AppColors c;

  const _HomeCalGrid({
    required this.selectedDate,
    required this.today,
    required this.events,
    required this.onDayTap,
    required this.c,
  });

  static const _weekdayNames = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

  @override
  Widget build(BuildContext context) {
    final selCeltic = gregorianToCeltic(selectedDate);
    if (selCeltic.isYearDay || selCeltic.isLeapDay) return const SizedBox.shrink();

    final celticYear  = selCeltic.celticYear;
    final celticMonth = selCeltic.month!;
    final mo    = celticMonths[celticMonth - 1];
    final dates = gregorianDatesForMonth(celticYear, celticMonth);

    // monthStartWeekday returns 0=Sun…6=Sat; convert to Mon-first offset
    final startDow      = monthStartWeekday(celticYear);
    final moFirstOffset = (startDow - 1 + 7) % 7;

    final tc = gregorianToCeltic(today);
    int? todayCDay;
    if (!tc.isYearDay && !tc.isLeapDay &&
        tc.celticYear == celticYear && tc.month == celticMonth) {
      todayCDay = tc.day;
    }
    final selectedCDay = selCeltic.day!;

    final eventDays = <int>{};
    for (final e in events) {
      if (e.celticDay != null) eventDays.add(e.celticDay!);
    }

    final gregRange = '${_gregFmt.format(dates.first)} – ${_gregFmt.format(dates.last)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Celtic month card — left-anchor layout
        Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.border),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left column: large ogham letter
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 18),
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: c.border)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        mo.ogham,
                        style: AppTextStyles.cinzel(
                            size: 48, color: c.gold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'OGHAM',
                        style: AppTextStyles.cinzel(
                            size: 8,
                            color: c.muted,
                            letterSpacing: 0.16,
                            weight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                // Right body: name / tree / keyword / date range
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mo.name,
                          style: AppTextStyles.cinzelDeco(
                              size: 20, color: c.text),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          mo.tree,
                          style: AppTextStyles.cinzel(
                              size: 13,
                              color: c.text,
                              weight: FontWeight.w600),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          mo.keyword,
                          style: AppTextStyles.imFell(
                              size: 14, color: c.muted, italic: true),
                        ),
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            gregRange.toUpperCase(),
                            style: AppTextStyles.cinzel(
                                size: 9,
                                color: c.dim,
                                letterSpacing: 0.12,
                                weight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Grid container
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: c.border),
            ),
            child: Column(
              children: [
                // Day-of-week headers
                Container(
                  decoration: BoxDecoration(
                    color: c.surface2,
                    border: Border(
                        bottom: BorderSide(color: c.border)),
                  ),
                  child: Row(
                    children: _weekdayNames
                        .map((d) => Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  d,
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.cinzel(
                                      size: 9,
                                      color: c.muted,
                                      letterSpacing: 0.1,
                                      weight: FontWeight.w600),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ),

                // Day cells
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: moFirstOffset + 28,
                  itemBuilder: (_, i) {
                    if (i < moFirstOffset) return const SizedBox.shrink();
                    final day      = i - moFirstOffset + 1;
                    final gregDate = dates[day - 1];
                    return GestureDetector(
                      onTap: () => onDayTap(gregDate),
                      child: _CalCell(
                        day: day,
                        gregDate: gregDate,
                        isToday: day == todayCDay,
                        isSelected: day == selectedCDay && day != todayCDay,
                        hasEvent: eventDays.contains(day),
                        c: c,
                        isLast: i >= moFirstOffset + 27,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CalCell extends StatelessWidget {
  final int day;
  final DateTime gregDate;
  final bool isToday;
  final bool isSelected;
  final bool hasEvent;
  final bool isLast;
  final AppColors c;

  const _CalCell({
    required this.day,
    required this.gregDate,
    required this.isToday,
    required this.isSelected,
    required this.hasEvent,
    required this.isLast,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: (isToday || isSelected) ? c.gold.withValues(alpha: 0.08) : null,
        border: Border(
          right: BorderSide(color: c.border.withValues(alpha: 0.5), width: 0.5),
          bottom: isLast
              ? BorderSide.none
              : BorderSide(color: c.border.withValues(alpha: 0.5), width: 0.5),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isToday)
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: c.gold,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: c.gold.withValues(alpha: 0.35), blurRadius: 8),
                ],
              ),
            )
          else if (isSelected)
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: c.gold, width: 1.5),
              ),
            ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$day',
                style: AppTextStyles.cinzel(
                    size: 12,
                    color: isToday ? c.bg : isSelected ? c.gold : c.text,
                    weight: (isToday || isSelected) ? FontWeight.w700 : FontWeight.w400),
              ),
              Text(
                _dayFmt.format(gregDate),
                style: AppTextStyles.cinzel(
                    size: 8,
                    color: isToday
                        ? c.bg.withValues(alpha: 0.7)
                        : isSelected
                            ? c.gold.withValues(alpha: 0.7)
                            : c.muted),
              ),
            ],
          ),
          if (hasEvent && !isToday && !isSelected)
            Positioned(
              bottom: 4,
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(color: c.gold, shape: BoxShape.circle),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Moon phase strip ───────────────────────────────────────────────────────────

class _MoonPhaseStrip extends StatelessWidget {
  final DateTime date;
  final AppColors c;
  final bool southernHemisphere;

  const _MoonPhaseStrip({required this.date, required this.c, this.southernHemisphere = false});

  static const _phaseTargets = [
    (label: 'New Moon',      minAge: 0.0,  maxAge: 1.5),
    (label: 'First Quarter', minAge: 7.4,  maxAge: 8.4),
    (label: 'Full Moon',     minAge: 13.5, maxAge: 16.5),
    (label: 'Last Quarter',  minAge: 22.1, maxAge: 23.1),
  ];

  List<({double age, DateTime date, String label})> _nextPhases() {
    final result = <({double age, DateTime date, String label})>[];
    for (final t in _phaseTargets) {
      var d = DateTime.utc(date.year, date.month, date.day);
      for (int i = 0; i < 35; i++) {
        final p = MoonPhaseCalculator.calculate(d);
        if (p.age >= t.minAge && p.age < t.maxAge) {
          result.add((age: p.age, date: d, label: t.label));
          break;
        }
        d = d.add(const Duration(days: 1));
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final phases     = _nextPhases();
    final todayPhase = MoonPhaseCalculator.calculate(date);

    bool _isActive(({double age, DateTime date, String label}) p) {
      switch (p.label) {
        case 'New Moon':
          return todayPhase.isNewMoon;
        case 'First Quarter':
          return todayPhase.age >= 7.4 && todayPhase.age < 8.4;
        case 'Full Moon':
          return todayPhase.isFullMoon;
        case 'Last Quarter':
          return todayPhase.age >= 22.1 && todayPhase.age < 23.1;
        default:
          return false;
      }
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MOON PHASES THIS MONTH',
            style: AppTextStyles.cinzel(
                size: 9,
                color: c.muted,
                letterSpacing: 0.12,
                weight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: phases.map((p) {
              final active = _isActive(p);
              return Column(
                children: [
                  Opacity(
                    opacity: active ? 1.0 : 0.40,
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CustomPaint(
                          painter: _MoonPainter(age: p.age, c: c, southernHemisphere: southernHemisphere)),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _dateFmt.format(p.date),
                    style: AppTextStyles.cinzel(
                        size: 8,
                        color: active ? c.gold : c.muted,
                        letterSpacing: 0.06),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Events list ────────────────────────────────────────────────────────────────

class _EventsList extends StatelessWidget {
  final List<Event> events;
  final void Function(DateTime) onDayTap;
  final AppColors c;

  const _EventsList({
    required this.events,
    required this.onDayTap,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    final now     = DateTime.now();
    final cutoff  = DateTime(now.year, now.month, now.day);
    final sorted  = [...events]
      ..sort((a, b) => a.gregorianDate.compareTo(b.gregorianDate));
    final upcoming = sorted
        .where((e) => !e.gregorianDate.isBefore(cutoff))
        .take(5)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: c.border, height: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'EVENTS THIS MONTH',
                style: AppTextStyles.cinzel(
                    size: 9,
                    color: c.muted,
                    letterSpacing: 0.16,
                    weight: FontWeight.w600),
              ),
            ),
            Expanded(child: Divider(color: c.border, height: 1)),
          ],
        ),
        const SizedBox(height: 14),
        if (upcoming.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No events this month',
              textAlign: TextAlign.center,
              style: AppTextStyles.imFell(
                  size: 13, color: c.dim, italic: true),
            ),
          )
        else
          ...upcoming.map(
              (e) => _EventCard(event: e, onTap: () => onDayTap(e.gregorianDate), c: c)),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  final Event event;
  final VoidCallback onTap;
  final AppColors c;

  const _EventCard({
    required this.event,
    required this.onTap,
    required this.c,
  });

  String _fmtMinutes(int minutes) {
    final h  = (minutes ~/ 60) % 24;
    final m  = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final celticDay = event.celticDay ?? 0;
    String timeStr;
    if (event.startMinutes != null) {
      final end = event.startMinutes! + (event.durationMinutes ?? 60);
      timeStr   = '${_fmtMinutes(event.startMinutes!)} – ${_fmtMinutes(end)}';
    } else {
      timeStr = 'All day';
    }
    final color = parseHexColor(event.color);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            // Date column
            SizedBox(
              width: 44,
              child: Column(
                children: [
                  Text(
                    '$celticDay',
                    style: AppTextStyles.cinzel(
                        size: 18, color: c.text, weight: FontWeight.w600),
                  ),
                  Text(
                    _gregShortFmt.format(event.gregorianDate),
                    style:
                        AppTextStyles.cinzel(size: 9, color: c.muted),
                  ),
                ],
              ),
            ),
            Container(
                width: 1, height: 40, color: c.border, margin: const EdgeInsets.symmetric(horizontal: 14)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style: AppTextStyles.cinzel(
                              size: 14,
                              color: c.text,
                              weight: FontWeight.w600),
                        ),
                      ),
                      Icon(Icons.chevron_right, size: 16, color: c.dim),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        width: 3,
                        height: 16,
                        decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(2)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeStr,
                        style: AppTextStyles.cinzel(
                            size: 11, color: c.muted, letterSpacing: 0.06),
                      ),
                    ],
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
