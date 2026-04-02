# Roots Calendar — Claude Code Instructions

## Project Overview
Build a Flutter mobile app called **Roots Calendar** — a Celtic Tree Calendar (Beth-Luis-Nion, 13-month system) that maps onto the Gregorian calendar, with local event storage and Google Calendar sync.

## App identity
- **App name:** Roots Calendar
- **Package name:** nl.blu8print.rootscalendar
- **Platforms:** Android + iOS
- **Flutter:** 3.x stable

---

## Reference UI
An HTML prototype is included in this folder as `celtic-calendar.html`.
Use it as the **visual and functional reference** for the calendar UI.
Match the dark forest aesthetic: deep greens, gold accents, Cinzel/IM Fell English fonts (use Google Fonts package).
Port the full UI logic from the HTML into Flutter widgets.

---

## Calendar Engine (`lib/engine/celtic_calendar.dart`)
Pure Dart, no Flutter dependencies.

Implement the **Celtic Tree Calendar (Beth-Luis-Nion)**:
- Year starts **December 24** (Beth/Birch)
- 13 months × 28 days = 364 days
- Day 365 = **Year Day** (nameless day, December 23 the following year)
- Leap years: add a **Leap Day** after Year Day

Month definitions (in order):
| # | Name | Tree | Keyword |
|---|------|------|---------|
| 1 | Beth | Birch | New Beginnings |
| 2 | Luis | Rowan | Protection |
| 3 | Nion | Ash | Connection |
| 4 | Fearn | Alder | Guidance |
| 5 | Saille | Willow | Intuition |
| 6 | Huath | Hawthorn | Cleansing |
| 7 | Duir | Oak | Strength |
| 8 | Tinne | Holly | Balance |
| 9 | Coll | Hazel | Wisdom |
| 10 | Muin | Vine | Harvest |
| 11 | Gort | Ivy | Perseverance |
| 12 | Ngetal | Reed | Healing |
| 13 | Ruis | Elder | Transition |

Required functions:
```dart
CelticDate gregorianToCeltic(DateTime gregorian);
DateTime celticToGregorian(int celticYear, int month, int day);
DateTime yearStart(int celticYear); // returns Dec 24 of that year
int celticYearOf(DateTime date);
bool isYearDay(DateTime date);
bool isLeapDay(DateTime date);
List<DateTime> gregorianDatesForMonth(int celticYear, int month);
```

---

## Local Storage (`lib/db/`)

Use **Drift** (SQLite) for local persistence. No data leaves the device.

Schema:

```dart
// events table
class Events extends Table {
  TextColumn get id => text()(); // UUID v4
  IntColumn get celticYear => integer()();
  IntColumn get celticMonth => integer().nullable()(); // null = Year Day or Leap Day
  IntColumn get celticDay => integer().nullable()();
  TextColumn get title => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get color => text().withDefault(const Constant('#c9a84c'))();
  DateTimeColumn get gregorianDate => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get googleEventId => text().nullable()(); // for sync
  BoolColumn get syncedToGoogle => boolean().withDefault(const Constant(false))();
}
```

Implement a `EventsDao` with:
- `getEventsForDay(DateTime date)`
- `getEventsForMonth(int celticYear, int month)`
- `insertEvent(EventsCompanion event)`
- `updateEvent(Event event)`
- `deleteEvent(String id)`
- `getUnsyncedEvents()`

---

## Google Calendar Sync (`lib/services/google_calendar_service.dart`)

Use packages:
- `google_sign_in`
- `googleapis`

Requirements:
- Sign in / sign out
- Read events from Google Calendar for the current Celtic month (map by Gregorian date)
- Write new local events to Google Calendar
- Store `googleEventId` on local events after writing
- **Never send data to any intermediate server — direct device ↔ Google API only**
- Handle auth token refresh gracefully
- Fail silently if offline (queue for next sync)

OAuth scopes needed:
```
https://www.googleapis.com/auth/calendar
```

---

## Screens

### `CalendarScreen` (main screen)
Port directly from the HTML prototype:
- Month card at top (ogham letter, Celtic month name, tree, keyword, Gregorian date range)
- 7-column day grid (28 days, each cell shows Celtic day number + Gregorian date)
- Today highlighted
- Month navigation (prev/next with month names)
- Horizontal scrollable month strip at bottom
- Year navigation
- Special Year Day view (full-width card, purple tones)
- Tap a day → opens `EventDetailScreen`

### `EventDetailScreen`
- Shows Celtic date + Gregorian date
- Lists events for that day
- Add / edit / delete event
- Toggle sync to Google Calendar

### `SettingsScreen`
- Google account sign in / sign out
- Show sync status
- Calendar system selector (placeholder for IFC and others — not implemented yet, just UI stub)

---

## Project Structure
```
lib/
├── main.dart
├── engine/
│   └── celtic_calendar.dart
├── db/
│   ├── database.dart
│   └── events_dao.dart
├── services/
│   └── google_calendar_service.dart
├── screens/
│   ├── calendar_screen.dart
│   ├── event_detail_screen.dart
│   └── settings_screen.dart
├── widgets/
│   ├── month_card.dart
│   ├── day_grid.dart
│   ├── month_strip.dart
│   └── year_day_card.dart
└── theme/
    └── app_theme.dart
```

---

## pubspec.yaml dependencies
```yaml
dependencies:
  flutter:
    sdk: flutter
  drift: ^2.18.0
  sqlite3_flutter_libs: ^0.5.0
  path_provider: ^2.1.0
  path: ^1.9.0
  google_sign_in: ^6.2.0
  googleapis: ^12.0.0
  http: ^1.2.0
  uuid: ^4.4.0
  google_fonts: ^6.2.0
  intl: ^0.19.0
  provider: ^6.1.0

dev_dependencies:
  drift_dev: ^2.18.0
  build_runner: ^2.4.0
```

---

## Theme (`lib/theme/app_theme.dart`)
Match the HTML prototype exactly:

```dart
// Core colours
bg:       #070e06
surface:  #0f1a0e
surface2: #172615
gold:     #c9a84c
gold2:    #e8cc88
cream:    #eee0bc
muted:    #527048
text:     #c0d8b8
dim:      #3a5030
border:   #1e3019
```

Fonts via `google_fonts`:
- Display: `Cinzel Decorative` (headings, month names)
- Serif: `Cinzel` (labels, day numbers)
- Body: `IM Fell English` (descriptions, keywords)

---

## Google Cloud Setup (`GOOGLE_SETUP.md`)
Write a step-by-step guide covering:
1. Create project at console.cloud.google.com
2. Enable Google Calendar API
3. OAuth consent screen setup (External, Testing mode)
4. Add test users (email addresses)
5. Create OAuth 2.0 credentials for Android (SHA-1 fingerprint instructions)
6. Create OAuth 2.0 credentials for iOS (Bundle ID)
7. Where to place `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
8. How to move from Testing → Production (verification process)

---

## Important constraints
- **No data stored on any server** — all events stay on device in Drift
- Google sync is optional — app works fully offline without it
- Design for public App Store release — no hardcoded credentials anywhere
- All secrets come from the Google-provided config files (google-services.json / plist)
- Write clean, maintainable Dart — this will grow into a multi-system calendar app
- Add TODO comments where IFC/other calendar systems will hook in later
