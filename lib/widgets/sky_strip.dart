import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../engine/astronomy.dart';
import '../engine/celtic_calendar.dart';
import '../engine/moon_phase.dart';
import '../services/location_helper.dart';
import '../theme/app_theme.dart';
import '../theme/sky_settings_notifier.dart';

/// Collapsible astronomical instrument strip.
///
/// Collapsed : moon phase · sun times (single Cinzel line).
/// Expanded  : symbol-anchored rows — moon, zodiac, sowing, sun, moon distance,
///             next solar event (tappable), meteor shower.
///
/// [onSolarEventTap] — called with the Gregorian date of the next solar event
/// when the user taps that row. Pass [Navigator] logic here to jump to the date.
class SkyStrip extends StatefulWidget {
  final DateTime date;
  final bool initiallyExpanded;
  final bool showSolarTime;
  final void Function(DateTime)? onSolarEventTap;
  final void Function(bool)? onExpandedChanged;

  const SkyStrip({
    super.key,
    required this.date,
    this.initiallyExpanded = false,
    this.showSolarTime = false,
    this.onSolarEventTap,
    this.onExpandedChanged,
  });

  @override
  State<SkyStrip> createState() => _SkyStripState();
}

class _SkyStripState extends State<SkyStrip> {
  late bool _expanded;
  Timer? _timer;
  DateTime _now = DateTime.now();
  static final _timeFmt = DateFormat('HH:mm');
  static final _dateFmt = DateFormat('d MMM  HH:mm');

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c        = context.colors;
    final settings = context.watch<SkySettingsNotifier>();

    if (!settings.showSkyPanel) return const SizedBox.shrink();

    final phase       = MoonPhaseCalculator.calculate(widget.date);
    final zodiac      = AstronomyEngine.zodiacForDate(widget.date);
    final bio         = AstronomyEngine.biodynamicForZodiac(zodiac);
    final sun         = (settings.latitude != null && settings.longitude != null)
        ? AstronomyEngine.sunTimesFor(widget.date, settings.latitude!, settings.longitude!)
        : null;
    final proximity   = AstronomyEngine.lunarProximityFraction(widget.date);
    final distKm      = AstronomyEngine.lunarDistanceKm(proximity);
    final solar       = AstronomyEngine.nextSolarEvent(widget.date);
    final shower      = AstronomyEngine.meteorShowerNear(widget.date);
    final pct         = (phase.illumination * 100).round();
    final isSupermoon = proximity > 0.92;

    // Solar time value (updated every second via _timer) — only when location is known
    final solarStr = settings.longitude != null
        ? _fmtHms(_solarTime(_now, settings.longitude!))
        : null;

    // Celtic month name for expanded header.
    final cd         = gregorianToCeltic(widget.date);
    final monthLabel = cd.monthData?.name.toUpperCase() ??
        (cd.isYearDay ? 'YEAR DAY' : 'LEAP DAY');
    final dateLabel  = DateFormat('d MMM yyyy').format(widget.date).toUpperCase();

    // Collapsed status-bar — moon leads, no biodynamic, no icon.
    final segments = <String>[
      if (settings.showMoonPhase) '${phase.symbol}  ${phase.name}',
    ];

