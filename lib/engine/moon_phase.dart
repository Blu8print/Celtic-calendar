import 'dart:math';

/// A snapshot of the moon's phase on a given day.
class MoonPhase {
  final String name;
  final String symbol;
  final double illumination; // 0.0–1.0
  final bool isFullMoon;
  final bool isNewMoon;

  const MoonPhase({
    required this.name,
    required this.symbol,
    required this.illumination,
    required this.isFullMoon,
    required this.isNewMoon,
  });
}

/// Pure Dart moon phase calculator using the synodic period.
///
/// Reference: J2000 known new moon = Julian Date 2451549.729 (Jan 6, 2000 18:14 UTC).
/// Accuracy: ±1 day, sufficient for calendar display purposes.
///
/// Always pass UTC-normalised dates (DateTime.utc) to avoid DST drift,
/// consistent with the Celtic calendar engine.
class MoonPhaseCalculator {
  static const double _knownNewMoon = 2451549.729;
  static const double _synodicPeriod = 29.53059;

  /// Converts a calendar date to a Julian Day Number.
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

  /// Returns the moon phase for [date].
  ///
  /// Pass UTC midnight: `MoonPhaseCalculator.calculate(DateTime.utc(y, m, d))`
  static MoonPhase calculate(DateTime date) {
    final utc = DateTime.utc(date.year, date.month, date.day);
    final jd = _toJulian(utc);
    var age = (jd - _knownNewMoon) % _synodicPeriod;
    if (age < 0) age += _synodicPeriod;

    final illumination = (1 - cos(2 * pi * age / _synodicPeriod)) / 2;
    final isNewMoon  = age < 1.5 || age > 28.0;
    final isFullMoon = age > 13.5 && age < 16.5;

    final String name;
    final String symbol;

    if (age < 1.5) {
      name = 'New Moon';        symbol = '🌑';
    } else if (age < 7.4) {
      name = 'Waxing Crescent'; symbol = '🌒';
    } else if (age < 8.4) {
      name = 'First Quarter';   symbol = '🌓';
    } else if (age < 13.5) {
      name = 'Waxing Gibbous';  symbol = '🌔';
    } else if (age < 16.5) {
      name = 'Full Moon';       symbol = '🌕';
    } else if (age < 22.1) {
      name = 'Waning Gibbous';  symbol = '🌖';
    } else if (age < 23.1) {
      name = 'Last Quarter';    symbol = '🌗';
    } else if (age < 28.0) {
      name = 'Waning Crescent'; symbol = '🌘';
    } else {
      name = 'New Moon';        symbol = '🌑';
    }

    return MoonPhase(
      name: name,
      symbol: symbol,
      illumination: illumination,
      isFullMoon: isFullMoon,
      isNewMoon: isNewMoon,
    );
  }

  /// Returns the first full-moon date on or after [from].
  static DateTime nextFullMoon(DateTime from) {
    var date = DateTime.utc(from.year, from.month, from.day);
    for (int i = 0; i < 32; i++) {
      if (calculate(date).isFullMoon) return date;
      date = date.add(const Duration(days: 1));
    }
    return date;
  }
}
