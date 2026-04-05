# The Time Paradox: A Day in the Life of a Broken Clock

*How building a Celtic Tree Calendar broke our faith in Gregorian time — and why it was already broken to begin with.*

---

## The Bug That Started It All

Today we found a bug. A simple one, on the surface: tap an upcoming event in the calendar, get taken to the wrong day. Yesterday's day. Or sometimes — somehow — both days at once.

The fix, once found, was three lines of Dart code.

But chasing it led somewhere unexpected: down into the foundations of how modern computers represent time, and why those foundations are a patchwork of historical accidents that make less sense the harder you look at them.

Pull up a chair. This one goes deep.

---

## Act I: The Ghost in the Calendar

The app is a Celtic Tree Calendar — 13 months of 28 days each, starting December 24, named after trees. Beth (Birch). Luis (Rowan). Fearn (Alder). A calendar designed by people who watched the sun and the trees, not a Pope and a committee.

We built it in Flutter. Events stored locally in SQLite via Drift. Sync to Google Calendar. Clean, modern, well-structured.

And yet: April 5th kept appearing as April 4th.

Tap day 19 of Fearn. Get taken to day 18. Create an all-day event. It shows up on the day before — or mysteriously on two days at once, like a quantum particle that hadn't decided where it lived yet.

The bug was a ghost. It only appeared in the Netherlands. Only in summer. Only for all-day events. Only after March.

That is the fingerprint of one thing: **Daylight Saving Time.**

---

## Act II: What Is a Day, Actually?

Here is a question that sounds philosophical but is entirely practical: *when does today begin?*

Your gut says: midnight. The moment the clock ticks from 23:59:59 to 00:00:00.

But which midnight? *Your* midnight — wherever you are, adjusted for your timezone and whatever political decision was made about whether to shift the clocks this week? Or *UTC midnight* — the one arbitrary meridian the world agreed to use as a shared reference point in 1884?

A computer has to pick one. And here is where it gets strange.

**SQLite stores dates as integers.** Not "April 5th." Not "00:00:00 CEST." Just a number: milliseconds since January 1, 1970, 00:00:00 UTC. The Unix epoch. An anchor point chosen because it was convenient for 1970s Unix engineers, not because it is meaningful to anyone who has ever watched a sunrise.

When the Drift ORM in Flutter reads that integer back out of the database, it calls `DateTime.fromMillisecondsSinceEpoch(ms)` — which returns a **local** DateTime. Your phone's local time. CEST. UTC+2 in summer. UTC+1 in winter.

Here is the paradox: **the same millisecond integer represents a different wall-clock time depending on what time of year you read it.**

An event created on April 5th at local midnight — that is, `00:00:00 CEST`, which is `22:00:00 UTC on April 4th` — has a millisecond value that, when interpreted in UTC, points to yesterday.

Write on April 5th. Read on April 4th. The event time-traveled.

---

## Act III: The DST Bug — A Technical Autopsy

The first bug we found — the one from a previous session — was in the calendar engine itself.

```dart
// The broken version:
CelticDate gregorianToCeltic(DateTime date) {
  final d  = DateTime(date.year, date.month, date.day);  // local midnight
  final cy = celticYearOf(d);
  final ys = yearStart(cy);                              // also local midnight
  final offset = d.difference(ys).inDays;               // truncates
  ...
}
```

On December 24th (year start), the clock is UTC+1. It's winter.
On April 5th, the clock is UTC+2. It's summer. The clocks "sprang forward."

So when you subtract local midnight April 5th from local midnight December 24th:

```
April 5 local midnight    = 2026-04-04T22:00:00Z  (CEST = UTC+2)
December 24 local midnight = 2025-12-23T23:00:00Z  (CET  = UTC+1)

Difference = 101 days + 23 hours
.inDays truncates to: 101
```

One hundred and one days. The correct answer is 102. The calendar was one day behind reality from late March through October, every year, in every country that observes DST.

