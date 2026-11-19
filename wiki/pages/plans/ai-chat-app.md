---
created: 2026-11-19
type: plan
status: proposed
summary: Ordered implementation plan and milestones for the Flutter LiteLLM chat app.
---

# Plan — Flutter AI chat app

Implements the [design spec](../specs/ai-chat-app.md) for the
[epic](../epics/ai-chat-app.md). Endpoint evidence:
[LiteLLM research](../research/litellm-endpoint.md).

Estimate: **6.5–7.5 dev days** for one developer, Android target. No code has been
written yet. Start only after M0 passes.

## Sequencing

```mermaid
flowchart LR
  m0["M0 Validate"] --> m1["M1 Skeleton + settings"]
  m1 --> m2["M2 LLM layer"]
  m1 --> m3["M3 Persistence"]
  m2 --> m4["M4 Chat UI MVP"]
  m3 --> m4
  m4 --> m5["M5 Polish"]
  m5 --> m6["M6 Hardening"]
```

M2 and M3 can run in parallel once M1 lands. M4 is the integration point and uses
`MockLlmClient` first, then the live proxy.

## M0 — Validate assumptions (0.5 d)

Goal: retire the two risks that could invalidate the design.

1. **Device access:** on the actual Android device/emulator, `GET
   https://llm.lan.otakeessen.com/v1/models` with `sk-litellm`. Confirm DNS resolves to
   `192.168.2.240` and the wildcard cert is trusted. If not, fix via LAN DNS/VPN and
   write the workaround down. Do not use the raw IP (cert/SNI failure).
2. **Streaming from Dart:** a throwaway `dart run` script or test using `http` against
   `/chat/completions` with `stream: true`; confirm incremental SSE chunks arrive and
   can be cancelled by closing the client.
3. **Package picks:** verify the Markdown widget renders chat-style Markdown on Flutter
   3.50 and the chosen package is maintained (`gpt_markdown` preferred; fall back to
   `markdown_widget`/`flutter_markdown` forks). Verify `sqflite` works on the target and
   `sqflite_common_ffi` in host tests. Verify `material_ui` re-exports the widgets used.
4. Optional: decide whether to add the Linux desktop host
   (`flutter create --platforms=linux .`) for fast iteration; note secure-storage
   implications.

Acceptance: one streamed reply on-device (or a documented, accepted workaround), package
choices recorded. Append results to the research page.

## M1 — Skeleton, settings, DI (1 d)

Dependencies (`pubspec.yaml`, pin via lockfile):

- Runtime: `http`, `provider`, `sqflite`, `path`, `path_provider`,
  `shared_preferences`, `flutter_secure_storage`, `uuid`, Markdown package chosen in M0.
- Dev: `sqflite_common_ffi` (host tests), existing `flutter_lints`/`flutter_test`.

Work:

1. Create the folder structure from the spec; keep `main.dart` as bootstrap.
2. `app_theme.dart` (Material 3, light/dark/system) and an app shell with a placeholder
   home screen.
3. `SettingsRepository` (prefs for base URL/default model/system prompt/temperature/
   max tokens/theme; secure storage for the key) with sensible defaults:
   base URL `https://llm.lan.otakeessen.com/v1`, model `llama3.2-3b-cpp`, temperature
   `0.7`, max tokens `1024`.
4. `SettingsController` + settings screen with masked key, “Test connection”
   (`GET /v1/models`), theme switch. Wire dependencies with `provider`.
5. Add `INTERNET` permission to the main manifest.

Files: `lib/main.dart`, `lib/app.dart`, `lib/core/app_theme.dart`,
`lib/domain/repositories/settings_repository.dart`,
`lib/data/prefs_settings_repository.dart`, `lib/ui/settings/*`.

Acceptance: settings persist across restart; test connection reports the live model
count or a readable error; `flutter analyze` clean.

## M2 — LLM layer (1 d)

Work:

1. `domain/llm/llm_client.dart`: `LlmClient`, `LlmStreamHandle`, `ChatRequest`,
   `ChatStreamEvent` (sealed), `ModelInfo`, `TokenUsage`, `FinishReason`.
2. `core/sse_parser.dart`: byte/line decoder that yields `data` payloads, handles CRLF,
   comments, multiple chunks per line, `[DONE]`.
3. `data/litellm_client.dart`: `GET /models`, `POST /chat/completions` streaming;
   per-request `http.Client` for cancellation; error mapping to `LlmException`.
4. `data/mock_llm_client.dart`: canned stream with configurable delay, reasoning
   delta option, and error injection for tests/demo.
5. `authored` unit tests: SSE parser table tests, client happy path/error/cancel using
   `http.testing.MockClient`, model parsing.
6. Optional debug screen: send “hi” and print stream events, used only in development.

Files: `lib/domain/llm/*`, `lib/core/sse_parser.dart`, `lib/core/exceptions.dart`,
`lib/data/litellm_client.dart`, `lib/data/mock_llm_client.dart`,
`test/sse_parser_test.dart`, `test/litellm_client_test.dart`.

Acceptance: unit tests pass; a dev screen streams against the live proxy; cancellation
stops network activity and yields a cancelled terminal event.

## M3 — Persistence (1 d)

Work:

1. `app_database.dart`: open DB, `PRAGMA foreign_keys=ON`, version 1 schema from the
   spec; a migration hook for future versions; `databaseFactory` selection so host tests
   use `sqflite_common_ffi`.
2. `chat_dao.dart`: conversations/messages CRUD, ordered reads, cascade delete,
   `updated_at` touch, transaction for “insert user + assistant placeholder”.