    return Container(
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Collapsed row ──────────────────────────────────────────────
          InkWell(
            onTap: () {
              setState(() => _expanded = !_expanded);
              widget.onExpandedChanged?.call(_expanded);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          segments.join('  \u00b7  '),
                          style: AppTextStyles.cinzel(size: 11, color: c.text),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (settings.showClocks && widget.showSolarTime && solarStr != null)
                          Text(
                            'Solar time  \u00b7  ${solarStr.substring(0, 5)}',
                            style: AppTextStyles.cinzel(size: 11, color: c.gold),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.expand_more, size: 16, color: c.text),
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded detail ────────────────────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _expanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Divider(height: 1, color: c.border),

                      // Header: CELTIC MONTH · DATE
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 5),
                        child: Text(
                          '$monthLabel  \u00b7  $dateLabel',
                          style: AppTextStyles.cinzel(
                              size: 9, color: c.text, letterSpacing: 1.4),
                        ),
                      ),

                      // 1. Moon phase
                      if (settings.showMoonPhase)
                        _InstrumentRow(
                          symbol: phase.symbol,
                          text: '${phase.name}  \u00b7  $pct%',
                          c: c,
                        ),

                      // 2. Zodiac sign
                      if (settings.showZodiac)
                        _InstrumentRow(
                          symbol: zodiac.symbol,
                          text: zodiac.label,
                          c: c,
                        ),

                      // 3. Sowing / biodynamic (own row, no badge)
                      if (settings.showBiodynamic)
                        _InstrumentRow(
                          symbol: bio.symbol,
                          text: 'Sowing  \u00b7  ${bio.label}',
                          c: c,
                        ),

                      // 4. Sun times (or location prompt)
                      if (settings.showSunTimes)
                        sun != null
                            ? _InstrumentRow(
                                symbol: '\u2609',
                                text: '\u2191 ${_timeFmt.format(sun.sunrise.toLocal())}'
                                    '  \u2193 ${_timeFmt.format(sun.sunset.toLocal())}'
                                    '  \u00b7  ${_dayLength(sun)}',
                                c: c,
                              )
                            : _TapRow(
                                symbol: '\u2609',
                                text: 'Enable location for sun times',
                                c: c,
                                onTap: () => _requestLocation(context),
                              ),

                      // 4b. Solar time (true sun)
                      if (settings.showClocks && widget.showSolarTime)
                        solarStr != null
                            ? _InstrumentRow(
                                symbol: '\u23f2',
                                text: 'Solar time (true sun)  \u00b7  $solarStr',
                                c: c,
                              )
                            : _TapRow(
                                symbol: '\u23f2',
                                text: 'Enable location for solar time',
                                c: c,
                                onTap: () => _requestLocation(context),
                              ),

                      // 5. Moon distance
                      if (settings.showMoonDistance)
                        _InstrumentRow(
                          symbol: '\u25ce',
                          text: '~${_fmtKm(distKm)} km'
                              '  \u00b7  ${AstronomyEngine.proximityLabel(proximity)}',
                          c: c,
                          badge: isSupermoon
                              ? _BadgeData('Supermoon', c.gold.withValues(alpha: 0.15))
                              : null,
                          highlight: isSupermoon,
                        ),

                      // 6. Next solar event — tappable when callback provided
                      if (settings.showSolarEvent)
                        widget.onSolarEventTap != null
                            ? _TapRow(
                                symbol: solar.symbol,
                                text: '${solar.name}  \u00b7  ${_dateFmt.format(solar.moment.toLocal())}',
                                c: c,
                                onTap: () => widget.onSolarEventTap!(
                                    solar.moment.toLocal()),
                              )
                            : _InstrumentRow(
                                symbol: solar.symbol,
                                text: '${solar.name}  \u00b7  ${_dateFmt.format(solar.moment.toLocal())}',
                                c: c,
                              ),

                      // 7. Meteor shower — always notable, always gold
                      if (shower != null)
                        _InstrumentRow(
                          symbol: shower.symbol,
                          text: '${shower.name}  \u00b7  Peak nearby',
                          c: c,
                          highlight: true,
                        ),

                      const SizedBox(height: 7),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  String _dayLength(SunTimes sun) {
    final h = sun.dayLengthMinutes ~/ 60;
    final m = sun.dayLengthMinutes % 60;
    return '${h}h ${m}m';
  }

  String _fmtKm(int km) {
    final t = km ~/ 1000;
    final r = (km % 1000).toString().padLeft(3, '0');
    return '$t,$r';
  }

  double _equationOfTime(DateTime date) {
    final n = date.difference(DateTime(date.year, 1, 1)).inDays.toDouble();
    final b = (360 / 365) * (n - 81) * (math.pi / 180);
    return 9.87 * math.sin(2 * b) - 7.53 * math.cos(b) - 1.5 * math.sin(b);
  }

  double _solarTime(DateTime now, double longitudeDeg) {
    final utcH = now.toUtc().hour + now.toUtc().minute / 60.0 + now.toUtc().second / 3600.0;
    final lmst = utcH + (longitudeDeg / 15.0);
    final eot = _equationOfTime(now);
    return lmst + eot / 60.0;
  }

  String _fmtHms(double fractionalHours) {
    final h = fractionalHours % 24;
    final totalSec = (h * 3600).round();
    final hh = (totalSec ~/ 3600).toString().padLeft(2, '0');
    final mm = ((totalSec % 3600) ~/ 60).toString().padLeft(2, '0');
    final ss = (totalSec % 60).toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  Future<void> _requestLocation(BuildContext context) =>
      LocationHelper.requestAndSave(context);
}

// ── Badge data holder ──────────────────────────────────────────────────────────

class _BadgeData {
  final String label;
  final Color bg;
  const _BadgeData(this.label, this.bg);
}

// ── Instrument row ─────────────────────────────────────────────────────────────

class _InstrumentRow extends StatelessWidget {
  final String symbol;
  final String text;
  final AppColors c;
  final _BadgeData? badge;
  final bool highlight;

  const _InstrumentRow({
    required this.symbol,
    required this.text,
    required this.c,
    this.badge,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(
              symbol,
              style: AppTextStyles.cinzel(size: 13, color: c.text),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.cinzel(
                size: 11,
                color: highlight ? c.gold : c.text,
              ),
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badge!.bg,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                badge!.label,
                style: AppTextStyles.cinzel(size: 9, color: c.text),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Tappable row ───────────────────────────────────────────────────────────────

class _TapRow extends StatelessWidget {
  final String symbol;
  final String text;
  final AppColors c;
  final VoidCallback onTap;

  const _TapRow({
    required this.symbol,
    required this.text,
    required this.c,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Text(
                symbol,
                style: AppTextStyles.cinzel(size: 13, color: c.text),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: AppTextStyles.cinzel(size: 11, color: c.gold),
              ),
            ),
            Text('\u203a', style: AppTextStyles.cinzel(size: 16, color: c.gold)),
          ],
        ),
      ),
    );
  }
}
