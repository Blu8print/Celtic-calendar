/// The 8 festivals of the Celtic Wheel of the Year.
///
/// These are contextual, read-only — they are never stored in the local DB.
/// All dates are computed fresh via [CelticFestivalEngine.festivalsForYear].

enum FestivalType { fire, solar }

class CelticFestival {
  final String name;
  final String description;
  final String flavour; // One or two poetic lines for the info card
  final String symbol;
  final FestivalType type;
  final DateTime gregorianDate; // UTC midnight for the specific Celtic year

  const CelticFestival({
    required this.name,
    required this.description,
    required this.flavour,
    required this.symbol,
    required this.type,
    required this.gregorianDate,
  });
}

class CelticFestivalEngine {
  /// Returns all 8 festivals for the given Celtic year.
  ///
  /// [celticYear] is the year that Beth (month 1) starts on Dec 24.
  /// Fire festivals fall in the Gregorian year that follows (celticYear + 1).
  /// Yule (Winter Solstice) falls in December of celticYear itself.
  static List<CelticFestival> festivalsForYear(int celticYear) {
    final gYear = celticYear + 1; // Gregorian year covering Jan–Nov of this Celtic year

    return [
      // ── Fire festivals — fixed Gregorian dates ────────────────────────────────
      CelticFestival(
        name: 'Imbolc',
        description: 'First stirring of spring · Brigid',
        flavour: 'The earth wakes. The first lamb is born.\nLight a candle for Brigid.',
        symbol: '🕯️',
        type: FestivalType.fire,
        gregorianDate: DateTime.utc(gYear, 2, 1),
      ),
      CelticFestival(
        name: 'Beltane',
        description: 'Fire festival · Summer begins',
        flavour: 'The bonfires are lit. The land is alive.\nDance between the flames.',
        symbol: '🔥',
        type: FestivalType.fire,
        gregorianDate: DateTime.utc(gYear, 5, 1),
      ),
      CelticFestival(
        name: 'Lughnasadh',
        description: 'First harvest · Feast of Lugh',
        flavour: 'The grain bends heavy. Lugh shines bright.\nBe grateful for what the earth gives.',
        symbol: '🌾',
        type: FestivalType.fire,
        gregorianDate: DateTime.utc(gYear, 8, 1),
      ),
      CelticFestival(
        name: 'Samhain',
        description: 'The veil is thin · Celtic New Year\'s Eve',
        flavour: 'The dead walk close tonight.\nHonour them. The year turns.',
        symbol: '🍂',
        type: FestivalType.fire,
        gregorianDate: DateTime.utc(gYear, 10, 31),
      ),

      // ── Solar festivals — lookup table ────────────────────────────────────────
      // Yule uses celticYear (Dec), all others use gYear.
      // Source: NASA, EarthSky, TimeAndDate (UTC day precision is sufficient).
      CelticFestival(
        name: 'Yule',
        description: 'Winter Solstice · The longest night',
        flavour: 'Darkness is deepest. Light is reborn.\nFeed the fire. The sun returns.',
        symbol: '❄️',
        type: FestivalType.solar,
        gregorianDate: _winterSolstice(celticYear),
      ),
      CelticFestival(
        name: 'Ostara',
        description: 'Spring Equinox · Balance returns',
        flavour: 'Day and night stand equal.\nSow your seeds. New life begins.',
        symbol: '🌱',
        type: FestivalType.solar,
        gregorianDate: _springEquinox(gYear),
      ),
      CelticFestival(
        name: 'Litha',
        description: 'Summer Solstice · The longest day',
        flavour: 'The sun is at its height. The wheel turns.\nGather the herbs at dawn.',
        symbol: '☀️',
        type: FestivalType.solar,
        gregorianDate: _summerSolstice(gYear),
      ),
      CelticFestival(
        name: 'Mabon',
        description: 'Autumn Equinox · Second harvest',
        flavour: 'Light fades into dark.\nGive thanks. Prepare for the quiet.',
        symbol: '🍎',
        type: FestivalType.solar,
        gregorianDate: _autumnEquinox(gYear),
      ),
    ];
  }

