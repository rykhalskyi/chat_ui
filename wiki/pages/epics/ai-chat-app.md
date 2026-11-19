---
created: 2026-11-19
type: epic
status: proposed
summary: Flutter AI chat app backed by the homelab LiteLLM proxy — design and delivery milestones.
---

# Epic — Flutter AI chat app on LiteLLM

Turn the stock Flutter app (`chat_ui_3`) into a small, usable AI chat client for the
homelab LiteLLM proxy: streaming chat, local history, model selection, run/thinking
status, and a connector abstraction so LiteLLM can be swapped for another
OpenAI-compatible backend without touching the UI.

Design only for now — no implementation code has been written.

- [Design spec](../specs/ai-chat-app.md)
- [Implementation plan](../plans/ai-chat-app.md)
- [Research: LiteLLM endpoint facts](../research/litellm-endpoint.md)
- [Project overview](../project-overview.md)

## Scope (MVP)

- Streaming chat against `https://llm.lan.otakeessen.com/v1` (key `sk-litellm`).
- Multiple conversations with local persistence, rename/delete, history restore.
- Per-conversation model selector populated from `GET /v1/models`.
- Status/“thinking” indicator: connecting, loading model, thinking, streaming, done,
  stopped, failed. Render `reasoning_content` when a model emits it.
- Stop generation, retry/regenerate, copy, markdown rendering.
- Settings: base URL, API key, default model, sampling options, theme, test connection.
- Connector interface: `LlmClient` with a LiteLLM implementation and a mock.

## Out of scope (v1)

- Accounts/auth, server-side sync, multi-user.
- Tools/function calling, RAG/knowledge, image or file input, web search.
- Background title/tag/follow-up generations.
- iOS/web/desktop releases (Android first; only the Android host exists).

## Milestones

| # | Milestone | Status | Est. |
|---|---|---|---|
| M0 | Validate device access, package choices | proposed | 0.5 d |
| M1 | App skeleton, settings, DI | proposed | 1 d |
| M2 | LLM layer (interface + SSE client) | proposed | 1 d |
| M3 | SQLite history | proposed | 1 d |
| M4 | Chat UI MVP | proposed | 2 d |
| M5 | Polish (history actions, markdown, status) | proposed | 1 d |
| M6 | Hardening, QA, docs | proposed | 1 d |

## Success criteria

- A reply streams token-by-token from any listed model and can be stopped mid-run.
- Chat history survives app restart; interrupted runs are marked, not lost.
- Long chats do not silently exceed the 4096-token llama.cpp window.
- Switching to another OpenAI-compatible provider is a settings/client change only.
- `flutter analyze` and `flutter test` pass; no API key or prompt text in logs.
