import 'dart:math';

import 'package:daylight/daylight.dart';

// ─── Enums ────────────────────────────────────────────────────────────────────

enum EclipseType {
  solarTotal,
  solarAnnular,
  solarHybrid,
  solarPartial,
  lunarTotal,
  lunarPartial,
}

enum MoonZodiac {
  aries,
  taurus,
  gemini,
  cancer,
  leo,
  virgo,
  libra,
  scorpio,
  sagittarius,
  capricorn,
  aquarius,
  pisces;

  String get label => const [
        'Aries', 'Taurus', 'Gemini', 'Cancer', 'Leo', 'Virgo',
        'Libra', 'Scorpio', 'Sagittarius', 'Capricorn', 'Aquarius', 'Pisces',
      ][index];

  // Astrological Unicode symbols (♈–♓)
  String get symbol => const [
        '♈', '♉', '♊', '♋', '♌', '♍', '♎', '♏', '♐', '♑', '♒', '♓',
      ][index];
}

enum BiodynamicType {
  root,
  leaf,
  fruit,
  flower;

  String get label => const ['Root', 'Leaf', 'Fruit', 'Flower'][index];
  String get symbol => const ['🌱', '🌿', '🍎', '🌸'][index];
}

// ─── Data classes ─────────────────────────────────────────────────────────────

class SunTimes {
  final DateTime sunrise; // UTC
  final DateTime sunset;  // UTC
  final int dayLengthMinutes;

  const SunTimes({
    required this.sunrise,
    required this.sunset,
    required this.dayLengthMinutes,
  });
}

class SolarEvent {
  final String name;
  final String symbol;
  final DateTime moment; // UTC

  const SolarEvent({
    required this.name,
    required this.symbol,
    required this.moment,
  });
}

class MeteorShower {
  final String name;
  final String symbol;

  const MeteorShower({required this.name, required this.symbol});
}

class Eclipse {
  final DateTime date; // UTC, moment of greatest eclipse
  final EclipseType type;
  final String label;  // e.g. "Total Solar Eclipse"
  final String symbol; // emoji

  const Eclipse(this.date, this.type, this.label, this.symbol);
}

// ─── Engine ───────────────────────────────────────────────────────────────────

class AstronomyEngine {
  AstronomyEngine._();

  // Julian Day Number — logic copied from moon_phase.dart (_toJulian is private there).
  static double _toJulian(DateTime date) {
    final y = date.year;
    final m = date.month;
    final d = date.day;
    final a = (14 - m) ~/ 12;
    final yr = y + 4800 - a;
    final mo = m + 12 * a - 3;
    return d +
        (153 * mo + 2) ~/ 5 +
        365 * yr +
        yr ~/ 4 -
        yr ~/ 100 +
        yr ~/ 400 -
        32045.0;
  }

  // Convert Julian Date to UTC DateTime.
  static DateTime _fromJulian(double jde) {
    final ms = ((jde - 2440587.5) * 86400000).round();
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }

  /// Moon's mean ecliptic longitude mapped to zodiac sign.
  /// Accuracy: within ~1 zodiac sign — sufficient for biodynamic display.
  /// Reference epoch J2000.0: moon mean longitude ≈ 218.3165°, daily motion 13.1764°/day.
  static MoonZodiac zodiacForDate(DateTime date) {
    final utc = DateTime.utc(date.year, date.month, date.day);
    final jd = _toJulian(utc);
    var lon = (218.3165 + 13.1764 * (jd - 2451545.0)) % 360.0;
    if (lon < 0) lon += 360.0;
    return MoonZodiac.values[(lon / 30).floor() % 12];
  }

  /// Biodynamic sowing type based on zodiac element.
  /// Fire (Aries/Leo/Sag) → fruit/seed  ·  Earth (Taurus/Virgo/Cap) → root
  /// Air  (Gem/Lib/Aqu)   → flower      ·  Water (Cancer/Sco/Pis)   → leaf
  static BiodynamicType biodynamicForZodiac(MoonZodiac sign) {
    switch (sign) {
      case MoonZodiac.aries:
      case MoonZodiac.leo:
      case MoonZodiac.sagittarius:
        return BiodynamicType.fruit;
      case MoonZodiac.taurus:
      case MoonZodiac.virgo:
      case MoonZodiac.capricorn:
        return BiodynamicType.root;
      case MoonZodiac.gemini:
      case MoonZodiac.libra:
      case MoonZodiac.aquarius:
        return BiodynamicType.flower;
      case MoonZodiac.cancer:
      case MoonZodiac.scorpio:
      case MoonZodiac.pisces:
        return BiodynamicType.leaf;
    }
  }