3. `ChatRepository` implementation: create/open/rename/delete conversation, append
   messages, throttled update of a streaming message, finalize, recovery of
   `streaming` rows on startup.
4. Tests on `sqflite_common_ffi`: CRUD, ordering, cascade, recovery, long content.

Files: `lib/data/db/app_database.dart`, `lib/data/db/chat_dao.dart`,
`lib/data/sqflite_chat_repository.dart`,
`lib/domain/repositories/chat_repository.dart`, `test/chat_repository_test.dart`.

Acceptance: repository tests pass; reopening the DB preserves conversations and message
order; an interrupted row becomes `stopped` with an error note.

## M4 — Chat UI MVP (2 d)

Work:

1. `ConversationsController` + drawer/rail: new chat, open, rename, delete, relative
   times.
2. `ChatController`: load conversation, draft, send, cancel, retry/regenerate; stream
   event handling; throttled persistence; single active run globally; expose run state
   for the status row.
3. Chat screen and widgets:
   - `message_bubble` (user/assistant, Markdown, copy, reasoning panel, footer),
   - `composer` (auto-grow, send/stop),
   - `run_status` (spinner/label/elapsed, error + retry),
   - `model_selector` (bottom sheet from `/v1/models`, context badge, refresh),
   - `empty_state` (examples + model picker),
   - auto-scroll with “jump to latest”.
4. `context_budget.dart` and integration: override `*-cpp` to 4096, trim oldest turns,
   show the trim notice.
5. Wire `main.dart`: DB init, settings load, factory chooses `LiteLlmClient` or
   `MockLlmClient` (debug/demo flag).
6. Widget tests with `MockLlmClient`: send, status transitions, stop, error/retry, model
   selector, history.

Acceptance: end-to-end chat works with the mock and the live proxy; stopping keeps the
partial text; a conversation with >4096 estimated tokens is trimmed and still answers;
no duplicate messages after retry.

## M5 — Polish (1 d)

- Rename/delete from the app bar and drawer; delete confirmation; empty-state handling.
- Regenerate last answer; copy message; preserve draft per conversation.
- Footer metadata: model, tokens/cost when provided; no fabricated timings.
- Responsive layout (drawer ↔ rail), theme polish, keyboard insets, safe areas.
- Accessibility: semantics labels, 48 dp targets, readable contrast.
- Markdown edge cases: fenced code, long lines, links (open externally only if a URL
  launcher is added — otherwise plain text).

Acceptance: UX checklist from the spec passes on a phone-sized emulator; dark mode
legible; no overflow errors in release-sized text scaling.

## M6 — Hardening, QA, docs (1 d)

1. Release manifest: `INTERNET` permission present; confirm no cleartext traffic.
2. Manual matrix against live LiteLLM:
   - each model (including `gemma3-4b-cpp` from live `/models`),
   - cold start after a model switch,
   - stop mid-stream, airplane mode mid-stream, 401 with a wrong key,
   - kill the app during a stream → reopen shows `stopped`,
   - long chat (trim notice), rapid conversation switching.
3. Confirm no key/prompt logging in release (`flutter run --release` + logcat).
4. Run `flutter analyze`, `flutter test`, `flutter build apk --release` (debug signing).
5. Update `wiki/pages/project-overview.md` (tech stack/architecture) and
   `wiki/pages/build-deploy.md` (new run/test notes); log the epic outcome.

Acceptance: test suite green; release APK builds; manual matrix signed off.

## Definition of done

- All success criteria in the [spec](../specs/ai-chat-app.md) and [epic](../epics/ai-chat-app.md)
  are met.
- `flutter analyze` clean, `flutter test` green, release APK builds.
- No secrets or prompt text in logs; key stored outside plain prefs on Android.
- Wiki updated: overview/build-deploy, tickets for completed milestones, decisions for
  any deviations.

## Risks & mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Phone cannot reach LAN host (DNS/cert/VPN) | blocker | M0 on real device; VPN; never use raw IP |
| Cold model load looks frozen (10–60 s) | UX | `Waiting for model…` + elapsed; generous timeouts; hint after 5 s |
| LiteLLM advertises 131k but llama.cpp is 4096 | failed/expensive requests | client override + trimming + notice; test long chat |
| One model, one slot; concurrent sends queue | confusing latency | single active run; stop prompt in other chats |
| DeepSeek costs money | surprise spend | local model default; show cost; no auto-fallback UI confusion |
| Markdown package churn | rework | validate/pin in M0; isolate rendering in one widget |
| `http` cancellation leaves the stream open | wasted tokens | per-request client + test that close aborts |
| Secure storage unavailable on a dev target | blocked onboarding | Android-first; document fallback for desktop |
| Prompts are traced in Langfuse server-side | privacy expectation | state it in settings/about; LAN-only |

## Ticket breakdown (create on start)

| Slug | Scope |
|---|---|
| `ticket-m0-endpoint-spike` | Device connectivity + package validation |
| `ticket-m1-app-shell-settings` | Theme, shell, settings, DI |
| `ticket-m2-llm-client` | Interface, SSE parser, LiteLLM + mock clients |
| `ticket-m3-chat-persistence` | sqflite schema, DAO, repository, recovery |
| `ticket-m4-chat-ui` | Chat screen/controllers/status/model selector |
| `ticket-m5-ux-polish` | History actions, markdown, responsive, a11y |
| `ticket-m6-hardening` | QA matrix, release build, docs |
