import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:team4tune/src/protocol.dart';
import 'package:team4tune/src/room_controller.dart';

const _itUrl = String.fromEnvironment('TEAM4TUNE_IT_URL');
const _source = String.fromEnvironment('TEAM4TUNE_IT_SOURCE');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  JustAudioMediaKit.ensureInitialized();

  testWidgets('host controls playback and permissions for the room',
      (tester) async {
    final hostBox = ProviderContainer();
    final guestBox = ProviderContainer();
    addTearDown(hostBox.dispose);
    addTearDown(guestBox.dispose);
    final host = hostBox.read(roomControllerProvider.notifier);
    final guest = guestBox.read(roomControllerProvider.notifier);

    RoomState hostRoom() => hostBox.read(roomControllerProvider).room!;
    RoomState guestRoom() => guestBox.read(roomControllerProvider).room!;

    await host.createRoom(_itUrl, 'host', modeSignal);
    await _until(tester, () => hostBox.read(roomControllerProvider).room != null);
    expect(hostRoom().isSelfHost, isTrue);

    await guest.joinRoom(_itUrl, hostRoom().roomCode, 'guest');
    await _until(tester, () => guestBox.read(roomControllerProvider).room != null);
    expect(guestRoom().isSelfHost, isFalse);

    host.enqueue(_source);
    await _until(
        tester,
        () =>
            hostBox.read(roomControllerProvider).playing &&
            guestBox.read(roomControllerProvider).playing,
        timeout: const Duration(seconds: 90));

    host.pause();
    await _until(
        tester,
        () =>
            !hostBox.read(roomControllerProvider).playing &&
            !guestBox.read(roomControllerProvider).playing);

    host.resume();
    await _until(
        tester,
        () =>
            hostBox.read(roomControllerProvider).playing &&
            guestBox.read(roomControllerProvider).playing);

    host.setSettings(const RoomSettings(enqueue: policyHost));
    await _until(tester, () => guestRoom().settings.enqueue == policyHost);

    final before = guestRoom().queue.length;
    guest.enqueue(_source);
    await _wait(tester, const Duration(seconds: 3));
    expect(guestRoom().queue.length, before,
        reason: 'locked enqueue from guest must not change the queue');

    host.skip();
    await _until(tester, () => hostRoom().queue.isEmpty,
        timeout: const Duration(seconds: 30));
  }, skip: _itUrl.isEmpty || _source.isEmpty);
}

Future<void> _until(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('condition not met within $timeout');
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
  }
}

Future<void> _wait(WidgetTester tester, Duration d) async {
  final deadline = DateTime.now().add(d);
  while (DateTime.now().isBefore(deadline)) {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
  }
}
