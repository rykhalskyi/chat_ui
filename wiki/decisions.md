# Decisions

Append-only decision record. The "why" lives here; the full change history lives in git.
- [2026-11-19] D-01 — Drive chat through an OpenAI-compatible /v1/chat/completions client behind an LlmClient interface — because LiteLLM, OpenAI, Ollama, and vLLM speak it, so connectors swap without UI changes
- [2026-11-19] D-02 — Persist chat history locally in SQLite via sqflite — because this is a single-user MVP that must work offline without a backend
- [2026-11-19] D-03 — Use provider + ChangeNotifier controllers for state and DI — because it needs no codegen, is easy to override in widget tests, and keeps the app small
- [2026-11-19] D-04 — Use package:http with one client per request for SSE and cancellation — because closing the client aborts the stream and avoids a dio dependency
- [2026-11-19] D-05 — Enforce a client-side 4096-token budget for local *-cpp models regardless of LiteLLM max_input_tokens — because llama.cpp pins 4096 and the advertised limits overstate it
- [2026-11-19] D-06 — Store model_id on each assistant message; conversation model is only the default — because switching models must not rewrite history provenance
- [2026-11-19] D-07 — Derive conversation titles from the first user message locally — because background title generation would queue behind the main request on the single-slot CPU
- [2026-11-19] D-08 — Show a run-state thinking indicator and render reasoning_content only when emitted — because current models emit no reasoning and synthetic chain-of-thought would be misleading
- [2026-11-19] D-09 — Store the API key in flutter_secure_storage and non-secret settings in shared_preferences — because the LAN key is a dummy but connectors may later target paid APIs
- [2026-11-19] D-10 — Target Android first for v1 — because only the Android host is scaffolded and web/desktop introduce CORS, TLS, and secure-storage differences
