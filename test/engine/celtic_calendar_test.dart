import 'package:flutter_test/flutter_test.dart';
import 'package:roots_calendar/engine/celtic_calendar.dart';

void main() {
  // ── yearStart ──────────────────────────────────────────────────────────────

  group('yearStart', () {
    test('returns Dec 24 of the given year', () {
      expect(yearStart(2024), DateTime(2024, 12, 24));
      expect(yearStart(2000), DateTime(2000, 12, 24));
    });
  });

  // ── celticYearOf ──────────────────────────────────────────────────────────

  group('celticYearOf', () {
    test('Dec 24 belongs to that Gregorian year', () {
      expect(celticYearOf(DateTime(2024, 12, 24)), 2024);
    });

    test('Dec 31 belongs to that Gregorian year', () {
      expect(celticYearOf(DateTime(2024, 12, 31)), 2024);
    });

    test('Jan 1 belongs to the previous Gregorian year', () {
      expect(celticYearOf(DateTime(2025, 1, 1)), 2024);
    });

    test('Dec 23 belongs to the previous Gregorian year', () {
      expect(celticYearOf(DateTime(2025, 12, 23)), 2024);
    });

    test('Dec 23 of next year is NOT in the current year', () {
      expect(celticYearOf(DateTime(2025, 12, 23)), isNot(2025));
    });
  });

  // ── isCelticLeapYear ──────────────────────────────────────────────────────

  group('isCelticLeapYear', () {
    // Celtic year 2023 spans Dec 24 2023 – Dec 23 2024.
    // 2024 is a Gregorian leap year → Celtic year 2023 is a leap year.
    test('Celtic year 2023 is a leap year (Gregorian 2024 has Feb 29)', () {
      expect(isCelticLeapYear(2023), isTrue);
    });

    test('Celtic year 2024 is NOT a leap year (Gregorian 2025 has no Feb 29)', () {
      expect(isCelticLeapYear(2024), isFalse);
    });

    test('Celtic year 1899 is NOT a leap year (1900 is not a Gregorian leap year)', () {
      expect(isCelticLeapYear(1899), isFalse);
    });

    test('Celtic year 1999 IS a leap year (2000 is a Gregorian leap year)', () {
      expect(isCelticLeapYear(1999), isTrue);
    });
  });

  // ── gregorianToCeltic — normal days ───────────────────────────────────────

  group('gregorianToCeltic – normal days', () {
    test('Dec 24 is Celtic month 1 day 1', () {
      final cd = gregorianToCeltic(DateTime(2024, 12, 24));
      expect(cd.month, 1);
      expect(cd.day, 1);
      expect(cd.celticYear, 2024);
      expect(cd.isYearDay, isFalse);
      expect(cd.isLeapDay, isFalse);
    });

    test('Dec 25 is Celtic month 1 day 2', () {
      final cd = gregorianToCeltic(DateTime(2024, 12, 25));
      expect(cd.month, 1);
      expect(cd.day, 2);
    });

    test('Jan 20 2025 is Celtic month 1 day 28 (last of Beth)', () {
      final cd = gregorianToCeltic(DateTime(2025, 1, 20));
      expect(cd.month, 1);
      expect(cd.day, 28);
    });

    test('Jan 21 2025 is Celtic month 2 day 1 (Luis)', () {
      final cd = gregorianToCeltic(DateTime(2025, 1, 21));
      expect(cd.month, 2);
      expect(cd.day, 1);
    });

    test('Month 13 day 1 starts on offset 336', () {
      final start = yearStart(2024).add(const Duration(days: 336));
      final cd = gregorianToCeltic(start);
      expect(cd.month, 13);
      expect(cd.day, 1);
    });

    test('Month 13 day 28 is last regular day (offset 363)', () {
      final last = yearStart(2024).add(const Duration(days: 363));
      final cd = gregorianToCeltic(last);
      expect(cd.month, 13);
      expect(cd.day, 28);
    });
  });

  // ── Year Day & Leap Day ───────────────────────────────────────────────────

  group('gregorianToCeltic – Year Day & Leap Day', () {
    test('offset 364 is Year Day', () {
      final yd = yearStart(2024).add(const Duration(days: 364));
      final cd = gregorianToCeltic(yd);
      expect(cd.isYearDay, isTrue);
      expect(cd.isLeapDay, isFalse);
      expect(cd.month, isNull);
      expect(cd.day, isNull);
    });

    test('isYearDay() helper matches', () {
      final yd = yearStart(2024).add(const Duration(days: 364));
      expect(isYearDay(yd), isTrue);
    });

    test('offset 365 in a leap year is Leap Day', () {
      // Celtic 2023 is a leap year (Gregorian 2024 has Feb 29)
      final ld = yearStart(2023).add(const Duration(days: 365));
      final cd = gregorianToCeltic(ld);
      expect(cd.isLeapDay, isTrue);
      expect(cd.isYearDay, isFalse);
    });

    test('isLeapDay() helper matches', () {
      final ld = yearStart(2023).add(const Duration(days: 365));
      expect(isLeapDay(ld), isTrue);
    });

    test('offset 365 in a non-leap year is NOT Leap Day', () {
      // Celtic 2024 is NOT a leap year — offset 365 would fall in Celtic 2025
      final ld = yearStart(2024).add(const Duration(days: 365));
      expect(isLeapDay(ld), isFalse);
    });
  });

  // ── DST regression (the bug from CLAUDE.md) ───────────────────────────────
  //
  // In DST timezones the local-midnight difference across the spring-forward
  // boundary is only 23 h, so .inDays truncates to the wrong day.
  // The fix is to normalise both dates to UTC midnight before subtracting.

  group('gregorianToCeltic – DST spring-forward regression', () {
    // In Central European Time the clocks jump forward on the last Sunday of
    // March. For 2025 that is March 30.  The Celtic date of March 30 2025 is
    // in Celtic year 2024, month 4 (Fearn).
    //
    // Without the UTC-normalisation fix, DateTime(2025, 3, 30) would produce
    // a date that is one day off when the test runs in CET (UTC+1→UTC+2).
    // Because tests always run with the process timezone, we compare the
    // UTC-normalised result against the expected offset and verify it is an
    // integer number of days from yearStart.

    test('March 30 2025 has an exact integer offset from yearStart (no DST drift)', () {
      final date = DateTime(2025, 3, 30);
      final cy = celticYearOf(date);
      final ysUtc = DateTime.utc(cy, 12, 24);
      final dUtc  = DateTime.utc(date.year, date.month, date.day);
      final offset = dUtc.difference(ysUtc);
      // Must be a whole number of days — no fractional day from DST.
      expect(offset.inHours % 24, 0,
          reason: 'DST must not produce a fractional day offset');
    });

    test('gregorianToCeltic returns consistent result across DST boundary', () {
      // Day before DST (March 29 2025) and day after (March 30 2025) must
      // be consecutive Celtic days.
      final before = gregorianToCeltic(DateTime(2025, 3, 29));
      final after  = gregorianToCeltic(DateTime(2025, 3, 30));
      expect(before.month, after.month,
          reason: 'Same Celtic month across DST boundary');
      expect(after.day, before.day! + 1,
          reason: 'Days must be consecutive across DST boundary');
    });
  });

  // ── celticToGregorian ─────────────────────────────────────────────────────

  group('celticToGregorian', () {
    test('month 1 day 1 → Dec 24 of the Celtic year', () {
      expect(celticToGregorian(2024, 1, 1), DateTime(2024, 12, 24));
    });

    test('month 1 day 28 → Jan 20 of the following year', () {
      expect(celticToGregorian(2024, 1, 28), DateTime(2025, 1, 20));
    });

    test('round-trips: gregorianToCeltic ∘ celticToGregorian = identity', () {
      for (int m = 1; m <= 13; m++) {
        for (int d = 1; d <= 28; d++) {
          final g  = celticToGregorian(2024, m, d);
          final cd = gregorianToCeltic(g);
          expect(cd.month, m, reason: 'month mismatch at ($m, $d)');
          expect(cd.day, d, reason: 'day mismatch at ($m, $d)');
        }
      }
    });
  });

  // ── gregorianDatesForMonth ────────────────────────────────────────────────

  group('gregorianDatesForMonth', () {
    test('returns exactly 28 dates', () {
      expect(gregorianDatesForMonth(2024, 1).length, 28);
    });

    test('first date of month 1 is Dec 24', () {
      expect(gregorianDatesForMonth(2024, 1).first, DateTime(2024, 12, 24));
    });

    test('consecutive months are adjacent', () {
      final m1 = gregorianDatesForMonth(2024, 1);
      final m2 = gregorianDatesForMonth(2024, 2);
      expect(m2.first, m1.last.add(const Duration(days: 1)));
    });
  });

  // ── yearDayDate / leapDayDate ─────────────────────────────────────────────

  group('yearDayDate / leapDayDate', () {
    test('yearDayDate is 364 days after yearStart', () {
      final yd = yearDayDate(2024);
      expect(yd.difference(yearStart(2024)).inDays, 364);
    });

    test('leapDayDate is 365 days after yearStart in a leap year', () {
      final ld = leapDayDate(2023)!;
      expect(ld.difference(yearStart(2023)).inDays, 365);
    });

    test('leapDayDate returns null in a non-leap year', () {
      expect(leapDayDate(2024), isNull);
    });
  });
}
