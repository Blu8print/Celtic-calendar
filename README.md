# Roots Calendar

A Celtic Tree Calendar app (Beth-Luis-Nion, 13-month system) for Android and iOS, built with Flutter.

The calendar maps the ancient Celtic lunar month system onto the Gregorian calendar, with optional Google Calendar sync. All events are stored locally on your device — no server, no account required.

---

## Features

- Full Beth-Luis-Nion Celtic calendar (13 months × 28 days, Year Day, Leap Day)
- Month and year navigation with ogham symbols and tree keywords
- Local event storage with Drift (SQLite) — works fully offline
- Optional two-way Google Calendar sync (PKCE OAuth, no intermediate server)
- Home screen widget showing today's Celtic date
- Reminder notifications
- Light and dark themes

---

## Requirements

- Flutter 3.x stable
- Android SDK 21+ / iOS 13+
- A Google Cloud project with the Calendar API enabled (for sync — optional)

---

## Build locally

```bash
# 1. Clone
git clone https://github.com/Blu8print/Celtic-calendar.git
cd Celtic-calendar

# 2. Install dependencies
flutter pub get

# 3. Generate Drift database code
dart run build_runner build --delete-conflicting-outputs

# 4. Run on a connected device or emulator
flutter run
```

> Google Calendar sync will not work until you add `android/app/google-services.json`
> and `ios/Runner/GoogleService-Info.plist`. See [GOOGLE_SETUP.md](GOOGLE_SETUP.md).

---

## Run tests

```bash
flutter test
```

---

## Release build (Android)

Set the following environment variables before building:

| Variable | Description |
|---|---|
| `KEYSTORE_PATH` | Absolute path to your `.jks` keystore file |
| `KEYSTORE_PASSWORD` | Keystore store password |
| `KEY_ALIAS` | Key alias inside the keystore |
| `KEY_PASSWORD` | Key password |

Generate a keystore once:

```bash
keytool -genkey -v -keystore roots-calendar.jks \
        -keyalg RSA -keysize 2048 -validity 10000 \
        -alias roots-calendar
```

Then build:

```bash
export KEYSTORE_PATH=/path/to/roots-calendar.jks
export KEYSTORE_PASSWORD=...
export KEY_ALIAS=roots-calendar
export KEY_PASSWORD=...

flutter build apk --release        # APK for sideloading
flutter build appbundle --release  # AAB for Play Store
```

---

## CI/CD

GitHub Actions runs automatically on every push to `master`/`main`:
- `flutter analyze`
- `flutter test`

On every `v*.*.*` tag push, it also builds and signs the APK and AAB, then attaches them to a GitHub Release.

Required GitHub secrets for release builds:

| Secret | Description |
|---|---|
| `KEYSTORE_BASE64` | `base64 roots-calendar.jks` output |
| `KEYSTORE_PASSWORD` | Keystore store password |
| `KEY_ALIAS` | Key alias |
| `KEY_PASSWORD` | Key password |
| `GOOGLE_SERVICES_JSON` | Contents of `google-services.json` |

---

## Google Calendar sync setup

See [GOOGLE_SETUP.md](GOOGLE_SETUP.md) for step-by-step instructions to create a Google Cloud project, enable the Calendar API, and configure OAuth credentials.

**Important:** The OAuth consent screen must be moved from *Testing* to *Production* before real users can sign in. See GOOGLE_SETUP.md §8.

---

## Crash reporting

The app uses Firebase Crashlytics. To enable it:

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Add an Android app (package `nl.blu8print.rootscalendar`) and download `google-services.json` → place in `android/app/`
3. Add an iOS app (bundle ID `nl.blu8print.rootscalendar`) and download `GoogleService-Info.plist` → place in `ios/Runner/`

The app runs normally without these files — crash reports simply won't be sent.

---

## Data & privacy

- All events are stored locally in a SQLite database on your device.
- No data is sent to any server operated by this app.
- Google Calendar sync communicates directly with Google's API from your device.
- See [privacy.html](privacy.html) for the full privacy policy.

---

## License

MIT
