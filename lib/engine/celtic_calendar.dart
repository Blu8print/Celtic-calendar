/// Celtic Tree Calendar engine — Beth-Luis-Nion system.
/// Pure Dart, no Flutter dependencies.
///
/// Rules:
///   • Celtic year Y starts on Dec 24 of Gregorian year Y.
///   • 13 months × 28 days = 364 days.
///   • Day 365 (offset 364 from year start) = Year Day (nameless).
///   • If Celtic year Y is a "leap year" (Gregorian year Y+1 has Feb 29),
///     Day 366 (offset 365) = Leap Day.
///
/// TODO: When IFC / other calendar systems are added, extract a shared
///       CalendarSystem interface that this engine implements.

library celtic_calendar;

// ─── Month metadata ───────────────────────────────────────────────────────────

class CelticMonth {
  final int number;
  final String name;
  final String tree;
  final String ogham;
  final String keyword;

  const CelticMonth({
    required this.number,
    required this.name,
    required this.tree,
    required this.ogham,
    required this.keyword,
  });
}

const List<CelticMonth> celticMonths = [
  CelticMonth(number: 1,  name: 'Beth',   tree: 'Birch',    ogham: 'ᚁ', keyword: 'New Beginnings'),
  CelticMonth(number: 2,  name: 'Luis',   tree: 'Rowan',    ogham: 'ᚂ', keyword: 'Protection'),
  CelticMonth(number: 3,  name: 'Nion',   tree: 'Ash',      ogham: 'ᚅ', keyword: 'Connection'),
  CelticMonth(number: 4,  name: 'Fearn',  tree: 'Alder',    ogham: 'ᚃ', keyword: 'Guidance'),
  CelticMonth(number: 5,  name: 'Saille', tree: 'Willow',   ogham: 'ᚄ', keyword: 'Intuition'),
  CelticMonth(number: 6,  name: 'Huath',  tree: 'Hawthorn', ogham: 'ᚆ', keyword: 'Cleansing'),
  CelticMonth(number: 7,  name: 'Duir',   tree: 'Oak',      ogham: 'ᚇ', keyword: 'Strength'),
  CelticMonth(number: 8,  name: 'Tinne',  tree: 'Holly',    ogham: 'ᚈ', keyword: 'Balance'),
  CelticMonth(number: 9,  name: 'Coll',   tree: 'Hazel',    ogham: 'ᚉ', keyword: 'Wisdom'),
  CelticMonth(number: 10, name: 'Muin',   tree: 'Vine',     ogham: 'ᚋ', keyword: 'Harvest'),
  CelticMonth(number: 11, name: 'Gort',   tree: 'Ivy',      ogham: 'ᚌ', keyword: 'Perseverance'),
  CelticMonth(number: 12, name: 'Ngetal', tree: 'Reed',     ogham: 'ᚍ', keyword: 'Healing'),
  CelticMonth(number: 13, name: 'Ruis',   tree: 'Elder',    ogham: 'ᚏ', keyword: 'Transition'),
];

// ─── CelticDate ───────────────────────────────────────────────────────────────

class CelticDate {
  /// The Celtic year (same as the Gregorian year of Dec 24 that starts it).
  final int celticYear;

  /// Month 1-13, or null for Year Day / Leap Day.
  final int? month;

  /// Day 1-28, or null for Year Day / Leap Day.
  final int? day;

  final bool isYearDay;
  final bool isLeapDay;

  const CelticDate({
    required this.celticYear,
    this.month,
    this.day,
    this.isYearDay = false,
    this.isLeapDay = false,
  }) : assert(
         (month != null && day != null && !isYearDay && !isLeapDay) ||
         (month == null && day == null && (isYearDay || isLeapDay)),
       );

  /// Convenience: returns the month metadata, or null for special days.
  CelticMonth? get monthData =>
      month != null ? celticMonths[month! - 1] : null;

  @override
  String toString() {
    if (isLeapDay) return 'Celtic Year $celticYear — Leap Day';
    if (isYearDay) return 'Celtic Year $celticYear — Year Day';
    return 'Celtic $celticYear / Month $month (${monthData?.name}) Day $day';
  }
}

