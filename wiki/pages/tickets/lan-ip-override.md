---
created: 2026-11-19
type: ticket
status: implemented
summary: Switchable LAN IP override to bypass phone DNS while preserving TLS hostname validation (v0.2.0).
---

# LAN IP override (v0.2.0)

Part of the [AI chat app spec](../specs/ai-chat-app.md); operational notes in
[build & deploy](../build-deploy.md#lan-dns-override).

## Spec

- The phone may be on the LAN but use a DNS server that cannot resolve
  `*.lan.otakeessen.com`.
- Settings → **LAN access** gets a switch and a **Connect address** field
  (e.g. `192.168.2.240`).
- The base URL stays `https://llm.lan.otakeessen.com/v1`; the app dials the IP but keeps
  the hostname for TLS/SNI and certificate validation.
- Switching it off restores normal DNS, so another LiteLLM endpoint can be used.
- Only works when the phone can route to the LAN IP; off-LAN still needs the VPN.
- Raise the response-header timeout from 15 s to 10 minutes for cold model loads.

## Plan

- Persist `useConnectAddress` and `connectAddress` in settings.
- `ApiClientFactory` builds an `HttpClient.connectionFactory` that dials the override and
  secures the socket with the URI host.
- Thread the address through the settings test connection, model refresh, and chat
  streaming clients.
- Settings UI: switch, address field, validation, reset; test connection uses it.
- Tests: settings persistence/threading, chat client threading.

## Outcome

- Implemented in `0.2.0+2`; 47 tests pass.
- Verified on the emulator: override enabled with `192.168.2.240` → test connection
  returns all 6 models; the setting persists across restart.
- Release APK verified: `versionName 0.2.0`, `versionCode 2`.
- Important fix: when a `connectionFactory` is set, Dart does not TLS-wrap the socket.
  Returning a plain socket sent plaintext to port 443 and Traefik answered 404. The
  factory now awaits the TCP connection, calls `SecureSocket.secure(raw, host: uri.host)`,
  and returns it via `ConnectionTask.fromSocket`.
