# Agent UI for Android and iOS

A native Flutter app for the agents in this repo. It does everything the web app in [../frontend](../frontend) does: pick an agent, chat with it, watch its tool calls live, approve or deny dangerous tools, and browse, rename and delete chats. It talks to the same FastAPI backend in [../backend](../backend), which needs no changes.

Today the phone and the computer must be on the **same Wi-Fi** (or both on Tailscale). Traffic is plain HTTP to the computer's local address.

## Prerequisites

- Flutter 3.47 or newer (Dart 3.13). Check with `flutter --version`.
- For Android: Android Studio or the Android SDK, and a phone with USB debugging on, or an emulator.
- For iOS: a Mac with Xcode. iOS can't be built on Windows.
- The computer running the agents, set up as described in [../README.md](../README.md), with Ollama running.

## Run it

1. On the computer, start the UI with phone access (it's on by default):

   ```powershell
   .\run_ui.ps1          # phones use port 5173 (dev mode)
   .\run_ui.ps1 -Prod    # phones use port 8000
   ```

   The terminal prints a sign-in link and a QR code.

2. Get the packages and run the app on a connected phone:

   ```powershell
   cd agent-ui\mobile
   flutter pub get
   flutter devices              # find your phone's id
   flutter run -d <device-id>
   ```

   For an installable build, use `flutter build apk --release` (Android) or open `ios/Runner.xcworkspace` in Xcode (iOS).

## Pair the phone

The first time the app opens, it asks you to connect to the computer.

- **Scan:** tap **Scan QR code** and point the camera at the QR code in the terminal, or at the one under **Use on your phone** at the bottom of the web app's sidebar.
- **By hand:** type the address and port from the terminal (for example `192.168.1.20:8000`) and paste the access token from `agent-ui/backend/data/remote_token.txt`. You can also paste the whole sign-in link into the address field.

The app checks the token before saving it. The token is kept in the Android Keystore or iOS Keychain, so next time the app opens straight to your chats. To sign out, open **Settings** from the bottom of the chat list and tap **Disconnect** (keeps the address) or **Forget this server**.

If someone deletes `remote_token.txt` to sign out every device, the app notices on its next request and asks you to pair again.

## Tests

Everything below runs without a server unless noted.

```powershell
flutter analyze                     # must report no issues
flutter test                        # unit, widget and happy-path tests (no device needed)
flutter test --coverage             # writes coverage/lcov.info
```

On a phone or emulator:

```powershell
flutter test integration_test/app_test.dart           # full happy path against a fake backend
flutter test integration_test/device_smoke_test.dart  # secure storage, wakelock, streaming on the device
```

Optional checks against a real running backend are skipped unless you pass its address and token. Use the computer's **LAN address**, not `localhost`: the backend trusts its own machine without a token, so `localhost` wouldn't test sign-in.

```powershell
# API only (no device):
flutter test test/live_smoke_test.dart `
  --dart-define=LIVE_BASE_URL=http://192.168.1.20:8000 --dart-define=LIVE_TOKEN=<token>

# Full UI on a device, with Ollama answering for real:
flutter test integration_test/live_e2e_test.dart -d <device-id> `
  --dart-define=LIVE_BASE_URL=http://192.168.1.20:8000 --dart-define=LIVE_TOKEN=<token>
```

The live UI test triggers the notes agent's `delete_all_notes` approval and always taps **Deny**, so nothing is deleted. It deletes the chats it creates.

## Troubleshooting

**"Timed out reaching…" or "Nothing is answering at…"**
- Check that `run_ui.ps1` is running and that you used the port it printed: 5173 in dev mode, 8000 with `-Prod`.
- Windows Firewall blocks incoming connections by default. `run_ui.ps1` adds a rule for its port the first time, which needs an admin prompt. If you declined it, run the `New-NetFirewallRule` command it printed, in an admin PowerShell. Other ports (for example a custom `-Port`) need their own rule.
- The rule only applies to **Private** networks. In Windows Settings → Network & internet → Wi-Fi → your network, set the profile to **Private**. On a network set to **Public**, the phone can't connect.

**"Can't reach… Your phone is probably not on the same Wi-Fi"**
- Connect the phone to the same Wi-Fi as the computer. Guest networks often block devices from seeing each other.
- Away from home, install [Tailscale](https://tailscale.com) on both, and use the computer's `100.x.y.z` address.

**iOS: nothing connects**
- The first time the app connects, iOS asks to **find and connect to devices on your local network**. Tap **Allow**. If you tapped Don't Allow, turn it on in Settings → Privacy & Security → Local Network → Agent UI.

**The QR scanner shows a black screen**
- Allow camera access in the phone's settings, or tap **Enter it by hand**.

**A reply stopped when I switched apps**
- The backend stops a turn when its connection drops, which can happen while the app is in the background. When you return, the app reloads the chat from the computer and says the reply was interrupted. Send the message again. The screen stays on while a reply streams in, to make this less likely.

## How it's built

```
lib/
  core/       theme tokens, constants, errors, SSE and QR-link parsers
  data/       models, the AgentBackend interface, LanAgentBackend, storage
  domain/     session, agents, conversations and chat-turn controllers, toBlocks()
  features/   pairing/, chat/, conversations/, settings/
```

- State is managed with Riverpod and navigation with go_router. Networking uses `package:http`, with SSE parsed incrementally from a streamed response.
- Widgets and controllers depend only on the `AgentBackend` interface. `LanAgentBackend` is today's implementation, sending the token as `Authorization: Bearer` on every request (the app never uses the cookie or `GET /api/login` sign-in).
- Markdown is rendered by [`gpt_markdown`](https://pub.dev/packages/gpt_markdown), which handles tables, highlighted code blocks with a copy button, and LaTeX.
- Colours live in one file, [lib/core/theme/tokens.dart](lib/core/theme/tokens.dart), for light and dark. A test checks that text contrast is at least 4.5:1.

Android allows plain HTTP app-wide ([network_security_config.xml](android/app/src/main/res/xml/network_security_config.xml)), because the computer's local IP address can be anything. iOS allows it for local addresses only (`NSAllowsLocalNetworking`). Both are marked for removal once the app moves to a hosted HTTPS backend: see [docs/FUTURE_REMOTE.md](docs/FUTURE_REMOTE.md).

## Known limitations

- A reply is lost if the app is killed or loses its connection mid-turn, because the backend ends the turn when the connection drops. The app reloads the saved chat and tells you, but it can't resume the turn.
- An approval prompt is only noticed while the app is open. There are no push notifications yet.
- iOS builds and the iOS local-network prompt have not been tested yet; they need a Mac.