  // ── Solstice / Equinox lookup tables ─────────────────────────────────────────
  // Day precision only — time of day is not needed for calendar display.
  // Extend this table as the app is maintained; past years never change.

  static DateTime _springEquinox(int year) {
    // Source: USNO / timeanddate.com — UTC day precision is sufficient.
    const dates = <int, (int, int)>{
      2024: (3, 20), 2025: (3, 20), 2026: (3, 20), 2027: (3, 20),
      2028: (3, 20), 2029: (3, 20), 2030: (3, 20), 2031: (3, 20),
      2032: (3, 20), 2033: (3, 20), 2034: (3, 20), 2035: (3, 20),
      2036: (3, 20), 2037: (3, 20), 2038: (3, 20), 2039: (3, 20),
      2040: (3, 20), 2041: (3, 20), 2042: (3, 20), 2043: (3, 20),
      2044: (3, 19), 2045: (3, 20), 2046: (3, 20), 2047: (3, 20),
      2048: (3, 19), 2049: (3, 20), 2050: (3, 20),
    };
    final d = dates[year] ?? (3, 20);
    return DateTime.utc(year, d.$1, d.$2);
  }

  static DateTime _summerSolstice(int year) {
    const dates = <int, (int, int)>{
      2024: (6, 20), 2025: (6, 21), 2026: (6, 21), 2027: (6, 21),
      2028: (6, 20), 2029: (6, 21), 2030: (6, 21), 2031: (6, 21),
      2032: (6, 20), 2033: (6, 21), 2034: (6, 21), 2035: (6, 21),
      2036: (6, 20), 2037: (6, 21), 2038: (6, 21), 2039: (6, 21),
      2040: (6, 20), 2041: (6, 21), 2042: (6, 21), 2043: (6, 21),
      2044: (6, 20), 2045: (6, 21), 2046: (6, 21), 2047: (6, 21),
      2048: (6, 20), 2049: (6, 21), 2050: (6, 21),
    };
    final d = dates[year] ?? (6, 21);
    return DateTime.utc(year, d.$1, d.$2);
  }

  static DateTime _autumnEquinox(int year) {
    const dates = <int, (int, int)>{
      2024: (9, 22), 2025: (9, 22), 2026: (9, 23), 2027: (9, 23),
      2028: (9, 22), 2029: (9, 22), 2030: (9, 23), 2031: (9, 23),
      2032: (9, 22), 2033: (9, 22), 2034: (9, 22), 2035: (9, 23),
      2036: (9, 22), 2037: (9, 22), 2038: (9, 23), 2039: (9, 23),
      2040: (9, 22), 2041: (9, 22), 2042: (9, 23), 2043: (9, 23),
      2044: (9, 22), 2045: (9, 22), 2046: (9, 23), 2047: (9, 23),
      2048: (9, 22), 2049: (9, 22), 2050: (9, 23),
    };
    final d = dates[year] ?? (9, 22);
    return DateTime.utc(year, d.$1, d.$2);
  }

  static DateTime _winterSolstice(int year) {
    // Yule: Dec solstice of [year] (the celticYear itself, not gYear).
    const dates = <int, (int, int)>{
      2024: (12, 21), 2025: (12, 21), 2026: (12, 21), 2027: (12, 22),
      2028: (12, 21), 2029: (12, 21), 2030: (12, 21), 2031: (12, 22),
      2032: (12, 21), 2033: (12, 21), 2034: (12, 21), 2035: (12, 21),
      2036: (12, 21), 2037: (12, 21), 2038: (12, 21), 2039: (12, 22),
      2040: (12, 21), 2041: (12, 21), 2042: (12, 21), 2043: (12, 22),
      2044: (12, 21), 2045: (12, 21), 2046: (12, 21), 2047: (12, 22),
      2048: (12, 21), 2049: (12, 21), 2050: (12, 21),
    };
    final d = dates[year] ?? (12, 21);
    return DateTime.utc(year, d.$1, d.$2);
  }
}
