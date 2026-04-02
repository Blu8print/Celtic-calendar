# Google Calendar Integration Setup

This guide covers everything you need to connect Roots Calendar to Google Calendar.
All communication is **direct device ↔ Google API**. No intermediate server is involved.

---

## 1. Create a Google Cloud Project

1. Go to [console.cloud.google.com](https://console.cloud.google.com).
2. Click **Select a project → New Project**.
3. Name it `Roots Calendar` (or any name you like) and click **Create**.
4. Make sure the new project is selected in the top bar.

---

## 2. Enable the Google Calendar API

1. In the left menu go to **APIs & Services → Library**.
2. Search for **Google Calendar API**.
3. Click it, then click **Enable**.

---

## 3. Configure the OAuth Consent Screen

1. Go to **APIs & Services → OAuth consent screen**.
2. Select **External** (lets you add test users during development).
3. Fill in:
   - **App name:** Roots Calendar
   - **User support email:** your email
   - **Developer contact:** your email
4. On the **Scopes** step, click **Add or Remove Scopes** and add:
   ```
   https://www.googleapis.com/auth/calendar
   ```
5. Complete the wizard. Leave the app in **Testing** mode for now.

---

## 4. Add Test Users

While the app is in Testing mode, only explicitly listed accounts can sign in.

1. Go to **OAuth consent screen → Test users**.
2. Click **+ Add Users**.
3. Enter every email address that will test the app.

---

## 5. Create OAuth Credentials — Android

You need the **SHA-1 fingerprint** of your signing key.

### Get your debug SHA-1 (development)
```bash
# macOS / Linux
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey \
  -storepass android -keypass android

# Windows (PowerShell)
keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" `
  -alias androiddebugkey -storepass android -keypass android
```
Copy the `SHA1:` value.

### Create the credential
1. Go to **APIs & Services → Credentials → Create Credentials → OAuth client ID**.
2. Application type: **Android**.
3. Package name: `nl.blu8print.rootscalendar`
4. SHA-1: paste your debug SHA-1.
5. Click **Create**.
6. Download the `google-services.json` file that appears.

### Place the file
```
android/
└── app/
    └── google-services.json   ← place it here
```

### Wire it up in Gradle
`android/build.gradle` — add to `dependencies`:
```groovy
classpath 'com.google.gms:google-services:4.4.1'
```

`android/app/build.gradle` — add at the bottom:
```groovy
apply plugin: 'com.google.gms.google-services'
```

---

## 6. Create OAuth Credentials — iOS

1. Go to **APIs & Services → Credentials → Create Credentials → OAuth client ID**.
2. Application type: **iOS**.
3. Bundle ID: `nl.blu8print.rootscalendar`
4. Click **Create**.
5. Download the `GoogleService-Info.plist` file.

### Place the file
```
ios/
└── Runner/
    └── GoogleService-Info.plist   ← place it here
```

Open `ios/Runner.xcworkspace` in Xcode and drag the file into the **Runner** group,
making sure **Copy items if needed** is checked.

### Add the URL scheme
In `ios/Runner/Info.plist`, add the `REVERSED_CLIENT_ID` from your plist:
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <!-- Copy REVERSED_CLIENT_ID value from GoogleService-Info.plist -->
      <string>com.googleusercontent.apps.YOUR_CLIENT_ID_HERE</string>
    </array>
  </dict>
</array>
```

---

## 7. No hardcoded credentials

**Never** commit `google-services.json` or `GoogleService-Info.plist` to a public
repository. Add them to `.gitignore`:

```
android/app/google-services.json
ios/Runner/GoogleService-Info.plist
```

The app reads credentials exclusively from these platform files at runtime.

---

## 8. Moving from Testing → Production

When you're ready to release publicly:

1. Go to **OAuth consent screen → Publishing status → Publish App**.
2. If your app requests the `calendar` scope (which it does), Google requires
   **verification**:
   - Submit your app for verification via the consent screen wizard.
   - Provide a privacy policy URL (required — host a simple page).
   - Provide a demo video showing OAuth usage.
   - Wait for Google's review (typically 1-6 weeks for sensitive scopes).
3. Once verified, any Google account can sign in — the 100-user testing cap is lifted.

### Privacy policy minimum requirements
Your policy must state:
- What data the app accesses (Google Calendar events).
- That no data is stored on external servers.
- How users can revoke access (Google Account → Security → Third-party apps).

---

## Quick checklist

- [ ] Google Cloud project created
- [ ] Google Calendar API enabled
- [ ] OAuth consent screen configured (External, Testing)
- [ ] Test users added
- [ ] Android OAuth credential created (correct package name + SHA-1)
- [ ] `google-services.json` in `android/app/`
- [ ] iOS OAuth credential created (correct Bundle ID)
- [ ] `GoogleService-Info.plist` in `ios/Runner/` and added to Xcode
- [ ] `REVERSED_CLIENT_ID` URL scheme added to `Info.plist`
- [ ] Both config files added to `.gitignore`
