# UconnectA — Frontend (Flutter)

A Flutter mobile application for the **UconnectA** platform — a driver-to-driver communication app featuring real-time messaging, WebRTC voice calls, push notifications, license-plate-based user discovery, and photo recognition. Currently targeting **Android**; iOS support is structurally possible but not yet configured.

---

## Table of Contents

1. [Tech Stack & Key Dependencies](#tech-stack--key-dependencies)
2. [Project Structure](#project-structure)
3. [Architecture Overview](#architecture-overview)
4. [Screens & Pages](#screens--pages)
5. [Core Services](#core-services)
6. [Authentication Flow](#authentication-flow)
7. [Real-Time Messaging](#real-time-messaging)
8. [Voice Calls (WebRTC)](#voice-calls-webrtc)
9. [Push Notifications (FCM)](#push-notifications-fcm)
10. [Photo Recognition](#photo-recognition)
11. [Design System](#design-system)
12. [Assets](#assets)
13. [Android Permissions](#android-permissions)
14. [Local Development Setup](#local-development-setup)
15. [Building for Release](#building-for-release)

---

## Tech Stack & Key Dependencies

| Category | Package | Version |
|---|---|---|
| HTTP client | `dio` | ^5.4.0 |
| WebSockets | `web_socket_channel` | ^2.4.0 |
| Secure storage | `flutter_secure_storage` | ^9.0.0 |
| Shared prefs | `shared_preferences` | ^2.2.3 |
| Firebase core | `firebase_core` | ^2.30.0 |
| Push notifications | `firebase_messaging` | ^14.7.0 |
| Local notifications | `flutter_local_notifications` | ^17.1.0 |
| WebRTC | `flutter_webrtc` | ^1.3.1 |
| Audio playback | `just_audio` | ^0.9.36 |
| Ringtone player | `flutter_ringtone_player` | ^4.0.0 |
| Vibration | `vibration` | ^3.1.3 |
| Image picker | `image_picker` | ^1.1.2 |
| ZIP archiver | `archive` | ^3.6.1 |
| File paths | `path_provider` + `path` | ^2.1.4 / ^1.9.0 |
| SVG rendering | `flutter_svg` | ^2.2.3 |
| Launcher icons | `flutter_launcher_icons` | ^0.13.1 |

**Dart SDK:** `^3.10.1`  
**App version:** `1.0.0+1`  
**Backend URL:** `https://uconnecta-backend.onrender.com`

---

## Project Structure

```
frontend/
├── assets/
│   ├── fonts/              # InriaSans & Jura typefaces (Regular / Bold / Light)
│   ├── images/             # blank_avatar.png
│   ├── sounds/             # incoming_call.mp3
│   ├── svgs/               # UI icons (arrow_back, block, cam, home, menu, phone,
│   │                       #   profile, rating, search, settings, support, locker,
│   │                       #   instruction)
│   └── icon.png            # App launcher icon
├── android/
│   ├── app/
│   │   ├── build.gradle.kts        # Min SDK, Java 17, Google Services plugin
│   │   ├── google-services.json    # Firebase project configuration
│   │   └── src/main/
│   │       ├── AndroidManifest.xml # Permissions + activity config
│   │       └── kotlin/…/MainActivity.kt
│   └── build.gradle.kts
└── lib/
    ├── main.dart                   # Entry point: Firebase init, push navigation
    ├── app_services.dart           # Global service locator (static singletons)
    ├── auth/
    │   ├── api_client.dart         # Dio wrapper + JWT inject + auto-refresh interceptor
    │   ├── auth_gate.dart          # Boot router: auto-login / first-launch / sign-in
    │   ├── auth_service.dart       # login, register, logout, me, saveFcmToken
    │   ├── current_user.dart       # CurrentUser model (id, email, phone, cars, rating…)
    │   ├── token_storage.dart      # FlutterSecureStorage wrapper (access + refresh)
    │   ├── tokens.dart             # JwtTokens model
    │   └── user_scope.dart         # InheritedNotifier<UserStore> for the widget tree
    ├── data/
    │   ├── api.dart                # Endpoint constants + baseUrl
    │   ├── call_controller.dart    # Call state machine + navigation orchestration
    │   ├── call_service.dart       # WebRTC peer connection + WS signaling
    │   ├── call_sound_service.dart # Ringtone start / stop
    │   ├── call_vibration_services.dart  # Vibration patterns for calls
    │   ├── chat_api.dart           # Chat & message HTTP operations
    │   ├── chat_store.dart         # In-memory chat list (ChangeNotifier)
    │   ├── constrains.dart         # Misc constants
    │   ├── constrains_&_utils.dart # KColors, DriverProfile, ChatListItem,
    │   │                           # MessageItem, QuickMsg, snack-bar helpers
    │   ├── navigation_service.dart # Global NavigatorKey
    │   ├── notifiers.dart          # UserStore + signUpInTabsNotifier
    │   ├── pending_message_buffer.dart  # Optimistic message persistence
    │   ├── recognize_api.dart      # Photo → ZIP → recognition API
    │   └── user_ws_service.dart    # Per-user WebSocket with auto-reconnect
    ├── components/
    │   ├── chat_card.dart          # Chat list tile widget
    │   ├── country_dropdown.dart   # Country-code selector
    │   ├── input_field.dart        # Styled text input component
    │   ├── search_field.dart       # Search bar + live user result list
    │   └── sort_tab.dart           # Tab-based sort selector
    └── pages/
        ├── account_page.dart            # Profile viewing & editing, settings
        ├── call_in_progress_page.dart   # Active call UI (timer, mute, speaker, end)
        ├── call_page.dart               # Incoming call UI (accept / reject)
        ├── camera_page.dart             # Camera capture for photo recognition
        ├── chat_page.dart               # Full chat screen (WS + REST)
        ├── driver_profile_page.dart     # Another user's public profile
        ├── home_page.dart               # Main screen: chat list + drawer navigation
        ├── home_page_unregistered.dart  # Onboarding / landing for first-time visitors
        ├── outgoing_call_page.dart      # Ringing screen while waiting for answer
        └── sign_up_in_page.dart         # Tabbed login / registration screen
```

---

## Architecture Overview

The app follows a **service-locator** pattern without a heavy state management framework. All long-lived singletons live on the `AppServices` class and are accessible anywhere without `BuildContext`.

```
AppServices (static singletons)
├── TokenStorage          ← FlutterSecureStorage for JWT tokens
├── ApiClient             ← Dio + JWT interceptor + auto-refresh
├── AuthService           ← login / register / logout / me
├── ChatApi               ← all chat & message HTTP calls
├── ChatStore             ← ChangeNotifier, in-memory chat list
├── UserWsService         ← /ws/user/ WebSocket + auto-reconnect
├── CallService           ← WebRTC peer connection + /ws/calls/<id>/
├── CallController        ← call state machine (idle→incoming→ringing→inProgress)
├── CallSoundService      ← ringtone playback
└── CallVibrationService  ← vibration patterns
```

**Reactive state** is handled at two levels:

- `UserStore` (`ValueNotifier<CurrentUser?>`) is provided to the widget tree through `UserScope` (`InheritedNotifier`). Any widget that calls `UserScope.of(context)` rebuilds automatically when the current user changes.
- `ChatStore` (`ChangeNotifier`) holds the live chat list and notifies listeners on upsert / remove.
- `CallController` exposes a `ValueNotifier<CallState>` so call-related pages can react to state transitions without polling.

**Optimistic messaging** — when a user sends a message, a `PendingBufferEntry` is written to `SharedPreferences` immediately. The entry is displayed in the chat list at once and removed only when the server confirms delivery (or navigation away from the chat). This keeps the UI responsive on slow connections.

---

## Screens & Pages

### `AuthGate` (boot router)
Runs once on startup. Tries to auto-login using the stored refresh token and fetches `/api/me/` to populate `UserStore`. On the very first launch (checked via a `SharedPreferences` flag), it routes to `HomePageUnregistered` as an onboarding experience. Otherwise unauthenticated users land on `SignUpInPage`.

### `HomePageUnregistered`
Landing / onboarding screen shown exactly once before the user has an account. Explains the app and offers sign-in / register entry points.

### `SignUpInPage`
Tabbed screen with **Login** (email + password) and **Register** (email, phone, password, confirm, preferred form of address) tabs. Handles validation, error display, and post-login navigation to `HomePage`.

### `HomePage`
The main authenticated screen. Shows the list of chats (via `ChatStore`) with sorting options. Contains a navigation drawer linking to the account page, call history, blocked users, and settings. Tapping a chat opens `ChatPage`; tapping a user avatar opens `DriverProfilePage`.

### `ChatPage`
Full-featured chat screen. Opens a WebSocket connection to `/ws/chat/<chat_id>/` for real-time events. Features include:
- Send text messages and images (via `image_picker`)
- Edit and delete messages (for yourself or for everyone)
- Long-press context menu on messages
- Optimistic message display with pending states
- Auto-scroll to latest message
- Toggle auto-delete (24-hour disappearing chats)
- Quick-message templates (pre-written road-situation messages)
- Delete the entire chat for yourself or all participants

### `DriverProfilePage`
Public profile of another user. Shows username, display name, about text, profile photo, rating, car number(s), and allows starting a direct chat, initiating a call, blocking the user, or rating them.

### `AccountPage`
The current user's own profile and settings. Allows editing name, surname, patronymic, how-to-address, about text, and profile photo. Also manages car numbers (add / remove) and app settings (auto-delete, show nickname, allow calls).

### `CallPage` (incoming)
Shown when a `call.incoming` WebSocket event or FCM push arrives. Displays the caller's profile, plays the ringtone, and vibrates. Offers **Accept** and **Reject** buttons. Auto-dismisses after 35 seconds if unanswered (marks the call as missed).

### `OutgoingCallPage`
Shown immediately after initiating a call. Displays the callee's profile and a ringing animation. The WebRTC peer connection is already initialised at this point so the SDP handshake can proceed without delay once the callee accepts.

### `CallInProgressPage`
Active call UI. Shows the peer's profile, a live call timer (ticking via `CallController.callDurationListenable`), and controls for mute, toggle speaker, and end call.

### `CameraPage`
In-app camera screen. Captures a photo, compresses it into a ZIP archive, and sends it to the `/api/recognize-photo/` endpoint via `RecognizeApi`. Displays the recognition result.

---

## Core Services

### `ApiClient`
A `Dio`-based HTTP client configured with the backend base URL and three interceptors:

1. **Logger** — logs all requests and responses in debug mode.
2. **Auth injector** — attaches `Authorization: Bearer <access_token>` to every non-auth request.
3. **Auto-refresh** — on a `401` response it silently calls `/api/auth/refresh/` to obtain a new access token, then retries the original request. `FormData` requests are not retried (multipart uploads cannot be cloned). If the refresh fails, tokens are cleared.

Convenience wrappers: `get`, `post`, `patch`, `delete`, `postFormData`.

### `UserWsService`
Maintains a persistent WebSocket connection to `/ws/user/?token=<access_token>`. Automatically reconnects on unexpected disconnection using a linear back-off delay capped at 5 seconds (retry count resets on manual disconnect). Dispatches decoded JSON events to the registered `WsEventHandler`.

Events routed through `AppServices.userWsEventHandler`:
- `call.incoming` → `CallController.onIncomingCall`
- `call.accepted` → `CallController.onCallAccepted`
- `call.rejected` / `call.ended` → `CallController.onCallEnded`

### `CallController`
Implements the call lifecycle state machine:

```
idle ──▶ ringing (outgoing) ──▶ inProgress ──▶ idle
idle ──▶ incoming           ──▶ inProgress ──▶ idle
                            └──▶ idle (rejected / missed)
```

Responsibilities: creating the call via REST, navigating between call screens, starting/stopping the in-call timer, coordinating sound and vibration, and calling `CallService.endLocal()` on reset.

### `CallService`
Owns the `RTCPeerConnection` and the signaling WebSocket to `/ws/calls/<call_id>/`. Handles the full WebRTC handshake:

- **Caller path:** connects WS as caller → waits for `ready` from callee → sends `offer` → receives `answer` → exchanges ICE candidates.
- **Callee path:** connects WS → sends `ready` → receives `offer` → sends `answer` → exchanges ICE candidates.

ICE candidates that arrive before `setRemoteDescription` completes are buffered in `_pendingCandidates` and flushed immediately after the remote description is set.

STUN/TURN server list is fetched dynamically from `/api/webrtc/ice-servers/` at the start of each call, falling back to `stun.l.google.com:19302`.

Supports: mute (`setMuted`), toggle speakerphone (`setSpeaker`), clean teardown (`endLocal`).

### `ChatStore`
A `ChangeNotifier` backed by a `Map<String, ChatListItem>`. Supports `setChats` (bulk replace), `upsert` (add or update one chat), and `remove`. Used by `HomePage` to render the chat list reactively.

### `RecognizeApi`
Wraps the photo-recognition flow: compresses the source image into a ZIP file using `ZipFileEncoder` (run in an `Isolate` via `compute` to avoid blocking the UI), POSTs it as `multipart/form-data`, returns the decoded JSON, and deletes the temporary ZIP.

---

## Authentication Flow

```
App start
   │
   ▼
AuthGate._boot()
   ├─ readRefresh() token present?
   │     ├─ YES → GET /api/me/ → populate UserStore → connect UserWsService
   │     │         └─ save FCM token to server
   │     │         → navigate to HomePage
   │     └─ NO  → first launch? → HomePageUnregistered
   │                            → SignUpInPage
   │
SignUpInPage (Login tab)
   └─ POST /api/auth/login/ → store access + refresh tokens
      → AppServices.userWs.connect()
      → navigate to HomePage

SignUpInPage (Register tab)
   └─ POST /api/auth/register/ → switch to Login tab

Logout (AccountPage)
   └─ callController.reset()
      callService.endLocal()
      userWs.disconnect()
      chatStore.clear()
      tokenStorage.clear()
      → navigate to SignUpInPage
```

JWT tokens are stored in `flutter_secure_storage` (encrypted on-device). The access token is injected into every API call automatically. A transparent refresh cycle handles token expiry without user interaction.

---

## Real-Time Messaging

Each open `ChatPage` connects to `/ws/chat/<chat_id>/` and listens for three event types:

| WS Event | Action |
|---|---|
| `message.created` | Appends the new message to the list |
| `message.edited` | Replaces the message in-place |
| `message.deleted` | Removes the message from the list |

Sending a message follows an **optimistic update** pattern:
1. A `PendingBufferEntry` is written to `SharedPreferences` and displayed immediately with a "sending" indicator.
2. `ChatApi.sendTextMessage` POSTs to the REST endpoint.
3. On success, the confirmed `MessageItem` replaces the pending entry.
4. On failure, the pending entry is marked as failed and can be retried.

This approach keeps the chat UI snappy even on poor connections and survives navigating away and back.

---

## Voice Calls (WebRTC)

The app implements **audio-only** peer-to-peer calls using `flutter_webrtc`. Video tracks are explicitly disabled (`offerToReceiveVideo: false`). Audio constraints include echo cancellation, noise suppression, and auto gain control.

**Outgoing call sequence:**
1. User taps call button on `DriverProfilePage`.
2. `CallController.startOutgoingCall` POSTs to `/api/calls/create/` to get a `call_id`.
3. `OutgoingCallPage` is pushed immediately.
4. WebRTC peer + local audio + WS signaling channel are initialised in the background.
5. Caller waits for `ready` from callee over the WS.
6. Once `ready` is received, caller creates and sends an SDP `offer`.
7. Callee sends an SDP `answer`; both sides exchange ICE candidates.
8. On `call.accepted` WS event, `CallInProgressPage` replaces `OutgoingCallPage`.

**Incoming call sequence:**
1. `call.incoming` arrives via `UserWsService` (or FCM when app is backgrounded).
2. `CallController.onIncomingCall` navigates to `CallPage`, starts ringtone and vibration.
3. User taps **Accept** → `CallController.accept` initialises WebRTC, connects WS (as callee), sends `ready`.
4. After handshake, `CallInProgressPage` is pushed.
5. Unanswered calls auto-reject after 35 seconds.

**In-call controls:** mute microphone, toggle between earpiece and speakerphone, hang up (sends `hangup` over WS + calls `/api/calls/<id>/end/`).

---

## Push Notifications (FCM)

Firebase Messaging is initialised in `main()`. The app handles three scenarios:

| Scenario | Handler |
|---|---|
| App in foreground | `UserWsService` delivers events directly |
| App in background, user taps notification | `FirebaseMessaging.onMessageOpenedApp` → `handlePushNavigation` |
| App terminated, user taps notification | `getInitialMessage()` → `handlePushNavigation` |
| App in background (no user tap) | `_firebaseMessagingBackgroundHandler` (isolate) |

`handlePushNavigation` inspects `data['type']` and routes to the appropriate screen:
- `call.incoming` → `CallPage`
- `message.created` → `ChatPage` (skipped if that chat is already open)

The FCM device token is saved to the backend (`/api/me/fcm/`) after every successful login or auto-login.

---

## Photo Recognition

Users can open `CameraPage` to capture a photo (car licence plate, etc.) and submit it for recognition. The flow:

1. Camera preview via `image_picker`.
2. `RecognizeApi.recognizePhoto(file)` runs `ZipFileEncoder` in a background `Isolate` to avoid UI jank.
3. The ZIP is POSTed as `multipart/form-data` to `/api/recognize-photo/`.
4. The backend proxies the image to an external OCR/recognition service.
5. The JSON result is displayed on-screen. The temporary ZIP is always deleted in `finally`.

---

## Design System

Colours are defined in `KColors` (from `data/constrains_&_utils.dart`):

| Token | Hex | Usage |
|---|---|---|
| `mainColor` | `#5E81AC` | Primary brand colour, buttons, accents |
| `secondaryColor` | `#88C0D0` | Secondary accents, gradients |
| `thirdColor` | `#BBDEFB` | Highlights, chips |
| `backgroundColor` | `#506A8B` | Drawer, overlays |
| `lightBackgroundColor` | `#ECF4` | Page backgrounds |
| `goodColor` | `#00D207` | Success states, high ratings |
| `mediumColor` | `#D1A700` | Medium rating |
| `badColor` | `#FF6262` | Errors, low ratings |
| `placeholderColor` | `#CFCFCF` | Input placeholder text |

A `mainGradient` (`LinearGradient`) transitions from `mainColor` through to `secondaryColor` at 90°.

The global `ThemeData` sets `InriaSans` as the default `fontFamily`. Components that use a display/heading typeface switch to `Jura`.

---

## Assets

| Path | Contents |
|---|---|
| `assets/fonts/` | InriaSans (Regular/Bold/Light) + Jura (Regular/Bold/Light) |
| `assets/images/blank_avatar.png` | Default avatar placeholder |
| `assets/sounds/incoming_call.mp3` | Ringtone for incoming calls |
| `assets/svgs/` | 13 SVG icons used throughout the UI |
| `assets/icon.png` | Source image for the Android launcher icon |

The launcher icon is generated by `flutter_launcher_icons` for Android (min SDK 21).

---

## Android Permissions

Declared in `AndroidManifest.xml`:

| Permission | Purpose |
|---|---|
| `INTERNET` | All network communication |
| `CAMERA` | Photo capture (CameraPage, photo recognition) |
| `POST_NOTIFICATIONS` | FCM push notifications (Android 13+) |
| `RECORD_AUDIO` | Microphone access for WebRTC voice calls |
| `ACCESS_NETWORK_STATE` | Network connectivity checks |
| `CHANGE_NETWORK_STATE` | WebRTC network handling |
| `MODIFY_AUDIO_SETTINGS` | Earpiece / speakerphone switching |
| `BLUETOOTH` / `BLUETOOTH_CONNECT` | Audio routing to Bluetooth headsets |

---

## Local Development Setup

**Prerequisites:** Flutter SDK (Dart ^3.10.1), Android Studio / VS Code with Flutter extension, Android emulator or physical device.

```bash
# 1. Clone the repository
git clone <repo-url>
cd frontend

# 2. Install Flutter dependencies
flutter pub get

# 3. Add google-services.json
# Place your Firebase project's google-services.json at:
#   android/app/google-services.json

# 4. (Optional) Regenerate the launcher icon after changing assets/icon.png
flutter pub run flutter_launcher_icons

# 5. Run on a connected device / emulator
flutter run

# For a specific device:
flutter run -d <device-id>
```

The app connects to `https://uconnecta-backend.onrender.com` by default. To point at a local backend, change `Api.baseUrl` in `lib/data/api.dart`:

```dart
// lib/data/api.dart
class Api {
  static const String baseUrl = "http://10.0.2.2:8000"; // Android emulator
  // static const String baseUrl = "http://192.168.x.x:8000"; // Physical device
  ...
}
```

> Note: the WebSocket scheme (`ws` / `wss`) is derived automatically from the `baseUrl` scheme in both `UserWsService` and `CallService`.

---

## Building for Release

```bash
# 1. Set up a signing key (first time only)
keytool -genkey -v -keystore android/app/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload

# 2. Create android/key.properties
#   storePassword=<password>
#   keyPassword=<password>
#   keyAlias=upload
#   storeFile=upload-keystore.jks

# 3. Update android/app/build.gradle.kts to use key.properties
#   (replace the debug signingConfig in the release block)

# 4. Build the release APK
flutter build apk --release

# Or an App Bundle for Google Play
flutter build appbundle --release
```

Output paths:
- APK: `build/app/outputs/flutter-apk/app-release.apk`
- Bundle: `build/app/outputs/bundle/release/app-release.aab`