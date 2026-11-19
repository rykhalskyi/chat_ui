---
created: 2026-11-19
type: build-deploy
summary: Flutter build, run, test, lint commands and wiki helper usage.
---

# Build & Deploy

All commands run from the project root (`/home/admin/Source/chat_ui`). Flutter is at
`/home/admin/Source/flutter/bin/flutter`.

## Dependencies

```bash
flutter pub get
```

## Run

```bash
flutter run              # debug on attached device/emulator
flutter run --release
```

### Android emulator

```bash
flutter emulators --launch Medium_Phone   # boot can take several minutes
flutter devices
flutter run -d emulator-5554
```

`adb` is at `/home/admin/Android/Sdk/platform-tools/adb` (not on `PATH`). Manual
`emulator` launches of this API 37 AVD segfaulted; the `flutter emulators --launch`
instance works. The emulator resolves the LAN host and trusts its cert (verified), but a
physical-device check is still advisable before release.

## Analyze & test

```bash
flutter analyze          # static analysis (flutter_lints)
flutter test             # widget tests in test/
flutter test test/widget_test.dart
```

## Build (Android only)

```bash
flutter build apk --debug
flutter build apk --release   # currently signed with debug keys
```

Release signing is not configured: `android/app/build.gradle.kts` signs release with
the debug config. Add a real keystore before publishing. Cleartext HTTP is disabled
(`android:usesCleartextTraffic="false"`); use HTTPS endpoints.

### Launcher icon

Source image: `assets/branding/app_icon.png` (not bundled into the APK). Generated
legacy icons live in `android/app/src/main/res/mipmap-*`, and the adaptive icon uses
`mipmap-anydpi-v26/ic_launcher.xml` plus `drawable-*/ic_launcher_foreground.png` and the
`ic_launcher_background` color (`#171420`). Regenerate the PNGs with ImageMagick after
changing the source.

## Codegen / formatting

```bash
dart format lib test
```

## Version

The app version is `version: 0.2.0+2` in `pubspec.yaml` (Android `versionName 0.2.0`,
`versionCode 2`). Settings reads it at runtime with `package_info_plus`; if the platform
channel is unavailable it falls back to `0.2.0 (build 2)`.

## LAN DNS override

If the phone is on the LAN but does not use Pi-hole DNS, Settings → **LAN access**:
enable **Use LAN IP override** and set the connect address (e.g. `192.168.2.240`). The
base URL stays `https://llm.lan.otakeessen.com/v1`; the app dials the IP but keeps the
hostname for TLS/SNI and certificate validation. Turn the switch off for a LiteLLM
endpoint that uses normal DNS. This only works when the phone can route to the LAN IP;
off-LAN still needs the VPN.

The app waits up to 10 minutes for response headers (cold model loads) and 15 seconds for
the TCP/TLS connect.

## Wiki helper

Requires Node.js (v24 available). Run from project root:

```bash
node scripts/wiki.mjs index        # regenerate wiki/index.md
node scripts/wiki.mjs log <action> "<description>"
node scripts/wiki.mjs decision "<decision> — because <reason>"
node scripts/wiki.mjs lint
```

No `package.json` exists, so there is no `npm run wiki` alias; invoke `node` directly.
