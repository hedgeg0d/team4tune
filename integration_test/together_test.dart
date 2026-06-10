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

  testWidgets('two clients in one room play in sync', (tester) async {
    final hostBox = ProviderContainer();
    final guestBox = ProviderContainer();
    addTearDown(hostBox.dispose);
    addTearDown(guestBox.dispose);

    final host = hostBox.read(roomControllerProvider.notifier);
    final guest = guestBox.read(roomControllerProvider.notifier);

    await host.createRoom(_itUrl, 'host', modeSignal);
    await _until(tester, () => hostBox.read(roomControllerProvider).room != null);
    final code = hostBox.read(roomControllerProvider).room!.roomCode;
    expect(code, isNotEmpty);

    await guest.joinRoom(_itUrl, code, 'guest');
    await _until(
        tester, () => guestBox.read(roomControllerProvider).room != null);
    await _until(
        tester,
        () =>
            hostBox.read(roomControllerProvider).room!.members.length == 2 &&
            guestBox.read(roomControllerProvider).room!.members.length == 2);

    host.enqueue(_source);

    await _until(
        tester,
        () =>
            hostBox.read(roomControllerProvider).playing &&
            guestBox.read(roomControllerProvider).playing,
        timeout: const Duration(seconds: 90));

    await _wait(tester, const Duration(seconds: 5));

    final posHost = hostBox.read(roomControllerProvider).positionMs;
    final posGuest = guestBox.read(roomControllerProvider).positionMs;
    final gap = (posHost - posGuest).abs();

    expect(posHost, greaterThan(0));
    expect(posGuest, greaterThan(0));
    expect(gap, lessThan(250),
        reason: 'host=$posHost guest=$posGuest gap=${gap}ms');
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
