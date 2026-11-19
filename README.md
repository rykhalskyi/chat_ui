# Chat UI

A small Flutter chat client for LiteLLM and other OpenAI-compatible endpoints.
It streams replies, keeps conversation history locally, lets you switch models, and
shows model reasoning when one provides it. A switchable LAN IP override keeps TLS
hostname validation while bypassing phone DNS for a homelab endpoint.

Version: `0.2.0`.

## Tech stack

- **Flutter / Dart** (Material 3 via `material_ui`)
- **`http`** with SSE streaming and cancellable requests
- **`provider`** for state and dependency injection
- **`sqflite`** for local conversation/message history
- **`gpt_markdown`** for streaming Markdown
- **`shared_preferences`** + **`flutter_secure_storage`** for settings and the API key
- **`package_info_plus`** for the app version
- Android-first (app id `com.otakeessen.chatui`)

## Configure

Open **Settings** and set the OpenAI-compatible base URL (for example
`https://llm.lan.otakeessen.com/v1`) and the API key. If the phone cannot resolve the
LAN hostname, enable **LAN access → Use LAN IP override** and enter the server IP
(for example `192.168.2.240`). Turn the switch off for endpoints that use normal DNS.

## Run

```bash
flutter pub get
flutter run
flutter test
flutter build apk --release
```

Project notes and design docs live in [`wiki/index.md`](wiki/index.md).

## License

MIT — see [LICENSE](LICENSE).