**The fix:** stop using local time for arithmetic. Normalize both dates to UTC midnight — a timezone where every day is exactly 86,400 seconds, no exceptions, no politics.

```dart
// The fixed version:
CelticDate gregorianToCeltic(DateTime date) {
  final dUtc  = DateTime.utc(date.year, date.month, date.day);
  final cy    = celticYearOf(date);
  final ysUtc = DateTime.utc(cy, 12, 24);
  final offset = dUtc.difference(ysUtc).inDays;  // exact integer, every time
  ...
}
```

`DateTime.utc(2026, 4, 5)` minus `DateTime.utc(2025, 12, 24)` equals exactly 102 days. No truncation. No DST artifacts. Just math.

---

## Act IV: The Deeper Bug — When Your Database Lies

The second bug, the one we hunted today, was subtler.

Events were stored correctly now — `_save()` was normalized to `DateTime.utc(year, month, day)`. But the database queries were using the wrong boundary:

```dart
// Broken: UTC boundary in a local-time world
Future<List<Event>> getEventsForDay(DateTime date) {
  final start = DateTime.utc(date.year, date.month, date.day);  // 22:00 yesterday in CEST
  final end   = start.add(const Duration(days: 1));
  ...
}
```

In CEST (UTC+2), `DateTime.utc(2026, 4, 5)` has a millisecond value that corresponds to `April 5 at 02:00 AM local time`. An event stored at local midnight — `April 5 at 00:00 CEST` — has a smaller millisecond value. It falls *before* the UTC boundary.

The query looked for events *on* April 5th. The event was stored *on* April 5th. But the database returned it on April 4th, because the boundary was drawn in the wrong timezone.

**The fix:** query with local midnight boundaries, because that's how old events were stored. And for new events, store UTC midnight — which, while technically 22:00 UTC the night before, is unambiguously "this date with no time component" and survives any timezone query that uses a 24-hour window around local midnight.

```dart
// Fixed: local boundary — works for all events, old and new
Future<List<Event>> getEventsForDay(DateTime date) {
  final start = DateTime(date.year, date.month, date.day);  // local midnight
  final end   = start.add(const Duration(days: 1));
  ...
}
```

Same date. Different epoch value. Completely different query result.

---

## Interlude: The Gregorian Calendar Is Political Fiction

Let's step back.

The Gregorian calendar was introduced in 1582 by Pope Gregory XIII to fix a drift problem in the Julian calendar — the solar year is not exactly 365.25 days, so Easter was wandering away from spring. The solution: skip 10 days in October 1582, and adjust the leap year rules.

Catholic countries adopted it immediately. Protestant countries resisted for over a century. Britain and its colonies didn't switch until 1752 — at which point they had to skip 11 days, because the drift had gotten worse. People rioted in the streets, demanding their days back.

The Soviet Union switched in 1918. Greece in 1923. Saudi Arabia in 2016.

We act as if "the date" is a physical fact of the universe, like the speed of light. It is not. It is a consensus. A political agreement. A spreadsheet that took 400 years to achieve global adoption and is still contested in edge cases.

**The Gregorian calendar is not the measure of time. It is one civilization's attempt to domesticate time into a form compatible with agriculture, taxation, and religious observance.**

---

## Act V: DST — The Recurring Crime Against Logic

Daylight Saving Time was proposed seriously by Benjamin Franklin in 1784 as a joke. He was satirizing Parisian laziness. In the early 1900s, George Hudson (an entomologist who wanted more daylight for bug-collecting) proposed it earnestly. Germany and Austria-Hungary implemented it in 1916 to save coal during World War I.

It has been modified, abolished, reinstated, extended, and fought over in nearly every country that uses it. The United States changed its rules in 2005. The European Union voted to abolish it in 2018. As of 2026, they still haven't actually done it.

In Arizona (USA), they don't observe DST — except the Navajo Nation within Arizona does — except the Hopi Reservation within the Navajo Nation doesn't — except some Navajo communities within the Hopi Reservation do.

