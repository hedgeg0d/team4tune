import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:team4tune/src/playback_service.dart';
import 'package:team4tune/src/protocol.dart';
import 'package:team4tune/src/room_controller.dart';

const _itUrl = String.fromEnvironment('TEAM4TUNE_IT_URL');
const _source = String.fromEnvironment('TEAM4TUNE_IT_SOURCE');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  JustAudioMediaKit.ensureInitialized();

  testWidgets('create room and reach clock sync against live server',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final ctrl = container.read(roomControllerProvider.notifier);

    await ctrl.createRoom(_itUrl, 'it', modeSignal);
    await _until(tester, () => container.read(roomControllerProvider).room != null);
    expect(container.read(roomControllerProvider).room, isNotNull);

    await _until(
        tester, () => container.read(roomControllerProvider).clockOffsetMs != null);
    expect(container.read(roomControllerProvider).clockOffsetMs, isNotNull);
  }, skip: _itUrl.isEmpty);

  testWidgets('signal playback advances and holds sync', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final ctrl = container.read(roomControllerProvider.notifier);

    await ctrl.createRoom(_itUrl, 'it', modeSignal);
    await _until(tester, () => container.read(roomControllerProvider).room != null);

    ctrl.enqueue(_source);
    await _until(tester, () => container.read(roomControllerProvider).playing,
        timeout: const Duration(seconds: 90));

    final start = container.read(roomControllerProvider).positionMs;
    await _wait(tester, const Duration(seconds: 4));
    final later = container.read(roomControllerProvider).positionMs;

    expect(later, greaterThan(start));
    expect(container.read(roomControllerProvider).driftMs.abs(),
        lessThan(driftSeekThresholdMs));
  }, skip: _itUrl.isEmpty || _source.isEmpty);

  testWidgets('seek on a streaming track resumes near the new position',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final ctrl = container.read(roomControllerProvider.notifier);

    await ctrl.createRoom(_itUrl, 'it', modeSignal);
    await _until(tester, () => container.read(roomControllerProvider).room != null);

    ctrl.enqueue(_source);
    await _until(tester, () => container.read(roomControllerProvider).playing,
        timeout: const Duration(seconds: 90));
    await _wait(tester, const Duration(seconds: 3));

    ctrl.seek(180000);
    await _until(
        tester, () => container.read(roomControllerProvider).positionMs > 170000,
        timeout: const Duration(seconds: 60));

    final at = container.read(roomControllerProvider).positionMs;
    await _wait(tester, const Duration(seconds: 4));
    expect(container.read(roomControllerProvider).positionMs, greaterThan(at));
    expect(container.read(roomControllerProvider).driftMs.abs(),
        lessThan(driftSeekThresholdMs));
  }, skip: _itUrl.isEmpty || _source.isEmpty);
}

Future<void> _until(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('condition not met within $timeout');
    }
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
