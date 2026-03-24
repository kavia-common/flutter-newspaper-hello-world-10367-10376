# flutternewspaper_frontend

A Flutter newspaper demo application.

## Universal (fat) release APK (single installable file)

This project is configured to **avoid ABI splits** so that building a release APK produces **one universal APK**
that includes both **arm64-v8a** and **armeabi-v7a** native libraries (compatible with typical Android 13 phones).

### Build command

From this directory (`flutternewspaper_frontend/`):

```bash
flutter build apk --release
```

### APK to install (artifact path)

Install this generated APK on your device:

```
build/app/outputs/flutter-apk/app-release.apk
```

If you see multiple APKs like `app-arm64-v8a-release.apk`, ABI splits are enabled somewhere; this repo disables them
in `android/app/build.gradle.kts` to ensure a single universal artifact.
