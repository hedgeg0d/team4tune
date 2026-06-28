# team4tune

Synchronized group music listening — Android app.

Create a room, share the code, queue tracks (URL or local file), and everyone hears the same thing at the same time. Audio sync is achieved through NTP-style clock agreement between every device and the server.

No accounts, no PII, no analytics. Rooms are ephemeral.

Two playback modes:
- **signal** — each device downloads the track and plays locally, synced via NTP-style clock (<50 ms target).
- **stream** — the server broadcasts live audio over WebRTC to all clients (no clock sync needed, works with any source).

## Quick start

Needs a running [team4tune-node-server](https://github.com/hedgeg0d/team4tune-node).

```sh
flutter pub get
flutter run                    # Android device/emulator
flutter run -d linux           # Linux desktop (dev/verification)
```

Set the server URL on the home screen:
- Linux desktop → `ws://127.0.0.1:8080/ws`
- Android emulator → `ws://10.0.2.2:8080/ws`
- Real device on LAN → `ws://<server-lan-ip>:8080/ws`

To prefill the server at build time:

```sh
flutter build apk --dart-define=TEAM4TUNE_SERVER=ws://hedgegod.tech:8080/ws
```

## Test

```sh
flutter test
# live round-trip against a running server:
TEAM4TUNE_IT_URL=ws://127.0.0.1:8090/ws flutter test test/ws_integration_test.dart
```

## Layout

```
lib/main.dart                  app root, screen routing
lib/src/protocol.dart          wire format
lib/src/ws_client.dart         WebSocket connection
lib/src/clock_sync.dart        NTP-style offset/RTT estimator
lib/src/playback_service.dart  download, schedule, drift correction
lib/src/room_controller.dart   Riverpod state: connection + room + clock
lib/src/screens/               home and room UI
lib/src/stream_service.dart    WebRTC stream mode client
```
