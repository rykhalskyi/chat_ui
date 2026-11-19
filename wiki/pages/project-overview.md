---
created: 2026-11-19
type: overview
status: in-progress
summary: Flutter chat UI app (chat_ui_3) — tech stack, architecture, and folder layout.
---

# Project Overview

`chat_ui_3` is an early-stage Flutter application (Material app) intended as a chat
interface. It currently ships the default counter demo in `lib/main.dart`; no chat
features are implemented yet.

## Tech stack

- **Framework:** Flutter (stable channel), Dart SDK `^3.14.0`.
- **UI library:** `material_ui: ^1.1.0` — the app imports
  `package:material_ui/material_ui.dart` instead of `package:flutter/material.dart`.
- **Icons:** `cupertino_icons`.
- **Lints:** `flutter_lints` (`package:flutter_lints/flutter.yaml`), analyzer excludes
  `build/**` and `android/**`.
- **Platforms:** Android (only platform folder present; iOS/web/desktop not scaffolded).
- **Language features:** Dart 3.x dot-shorthands are used, e.g.
  `colorScheme: .fromSeed(...)` in `lib/main.dart:34`.

## Architecture

Single-entry Flutter app, no state-management or networking layer yet.

- `lib/main.dart` — `main()` → `MyApp` (`MaterialApp`, theme seeded with
  `Colors.deepPurple`) → `MyHomePage` (`StatefulWidget` with a `_counter` and an
  increment FAB).
- `test/widget_test.dart` — widget smoke test asserting the counter increments.

## Folder structure

```
chat_ui/
├── lib/main.dart            # app entry point and demo widget tree
├── test/widget_test.dart    # widget smoke test
├── android/                 # Android host (Kotlin, Gradle KTS)
│   └── app/src/main/kotlin/com/example/chat_ui_3/MainActivity.kt
├── wiki/                    # this project knowledge base
├── scripts/wiki.mjs         # wiki helper (index/log/decision/lint)
├── pubspec.yaml             # deps + version 1.0.0+1
└── analysis_options.yaml    # lints (flutter_lints)
```

## Identifiers

- Package name: `chat_ui_3`
- Android `applicationId` / namespace: `com.example.chat_ui_3`
- Kotlin entry: `android/app/src/main/kotlin/com/example/chat_ui_3/MainActivity.kt`

## Planned work

The app is being designed as a small AI chat client for the homelab LiteLLM proxy:
[epic](epics/ai-chat-app.md) · [design spec](specs/ai-chat-app.md) ·
[implementation plan](plans/ai-chat-app.md).

## Notes

- The repository is **not** currently a git repo (`git status` fails); the wiki has no
  git-backed history until it is initialized.
- README is still the stock Flutter template.
