# Moving to a hosted, remote backend

Today the app talks to `agent-ui/backend` on the local network over plain HTTP, signing in with the access token from `run_ui.ps1`. Later the agents may run as a deployed API reachable from anywhere over HTTPS. This page lists what changes when that happens. **None of it is built yet.**

The app was structured so that this is mostly one new class plus configuration:

- Widgets and controllers use only the `AgentBackend` interface ([lib/data/backend/agent_backend.dart](../lib/data/backend/agent_backend.dart)), never URLs or a transport.
- `backendFactoryProvider` ([lib/domain/session_controller.dart](../lib/domain/session_controller.dart)) is the single place that picks an implementation, based on the profile's `authKind`.
- Saved servers are a list of `ConnectionProfile`s, so a cloud profile can sit next to a LAN one. Credentials are stored separately in secure storage, keyed by profile id.

## 1. A new `RemoteAgentBackend`

Add `lib/data/backend/remote_agent_backend.dart`, implementing `AgentBackend`:

- Same methods and the same return types: `Agent`, `Conversation`, `ConversationDetail` and `StreamEvent`. Map the hosted API's payloads onto these models inside the class, so nothing above it changes.
- Throw the same errors (`UnauthorizedException`, `UnreachableException`, `ServerException`). The 401 sign-out, the banners and the pairing messages then keep working.
- Make `logoUrl()` and `authHeaders` return whatever the hosted API needs for images. That might be a signed URL with empty headers.
- In `backendFactoryProvider`, add a case for the new auth kind.

## 2. HTTPS only

When no LAN profile is left, remove the plain-HTTP exemptions:

- Android: delete `android/app/src/main/res/xml/network_security_config.xml` and the `android:networkSecurityConfig` attribute in `AndroidManifest.xml`. Android then blocks cleartext by default.
- iOS: remove `NSAppTransportSecurity` / `NSAllowsLocalNetworking` and `NSLocalNetworkUsageDescription` from `ios/Runner/Info.plist`.
- `parseServerAddress()` should reject `http://` for remote profiles.
- Consider certificate pinning for the hosted domain.

If LAN mode must keep working alongside the cloud, keep the exemptions and require `https` only for the new profile kind.

## 3. A new sign-in flow

- Add an `AuthKind` value, for example `apiKey` or `oauth`, in [connection_profile.dart](../lib/data/models/connection_profile.dart). Older app versions skip unknown kinds instead of crashing.
- **API key:** a pairing screen variant that asks for the key and stores it like the LAN token.
- **OAuth / OIDC:** sign in through the system browser with PKCE (for example `flutter_appauth`). Store the refresh token in secure storage, and refresh the access token inside `RemoteAgentBackend` before it throws `UnauthorizedException`.
- Pairing then gains a choice between "This computer (same Wi-Fi)" and "Cloud".

## 4. Optional WebSocket transport

SSE over HTTPS works through most proxies and is enough for one-way streaming. A WebSocket only helps if the hosted API needs two-way traffic on one connection (approvals, stop, resuming a turn).

- Keep it inside `RemoteAgentBackend`: `sendMessage()` still returns `Stream<StreamEvent>`, while `approve()` and `stop()` send on the socket.
- Reuse `StreamEvent.tryFromJson`, so unknown events are still ignored.
- Add reconnection with backoff. If the server supports it, **resume** a turn by id after reconnecting. That would fix today's biggest limitation: a turn dies when the phone's connection drops.

## 5. Push notifications for pending approvals

On a phone, an approval prompt is easy to miss while the app is in the background. The hosted service should:

- Register each device's push token (FCM on Android, APNs on iOS) against the user.
- Send a push when a turn emits `approval_required`. Include the conversation id and the tool's warning, never the arguments.
- When the app opens from the notification, open that conversation and show the approval card. Notification actions could approve or deny directly, but require the device to be unlocked for that.
- The server must keep the turn alive while it waits for an approval, even with no client connected. Today the backend ends a turn when the client disconnects.

## What doesn't change

The UI, the chat-turn controller, `toBlocks()`, the activity groups, the Markdown rendering, the theme and every widget test. The fake-backend tests keep working, because they also go through `AgentBackend`.
