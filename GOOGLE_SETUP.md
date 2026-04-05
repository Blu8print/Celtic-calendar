# Google Calendar Setup

No SHA-1 fingerprint. No JSON files. Just an iOS OAuth client ID.

## One-time setup (~5 minutes)

### 1. Create a Google Cloud project
1. Go to console.cloud.google.com
2. Click **Select a project → New Project**
3. Name it `Roots Calendar` → **Create**

### 2. Enable the Calendar API
1. APIs & Services → **Library**
2. Search **Google Calendar API** → click it → **Enable**

### 3. Configure the OAuth consent screen
1. APIs & Services → **OAuth consent screen**
2. User type: **External** → Create
3. App name: `Roots Calendar`, fill in your Gmail for support + developer contact
4. Save and Continue through Scopes (skip)
5. Test users → **Add users** → add your Gmail → Save

### 4. Create the OAuth client
1. APIs & Services → **Credentials** → **Create Credentials** → **OAuth 2.0 Client ID**
2. Application type: **iOS** (allows reverse-DNS redirect URIs without SHA-1)
3. Bundle ID: `nl.blu8print.rootscalendar`
4. Skip App Store ID and Team ID
5. Click **Create**

You'll get two values:
- **Client ID** — e.g. `123456789-abcdef.apps.googleusercontent.com`
- **iOS URL scheme** — e.g. `com.googleusercontent.apps.123456789-abcdef`

### 5. Paste both values into three files

**`lib/services/google_calendar_service.dart`** — replace both placeholders:

```dart
static const _clientId =
    '123456789-abcdef.apps.googleusercontent.com';
static const _redirectUri =
    'com.googleusercontent.apps.123456789-abcdef:/oauth2redirect';
```

**`android/app/build.gradle.kts`** — replace the placeholder (scheme only, no `:/oauth2redirect`):

```kotlin
manifestPlaceholders["appAuthRedirectScheme"] = "com.googleusercontent.apps.123456789-abcdef"
```

**`ios/Runner/Info.plist`** — replace the placeholder string:

```xml
<string>com.googleusercontent.apps.123456789-abcdef</string>
```

---

## How sign-in works

1. User taps **Sign in with Google** in Settings
2. Chrome opens with Google standard login
3. User signs in and grants calendar permission
4. Chrome redirects back to the app automatically
5. App syncs immediately

## Going to production

While in **Testing** mode only the email addresses you added in step 3 can sign in.
To open the app to everyone, submit for Google verification (requires a privacy policy URL).
