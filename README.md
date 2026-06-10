# team4tune-client

Flutter client for [team4tune](https://github.com/team4tune) — synchronized group music
listening. Anonymous and open source: no accounts, just a room code. **Android is the
product; Linux desktop is a dev/verification target** (audio runs through libmpv there
via `just_audio_media_kit`).

## Status

- M0 — connect to a node server, create/join a room, live member list, enqueue a
  track URL and watch the queue resolve.
- M2 — NTP-style clock sync (ping/pong, min-RTT offset estimator) with an
  offset/rtt debug strip in the room.
- M3 — signal-mode playback: `PlaybackService` downloads the prepared file, sends
  `ready`, and schedules start against `nowServerMs()` with `just_audio`; now-playing
  bar in the room.
- M4 (in progress) — drift correction: ~1s loop compares player position to the
  expected `s + (serverNow - t0)` and corrects (`>250ms` seek / `30–250ms` speed nudge /
  `<30ms` ignore); measured drift shown in the room debug chip.

## Run

Needs a running [`team4tune-node-server`](../team4tune-node-server).

```sh
flutter pub get
flutter run -d linux           # dev/verification on this machine
flutter run                    # Android device/emulator (the product)
```

On the home screen set the server URL:

- Linux desktop → `ws://127.0.0.1:8080/ws`
- Android emulator → `ws://10.0.2.2:8080/ws`
- Real device on LAN → `ws://<server-lan-ip>:8080/ws`

For the real-Android audio path, see [`scripts/waydroid.md`](scripts/waydroid.md).

## Test

```sh
flutter test
# live round-trip against a running server:
TEAM4TUNE_IT_URL=ws://127.0.0.1:8090/ws flutter test test/ws_integration_test.dart

# full e2e harness (boots the server, drives the Linux app, headless via xvfb):
scripts/verify.sh                              # connection + clock sync
TEAM4TUNE_IT_SOURCE=<media-url> scripts/verify.sh   # + enqueue and verify audio advances
```

## Layout

```
lib/main.dart                  app root, Home/Room switch
lib/src/protocol.dart          wire format (mirrors server docs/protocol.md)
lib/src/ws_client.dart         WebSocket connection + envelope stream
lib/src/clock_sync.dart        NTP-style offset/RTT estimator
lib/src/playback_service.dart  download on prepare, schedule start, drift correction
lib/src/room_controller.dart   Riverpod state: connection + room + clock + playback
lib/src/screens/               home + room UI
integration_test/             e2e tests driven by scripts/verify.sh
scripts/verify.sh             boot server + run the Linux app e2e (headless)
scripts/waydroid.md           real-Android verification path
```

## Roadmap

- M4 — drift correction (in progress), late join
- Later — stream mode, local-file upload