// ─── Calendar engine functions ────────────────────────────────────────────────

/// Returns Dec 24 of the given Celtic year (the first day of that year).
DateTime yearStart(int celticYear) => DateTime(celticYear, 12, 24);

/// Returns the Celtic year that contains [date].
/// Dec 24 and later in a given Gregorian year belong to that Gregorian year's
/// Celtic year; all other dates belong to the previous Gregorian year's Celtic year.
int celticYearOf(DateTime date) {
  if (date.month == 12 && date.day >= 24) return date.year;
  return date.year - 1;
}

/// Returns true if Celtic year [y] has a Leap Day.
/// This happens when Gregorian year (y + 1) is a leap year, because
/// Feb 29 of y+1 falls inside the Celtic year that started Dec 24 of y.
bool isCelticLeapYear(int celticYear) {
  final y = celticYear + 1;
  return (y % 4 == 0 && y % 100 != 0) || (y % 400 == 0);
}

/// Returns true if [date] is the Year Day of its Celtic year.
bool isYearDay(DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  final ys = yearStart(celticYearOf(d));
  return d.difference(ys).inDays == 364;
}

/// Returns true if [date] is the Leap Day of its Celtic year.
bool isLeapDay(DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  final cy = celticYearOf(d);
  if (!isCelticLeapYear(cy)) return false;
  return d.difference(yearStart(cy)).inDays == 365;
}

/// Converts a Gregorian [date] to a [CelticDate].
CelticDate gregorianToCeltic(DateTime date) {
  // Normalize both dates to UTC midnight to avoid DST-induced off-by-one errors.
  // In DST timezones, local midnight in summer vs winter gives a fractional
  // day difference; .inDays truncates, shifting the Celtic date by 1 day.
  final dUtc  = DateTime.utc(date.year, date.month, date.day);
  final cy    = celticYearOf(date);
  final ysUtc = DateTime.utc(cy, 12, 24);
  final offset = dUtc.difference(ysUtc).inDays;

  if (offset == 365 && isCelticLeapYear(cy)) {
    return CelticDate(celticYear: cy, isLeapDay: true);
  }
  if (offset == 364) {
    return CelticDate(celticYear: cy, isYearDay: true);
  }
  final month = offset ~/ 28 + 1;
  final day = offset % 28 + 1;
  return CelticDate(celticYear: cy, month: month, day: day);
}

/// Converts Celtic date components back to a Gregorian [DateTime].
/// [month] must be 1-13, [day] must be 1-28.
DateTime celticToGregorian(int celticYear, int month, int day) {
  assert(month >= 1 && month <= 13);
  assert(day >= 1 && day <= 28);
  return yearStart(celticYear).add(Duration(days: (month - 1) * 28 + (day - 1)));
}

/// Returns the Gregorian date of the Year Day for the given Celtic year.
DateTime yearDayDate(int celticYear) =>
    yearStart(celticYear).add(const Duration(days: 364));

/// Returns the Gregorian date of the Leap Day for the given Celtic year,
/// or null if that year is not a leap year.
DateTime? leapDayDate(int celticYear) {
  if (!isCelticLeapYear(celticYear)) return null;
  return yearStart(celticYear).add(const Duration(days: 365));
}

/// Returns the 28 Gregorian dates that make up the given Celtic month.
List<DateTime> gregorianDatesForMonth(int celticYear, int month) {
  assert(month >= 1 && month <= 13);
  final start = yearStart(celticYear).add(Duration(days: (month - 1) * 28));
  return List.generate(28, (i) => start.add(Duration(days: i)));
}

/// Returns the weekday index (0=Sun…6=Sat) that day 1 of every month in a
/// given Celtic year falls on. Because months are exactly 28 days (= 4 weeks),
/// all 13 months start on the same weekday.
int monthStartWeekday(int celticYear) => yearStart(celticYear).weekday % 7;
// DateTime.weekday is 1=Mon…7=Sun; convert to 0=Sun…6=Sat.