This is the system our computers are expected to faithfully represent when they tell you what time it is.

The IANA timezone database — the file that tells every Linux server and smartphone what the rules are — is one of the most frequently updated databases in computing. It is updated multiple times per year because governments keep changing their timezone rules, sometimes with weeks of notice.

**Daylight Saving Time is not a feature. It is a bug that was shipped to production in 1916 and has never been successfully rolled back.**

---

## Act VI: Why UTC Is the Only Honest Clock

UTC — Coordinated Universal Time — does not observe Daylight Saving Time. It does not observe any political decisions whatsoever. It just counts seconds from the agreed-upon epoch.

(Well. Mostly. Leap seconds exist because the Earth's rotation is irregular, and UTC has to periodically insert a "61st second" into a minute to stay within 0.9 seconds of astronomical time. But that is a problem for GPS engineers, not app developers.)

When we fixed the Celtic Calendar bugs, the principle was always the same: **do all arithmetic in UTC. Convert to local time only for display.**

This is not a new idea. Every serious time-handling library in existence — Joda-Time, Java's `java.time`, Rust's `chrono`, Python's `datetime.timezone.utc`, Dart's `DateTime.utc()` — is built around this principle. Store UTC. Display local. Never mix them in calculations.

The bug we found today was a mixing bug. Events were stored in local time. Queries used UTC boundaries. The result was undefined behavior that looked deterministic just often enough to be maddening.

---

## Act VII: The Celtic Calendar Has No Such Problem

Here is the quietly funny thing: the Celtic Tree Calendar, the alternative system we were building, does not have a DST problem.

It does not have timezones. It does not have UTC offsets. It has seasons. It has the solstice. It has trees. The year begins December 24th because that is when the Birch starts its cycle, not because a committee said so.

The calendar we were representing had cleaner semantics than the coordinate system we were using to represent it. The bug existed entirely in the Gregorian layer — the translation between "what tree month is this" and "which millisecond-since-1970 integer does that correspond to."

The fix was to be very precise about which side of that translation you were on at every step. Celtic dates are pure and offset-agnostic. Gregorian dates are local-time hell. The interface between them must be explicitly UTC-normalized to survive the journey through DST country.

```dart
// The moment of translation:
final dUtc  = DateTime.utc(date.year, date.month, date.day);
final ysUtc = DateTime.utc(cy, 12, 24);
final offset = dUtc.difference(ysUtc).inDays;
// ↑ This line crosses from Gregorian chaos into Celtic clarity.
```

---

## Epilogue: Three Lines of Code and a Question

The fix was, ultimately:

1. Normalize `gregorianToCeltic()` to use UTC dates for the offset calculation.
2. Store new events with a UTC midnight timestamp, not a local one.
3. Query events using local midnight boundaries, which work for all timestamps regardless of when they were created.

Three changes. Dozens of lines of investigation. One conceptual error at the root: assuming that "midnight" is an unambiguous concept.

It is not. Midnight is a local event. It happens at different UTC instants in Amsterdam and Auckland. It happens at different UTC instants in Amsterdam in January and Amsterdam in July. Treating it as a fixed point — as a "day boundary" — requires you to specify *which* midnight you mean, every single time.

The Gregorian calendar never tells you this. It just says "April 5th" and leaves the rest as an exercise for the reader.

Meanwhile, the trees don't care. Fearn (Alder) runs from day 85 to day 112 of the Celtic year. It will not shift by an hour because some government decided to save electricity. It will not be represented differently in summer than in winter.

Maybe the people who watched trees and solstices instead of clocks and committees were onto something.

Maybe the real Daylight Saving Time bug is that we are still using a calendar designed to schedule Easter.

---

*Written April 5th, 2026 — Day 19 of Fearn, Year 2025 of the Celtic Tree Calendar.*
*The irony of using a Gregorian date to timestamp an article about Gregorian dates is not lost on us.*