  /// Next solstice or equinox on or after [date].
  /// Meeus simplified formulae (Astronomical Algorithms, ch. 27, Table 27.a).
  /// Accuracy: ±30 min — sufficient for display.
  static SolarEvent nextSolarEvent(DateTime date) {
    final today = DateTime.utc(date.year, date.month, date.day);

    for (int yr = date.year; yr <= date.year + 1; yr++) {
      final t = (yr - 2000) / 1000.0;
      final t2 = t * t;
      final t3 = t2 * t;
      final t4 = t3 * t;

      final candidates = [
        (
          jde: 2451623.80984 + 365242.37404 * t + 0.05169 * t2
              - 0.00411 * t3 - 0.00057 * t4,
          name: 'Vernal equinox',
          symbol: '♈',
        ),
        (
          jde: 2451716.56767 + 365241.62603 * t + 0.00325 * t2
              + 0.00888 * t3 - 0.00030 * t4,
          name: 'Summer solstice',
          symbol: '♋',
        ),
        (
          jde: 2451810.21715 + 365242.01767 * t - 0.11575 * t2
              + 0.00337 * t3 + 0.00078 * t4,
          name: 'Autumnal equinox',
          symbol: '♎',
        ),
        (
          jde: 2451900.05952 + 365242.74049 * t - 0.06223 * t2
              - 0.00823 * t3 + 0.00032 * t4,
          name: 'Winter solstice',
          symbol: '♑',
        ),
      ];

      for (final c in candidates) {
        final moment = _fromJulian(c.jde);
        if (!moment.isBefore(today)) {
          return SolarEvent(name: c.name, symbol: c.symbol, moment: moment);
        }
      }
    }

    // Fallback — not reachable under normal circumstances.
    final t = (date.year + 1 - 2000) / 1000.0;
    return SolarEvent(
      name: 'Vernal equinox',
      symbol: '♈',
      moment: _fromJulian(
        2451623.80984 + 365242.37404 * t + 0.05169 * t * t,
      ),
    );
  }

  /// Fraction 0.0 (apogee — farthest) to 1.0 (perigee — closest).
  /// Based on anomalistic period 27.5545 days, reference perigee JDE 2451563.0
  /// (approx. Jan 10 2000).
  static double lunarProximityFraction(DateTime date) {
    const double anomalisticPeriod = 27.5545;
    const double referencePerigeeJDE = 2451563.0;
    final utc = DateTime.utc(date.year, date.month, date.day);
    final jd = _toJulian(utc);
    var age = (jd - referencePerigeeJDE) % anomalisticPeriod;
    if (age < 0) age += anomalisticPeriod;
    return (1 + cos(2 * pi * age / anomalisticPeriod)) / 2;
  }

  /// Approximate lunar distance in km from a [proximityFraction].
  /// Perigee ≈ 356,500 km; apogee ≈ 406,700 km.
  static int lunarDistanceKm(double fraction) =>
      (356500 + (1 - fraction) * 50200).round();

  /// Human-readable proximity label.
  static String proximityLabel(double f) {
    if (f > 0.75) return 'Close';
    if (f > 0.40) return 'Average';
    return 'Far';
  }

  static const _showers = <({int month, int day, String name})>[
    (month: 1,  day: 4,  name: 'Quadrantids'),
    (month: 4,  day: 22, name: 'Lyrids'),
    (month: 5,  day: 6,  name: 'Eta Aquariids'),
    (month: 7,  day: 30, name: 'Delta Aquariids'),
    (month: 8,  day: 12, name: 'Perseids'),
    (month: 10, day: 8,  name: 'Draconids'),
    (month: 10, day: 21, name: 'Orionids'),
    (month: 11, day: 5,  name: 'Southern Taurids'),
    (month: 11, day: 17, name: 'Leonids'),
    (month: 12, day: 13, name: 'Geminids'),
    (month: 12, day: 22, name: 'Ursids'),
  ];

  /// Returns the meteor shower whose annual peak is within ±3 days of [date],
  /// or null if none.
  static MeteorShower? meteorShowerNear(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    for (final s in _showers) {
      final peak = DateTime(date.year, s.month, s.day);
      if (d.difference(peak).abs().inDays <= 3) {
        return MeteorShower(name: s.name, symbol: '☄');
      }
    }
    return null;
  }

