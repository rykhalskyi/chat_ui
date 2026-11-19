---
created: 2026-11-19
type: overview
status: in-progress
summary: Flutter chat UI app (chat_ui_3) — tech stack, architecture, and folder layout.
---

# Project Overview

`chat_ui_3` is a Flutter AI chat client for the homelab LiteLLM proxy. M1–M4 are
implemented: settings and secure key storage, an OpenAI-compatible SSE client behind
`LlmClient`, local SQLite history with interrupted-run recovery, and a streaming chat UI
with a model selector, reasoning panel, stop/retry, and history restore. Polish and
hardening remain (M5–M6).

## Tech stack

- **Framework:** Flutter (stable channel), Dart SDK `^3.14.0`.
- **UI library:** `material_ui: ^1.1.0` — the app imports
  `package:material_ui/material_ui.dart` instead of `package:flutter/material.dart`.
- **Icons:** `cupertino_icons`.
- **State/DI:** `provider` (`ChangeNotifier` controllers).
- **Networking:** `http` (OpenAI-compatible REST + SSE).
- **Storage:** `shared_preferences` (settings), `flutter_secure_storage` (API key),
  `sqflite` (conversations/messages).
- **Rendering:** `gpt_markdown` (streaming chat Markdown).
- **Lints:** `flutter_lints` (`package:flutter_lints/flutter.yaml`), analyzer excludes
  `build/**` and `android/**`.
- **Platforms:** Android (only platform folder present; iOS/web/desktop not scaffolded).
- **Language features:** Dart 3.x (records, sealed classes, switch expressions).

## Architecture

Layered Flutter app with constructor-injected dependencies provided via `provider`.

- `lib/main.dart` — bootstrap: prefs + secure storage, settings, SQLite open, recovery.
- `lib/app.dart` — `MaterialApp`, light/dark themes, theme mode from `SettingsController`.
- `lib/core/` — theme, `SseParser`, URI normalization, `LlmException`.
- `lib/ui/home/` — placeholder home; opens settings.
- `lib/ui/settings/` — `SettingsScreen` + `SettingsController` (load/save, connection test).
- `lib/ui/chat/` — `ChatScreen`, chat/conversation controllers, conversation panel,
  message bubbles, composer, run status, model selector.
- `lib/domain/llm/` — `LlmClient`/`LlmStreamHandle`, `ChatRequest`, typed stream events.
- `lib/domain/entities/` — `AppSettings`, `ModelInfo`, `Conversation`, `Message`.
- `lib/domain/repositories/` — settings and chat repository contracts.
- `lib/data/` — settings repo, model catalog, `LiteLlmClient`, `MockLlmClient`,
  `SqfliteChatRepository`, and the SQLite DAO/schema.
- `test/` — 42 unit/widget tests with fakes and `sqflite_common_ffi`.

## Folder structure

```
chat_ui/
├── lib/
│   ├── main.dart            # bootstrap + DI
│   ├── app.dart             # MaterialApp + theme mode
│   ├── core/                # theme, SSE parser, URIs, LlmException
│   ├── domain/
│   │   ├── entities/        # AppSettings, ModelInfo, Conversation, Message
│   │   ├── llm/             # LlmClient, ChatRequest, stream events
│   │   └── repositories/    # SettingsRepository, ChatRepository
│   ├── data/
│   │   ├── db/              # AppDatabase schema + ChatDao
│   │   ├── litellm_client.dart / mock_llm_client.dart
│   │   ├── sqflite_chat_repository.dart
│   │   └── prefs_settings_repository.dart / model_catalog_client.dart
│   └── ui/
│       ├── chat/            # screen, controllers, chat widgets
│       └── settings/        # settings screen + controller
├── test/                    # unit/widget tests + fakes
├── android/                 # Android host (Kotlin, Gradle KTS)
│   └── app/src/main/kotlin/com/otakeessen/chatui/MainActivity.kt
├── wiki/                    # this project knowledge base
├── scripts/wiki.mjs         # wiki helper (index/log/decision/lint)
├── pubspec.yaml             # deps + version 1.0.0+1
└── analysis_options.yaml    # lints (flutter_lints)
```

## Identifiers

- Dart package name: `chat_ui_3`
- Android `applicationId` / namespace: `com.otakeessen.chatui`
- Android app label: `Chat UI`
- Kotlin entry: `android/app/src/main/kotlin/com/otakeessen/chatui/MainActivity.kt`

## Planned work

The app is being designed as a small AI chat client for the homelab LiteLLM proxy:
[epic](epics/ai-chat-app.md) · [design spec](specs/ai-chat-app.md) ·
[implementation plan](plans/ai-chat-app.md).

## Notes

- Git remote: `git@github.com:rykhalskyi/chat_ui.git` (branch `main`).
- README is still the stock Flutter template.
