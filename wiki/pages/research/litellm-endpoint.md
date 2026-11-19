---
created: 2026-11-19
type: research
summary: Verified LiteLLM endpoint, model list, SSE streaming shape, and context-window caveats for the chat app.
---

# Research — LiteLLM endpoint for the chat app

Verified against the live homelab proxy on 2026-11-19. Source of truth for the cluster
config: `homelab/infra/clusters/talos/apps/litellm/` and
`homelab/docs/wiki/pages/llamacpp-talos.md`.

Related: [design spec](../specs/ai-chat-app.md) · [implementation plan](../plans/ai-chat-app.md)

## Endpoint

| Item | Value |
|---|---|
| LAN base URL | `https://llm.lan.otakeessen.com/v1` |
| In-cluster base URL | `http://litellm.litellm.svc.cluster.local:4000/v1` |
| API key | `sk-litellm` (fixed LAN-only dummy, not a security boundary) |
| Protocol | OpenAI-compatible: `GET /models`, `POST /chat/completions` |
| Traces | Exported server-side to Langfuse (prompts/responses leave the device but stay in the LAN) |
| Exposure | LAN only; Cloudflare tunnel 404s `*.lan.otakeessen.com` |

The device must resolve `llm.lan.otakeessen.com` to `192.168.2.240` (Pi-hole) and
trust the Let’s Encrypt wildcard. Off-LAN requires the VPN. Do not substitute the raw
IP: TLS SNI/cert validation will fail.

## Models (live `GET /v1/models`)

| id | advertised max input | notes |
|---|---|---|
| `llama3.2-3b-cpp` | 131072 | local llama.cpp, 4096 actual window |
| `qwen2.5-coder-3b-cpp` | 32768 | local, 4096 actual, supports tools |
| `gemma3-1b-cpp` | 32768 | local, 4096 actual, no tools |
| `gemma3-4b-cpp` | 131072 | **live but absent from the repo configmap** |
| `qwen3.5-4b-cpp` | 262144 | local, 4096 actual, strongest/slowest |
| `deepseek-chat` | 131072 | cloud, costs money, 8k max output |

Implications:

- Never hardcode the model list; fetch `/v1/models` and cache, with a static fallback.
- `max_input_tokens` from LiteLLM reflects the upstream model, **not** the llama.cpp
  router’s pinned 4096-token context. A client-side override is required.
- One local model is resident at a time (`--models-max 1`); switching models pays a
  cold-load penalty. Concurrent generations share the 6-core node.

## Streaming shape (verified with `deepseek-chat`)

Request used `stream: true` and `stream_options: {"include_usage": true}`. Response is
`text/event-stream` with `data: <json>` lines and a terminating `data: [DONE]`:

```text
data: {"choices":[{"index":0,"delta":{"content":"","role":"assistant"}}]}
data: {"choices":[{"index":0,"delta":{"content":"Hey"}}]}
data: {"choices":[{"index":0,"delta":{"content":" there"}}]}
data: {"choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}
data: {"choices":[{"delta":{}}],"usage":{"prompt_tokens":10,"completion_tokens":3,"total_tokens":13,"completion_tokens_details":{"reasoning_tokens":0,"text_tokens":3},"cost":3.3e-6}}
data: [DONE]
```

Notes:

- The first chunk may carry an empty content + role; do not render it as a token.
- Usage arrives only when `include_usage` is requested; cost is included for paid models.
- Non-streaming llama.cpp responses additionally include a non-standard `timings` object
  (prompt/predicted tok/s). Streaming does not reliably include it — do not depend on it.
- No `reasoning_content` was observed for `deepseek-chat`. LiteLLM is configured with
  `merge_reasoning_content_in_choices: false`, so a reasoner model would most likely
  deliver `delta.reasoning_content` (possibly under `provider_specific_fields`). Parse
  both defensively; current models emit none.

## Cold start

A non-streaming request to `llama3.2-3b-cpp` returned in ~1.7 s while the model was
loaded. A first request after a model switch can take tens of seconds while the router
loads the GGUF. LiteLLM sets `timeout: 600`, so the client should not impose a short
read timeout, and the UI must narrate the wait (“loading model”).

## Re-verify

```bash
curl -sS --resolve llm.lan.otakeessen.com:443:192.168.2.240 \
  https://llm.lan.otakeessen.com/v1/models \
  -H 'Authorization: Bearer sk-litellm'

curl -sS -N --resolve llm.lan.otakeessen.com:443:192.168.2.240 \
  https://llm.lan.otakeessen.com/v1/chat/completions \
  -H 'Authorization: Bearer sk-litellm' -H 'Content-Type: application/json' \
  -d '{"model":"llama3.2-3b-cpp","messages":[{"role":"user","content":"hi"}],"stream":true,"stream_options":{"include_usage":true},"max_tokens":32}'
```

## Conclusions

1. Implement a plain OpenAI-compatible SSE client; no LiteLLM-specific SDK is needed.
2. Fetch models dynamically; enrich with a local context override for local models.
3. Budget context for 4096 tokens regardless of advertised limits.
4. Treat “thinking” as a UI run state; reasoning text is optional and model-dependent.
5. Verify DNS/TLS from the actual Android device before building the UI (M0).
