# Changelog

All notable changes to Roots Calendar are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added
- Global Flutter and platform error handlers with Firebase Crashlytics integration
- Unit tests for the Celtic calendar engine (32 tests, including DST regression)
- Unit tests for the local events database (16 tests)
- GitHub Actions CI pipeline (analyze + test on every push)
- GitHub Actions release pipeline (build, sign, and publish APK/AAB on version tags)
- Android Auto Backup rules — Drift database is backed up; OAuth tokens are excluded
- Exponential backoff for Google Calendar sync retries (network errors, 429 rate limits)
- Proactive sign-out when Google token refresh returns `invalid_grant`

### Fixed
- Background widget update task now logs errors instead of silently swallowing them
- Release builds use env-var keystore instead of debug signing key
- `android/local.properties` added to `.gitignore`

---

## [1.0.0] — 2026-04-17

### Added
- Celtic Tree Calendar (Beth-Luis-Nion): 13 months × 28 days, Year Day, Leap Day
- Gregorian calendar mapping with DST-safe UTC normalisation
- Local event storage with Drift (SQLite) — insert, edit, delete, recurring events
- Google Calendar two-way sync (AppAuth PKCE — no SHA-1, no server)
- Home screen widget showing today's Celtic date and upcoming events
- Reminder notifications (local, scheduled with flutter_local_notifications)
- Month card view with ogham symbol, tree name, keyword, Gregorian date range
- 7-column 28-day grid with today highlight and event dot indicators
- Month strip navigation and year navigation
- Year Day full-width card (nameless day)
- Gregorian year view and multi-day schedule view
- Light and dark themes (deep forest palette with Cinzel / IM Fell English fonts)
- Onboarding screen for first-time users
- Settings screen: Google sign-in/out, sync status, theme toggle
- Privacy policy page
