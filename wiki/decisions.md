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
- [2026-11-19] D-11 — Render assistant Markdown with gpt_markdown in streaming mode — because it already targets material_ui, reuses settled blocks while streaming, and flutter_markdown is discontinued
- [2026-11-19] D-12 — Keep llama3.2-3b-cpp as the default and dev/test model, with qwen3.5-4b-cpp opt-in — because qwen3.5 emits reasoning_content but took about 74s before its first content token on CPU
- [2026-11-19] D-13 — Translate client-close cancellation and LiteLLM 400 error.type payloads explicitly — because closing the HTTP client throws ClientException and both a bad key and an unknown model return HTTP 400
- [2026-11-19] D-14 — Use Android app id com.otakeessen.chatui — because it is the owned reverse-DNS namespace and replaces the com.example placeholder
- [2026-11-19] D-15 — Keep sqflite rather than adding drift for chat history — because the schema is two simple tables and avoiding codegen keeps the app lean, with the ChatRepository interface isolating a later switch
- [2026-11-19] D-16 — Persist each assistant reply as a streaming placeholder and mark leftovers stopped on launch — because an app kill mid-stream must preserve partial history and surface the interruption
- [2026-11-19] D-17 — Place the model selector above the composer instead of the app bar — because the app-bar chip and actions squeezed conversation titles on phones
- [2026-11-19] D-18 — Allow only one active generation at a time and block chat switching while streaming — because llama.cpp runs one model and one slot, so concurrent runs would queue and confuse latency
- [2026-11-19] D-19 — Use the provided AI Chat Sparkle artwork as the launcher icon — because it matches the app identity and its transparent rounded square works as both legacy and adaptive icons
- [2026-11-19] D-20 — Keep regenerate/retry in the app bar and rename/delete in the conversation drawer — because the extra app-bar overflow squeezed conversation titles
- [2026-11-19] D-21 — Keep drafts in memory per conversation for the session — because persisting them adds little value while composing and keeps storage simple
- [2026-11-19] D-22 — Disable cleartext traffic on Android — because all supported endpoints are HTTPS and this prevents accidental plaintext use