  /// Sunrise and sunset times for [date] at [lat]/[lon] via the `daylight` package.
  /// Returns null on polar days with no sunrise or sunset.
  static SunTimes? sunTimesFor(DateTime date, double lat, double lon) {
    final location = DaylightLocation(lat, lon);
    final calc = DaylightCalculator(location);
    final result = calc.calculateForDay(
      DateTime.utc(date.year, date.month, date.day),
      Zenith.official,
    );
    if (result.sunrise == null || result.sunset == null) return null;
    final lengthMinutes =
        result.sunset!.difference(result.sunrise!).inMinutes;
    return SunTimes(
      sunrise: result.sunrise!,
      sunset: result.sunset!,
      dayLengthMinutes: lengthMinutes,
    );
  }

  // NASA/Fred Espenak, eclipse.gsfc.nasa.gov — Five Millennium Canon of Solar
  // and Lunar Eclipses. Penumbral lunar eclipses omitted (barely visible).
  // Covers 2024–2035.
  static final _eclipses = <Eclipse>[
    // ── SOLAR ──────────────────────────────────────────────────
    // 2024
    Eclipse(DateTime.utc(2024, 4, 8, 18, 18),  EclipseType.solarTotal,    'Total Solar Eclipse',    '☀️'),
    Eclipse(DateTime.utc(2024, 10, 2, 18, 46), EclipseType.solarAnnular,  'Annular Solar Eclipse',  '🌑'),
    // 2025
    Eclipse(DateTime.utc(2025, 3, 29, 10, 48), EclipseType.solarPartial,  'Partial Solar Eclipse',  '🌑'),
    Eclipse(DateTime.utc(2025, 9, 21, 19, 43), EclipseType.solarPartial,  'Partial Solar Eclipse',  '🌑'),
    // 2026
    Eclipse(DateTime.utc(2026, 2, 17, 12, 13), EclipseType.solarAnnular,  'Annular Solar Eclipse',  '🌑'),
    Eclipse(DateTime.utc(2026, 8, 12, 17, 47), EclipseType.solarTotal,    'Total Solar Eclipse',    '☀️'),
    // 2027
    Eclipse(DateTime.utc(2027, 2, 6, 16, 0),   EclipseType.solarAnnular,  'Annular Solar Eclipse',  '🌑'),
    Eclipse(DateTime.utc(2027, 8, 2, 10, 7),   EclipseType.solarTotal,    'Total Solar Eclipse',    '☀️'),
    // 2028
    Eclipse(DateTime.utc(2028, 1, 26, 15, 55), EclipseType.solarAnnular,  'Annular Solar Eclipse',  '🌑'),
    Eclipse(DateTime.utc(2028, 7, 22, 2, 56),  EclipseType.solarTotal,    'Total Solar Eclipse',    '☀️'),
    // 2029
    Eclipse(DateTime.utc(2029, 1, 14, 17, 13), EclipseType.solarPartial,  'Partial Solar Eclipse',  '🌑'),
    Eclipse(DateTime.utc(2029, 6, 1, 4, 34),   EclipseType.solarAnnular,  'Annular Solar Eclipse',  '🌑'),
    Eclipse(DateTime.utc(2029, 11, 25, 15, 4), EclipseType.solarTotal,    'Total Solar Eclipse',    '☀️'),
    // 2030
    Eclipse(DateTime.utc(2030, 6, 1, 6, 29),   EclipseType.solarAnnular,  'Annular Solar Eclipse',  '🌑'),
    Eclipse(DateTime.utc(2030, 11, 25, 6, 51), EclipseType.solarTotal,    'Total Solar Eclipse',    '☀️'),
    // 2031
    Eclipse(DateTime.utc(2031, 5, 21, 7, 16),  EclipseType.solarAnnular,  'Annular Solar Eclipse',  '🌑'),
    Eclipse(DateTime.utc(2031, 11, 14, 21, 7), EclipseType.solarHybrid,   'Hybrid Solar Eclipse',   '☀️'),
    // 2032
    Eclipse(DateTime.utc(2032, 5, 9, 13, 42),  EclipseType.solarAnnular,  'Annular Solar Eclipse',  '🌑'),
    Eclipse(DateTime.utc(2032, 11, 3, 5, 18),  EclipseType.solarPartial,  'Partial Solar Eclipse',  '🌑'),
    // 2033
    Eclipse(DateTime.utc(2033, 3, 30, 18, 2),  EclipseType.solarTotal,    'Total Solar Eclipse',    '☀️'),
    Eclipse(DateTime.utc(2033, 9, 23, 12, 58), EclipseType.solarAnnular,  'Annular Solar Eclipse',  '🌑'),
    // 2034
    Eclipse(DateTime.utc(2034, 3, 20, 10, 18), EclipseType.solarTotal,    'Total Solar Eclipse',    '☀️'),
    Eclipse(DateTime.utc(2034, 9, 12, 16, 17), EclipseType.solarAnnular,  'Annular Solar Eclipse',  '🌑'),
    // 2035
    Eclipse(DateTime.utc(2035, 3, 9, 18, 20),  EclipseType.solarAnnular,  'Annular Solar Eclipse',  '🌑'),
    Eclipse(DateTime.utc(2035, 9, 2, 1, 56),   EclipseType.solarTotal,    'Total Solar Eclipse',    '☀️'),

    // ── LUNAR ──────────────────────────────────────────────────
    // 2024
    Eclipse(DateTime.utc(2024, 9, 18, 2, 44),  EclipseType.lunarPartial,  'Partial Lunar Eclipse',  '🌕'),
    // 2025
    Eclipse(DateTime.utc(2025, 3, 14, 6, 59),  EclipseType.lunarTotal,    'Total Lunar Eclipse',    '🌕'),
    Eclipse(DateTime.utc(2025, 9, 7, 18, 12),  EclipseType.lunarTotal,    'Total Lunar Eclipse',    '🌕'),
    // 2026
    Eclipse(DateTime.utc(2026, 3, 3, 11, 34),  EclipseType.lunarTotal,    'Total Lunar Eclipse',    '🌕'),
    Eclipse(DateTime.utc(2026, 8, 28, 4, 14),  EclipseType.lunarPartial,  'Partial Lunar Eclipse',  '🌕'),
    // 2028
    Eclipse(DateTime.utc(2028, 7, 6, 18, 20),  EclipseType.lunarPartial,  'Partial Lunar Eclipse',  '🌕'),
    Eclipse(DateTime.utc(2028, 12, 31, 16, 52),EclipseType.lunarTotal,    'Total Lunar Eclipse',    '🌕'),
    // 2029
    Eclipse(DateTime.utc(2029, 6, 26, 3, 23),  EclipseType.lunarTotal,    'Total Lunar Eclipse',    '🌕'),
    Eclipse(DateTime.utc(2029, 12, 20, 22, 43),EclipseType.lunarTotal,    'Total Lunar Eclipse',    '🌕'),
    // 2030
    Eclipse(DateTime.utc(2030, 6, 15, 18, 35), EclipseType.lunarPartial,  'Partial Lunar Eclipse',  '🌕'),
    // 2032
    Eclipse(DateTime.utc(2032, 4, 25, 15, 14), EclipseType.lunarTotal,    'Total Lunar Eclipse',    '🌕'),
    Eclipse(DateTime.utc(2032, 10, 18, 19, 4), EclipseType.lunarTotal,    'Total Lunar Eclipse',    '🌕'),
    // 2033
    Eclipse(DateTime.utc(2033, 4, 14, 19, 13), EclipseType.lunarTotal,    'Total Lunar Eclipse',    '🌕'),
    Eclipse(DateTime.utc(2033, 10, 8, 10, 56), EclipseType.lunarTotal,    'Total Lunar Eclipse',    '🌕'),
    // 2034
    Eclipse(DateTime.utc(2034, 4, 3, 19, 48),  EclipseType.lunarPartial,  'Partial Lunar Eclipse',  '🌕'),
    Eclipse(DateTime.utc(2034, 9, 28, 2, 45),  EclipseType.lunarPartial,  'Partial Lunar Eclipse',  '🌕'),
    // 2035
    Eclipse(DateTime.utc(2035, 8, 19, 1, 12),  EclipseType.lunarTotal,    'Total Lunar Eclipse',    '🌕'),
  ];

  /// Returns the nearest eclipse within 30 days of [date], or null if none.
  /// When multiple eclipses fall within the window, the closest one is returned.
  static Eclipse? eclipseNear(DateTime date) {
    final utcDay = DateTime.utc(date.year, date.month, date.day);
    Eclipse? best;
    int bestDays = 31;
    for (final e in _eclipses) {
      final eclipseDay = DateTime.utc(e.date.year, e.date.month, e.date.day);
      final diff = eclipseDay.difference(utcDay).inDays.abs();
      if (diff <= 30 && diff < bestDays) {
        best = e;
        bestDays = diff;
      }
    }
    return best;
  }
}
