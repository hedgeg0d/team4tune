import 'dart:io';

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

  testWidgets('client reconnects and resumes after a socket drop',
      (tester) async {
    final hostBox = ProviderContainer();
    final guestBox = ProviderContainer();
    addTearDown(hostBox.dispose);
    addTearDown(guestBox.dispose);
    final host = hostBox.read(roomControllerProvider.notifier);
    final guest = guestBox.read(roomControllerProvider.notifier);
    AppState g() => guestBox.read(roomControllerProvider);

    await host.createRoom(_itUrl, 'host', modeSignal);
    await _until(tester, () => hostBox.read(roomControllerProvider).room != null);
    final code = hostBox.read(roomControllerProvider).room!.roomCode;
    await guest.joinRoom(_itUrl, code, 'guest');
    await _until(tester, () => g().room != null);

    host.enqueue(_source);
    await _until(tester, () => g().playing, timeout: const Duration(seconds: 90));

    await guest.debugDrop();
    await _until(tester, () => g().reconnecting, timeout: const Duration(seconds: 10));
    await _until(tester, () => !g().reconnecting && g().room != null,
        timeout: const Duration(seconds: 30));
    await _until(tester, () => g().playing, timeout: const Duration(seconds: 60));

    final a = g().positionMs;
    await _wait(tester, const Duration(seconds: 3));
    expect(g().positionMs, greaterThan(a),
        reason: 'playback should keep advancing after resume');
  }, skip: _itUrl.isEmpty || _source.isEmpty);

  testWidgets('a slow client does not block the room and resyncs',
      (tester) async {
    final proxy = _ThrottleProxy(Uri.parse(_httpFromWs(_itUrl)));
    await proxy.start();
    addTearDown(proxy.stop);
    final slowUrl = _itUrl.replaceFirst(
        RegExp(r'//[^/]+'), '//127.0.0.1:${proxy.port}');

    final hostBox = ProviderContainer();
    final slowBox = ProviderContainer();
    addTearDown(hostBox.dispose);
    addTearDown(slowBox.dispose);
    final host = hostBox.read(roomControllerProvider.notifier)
      ..cacheDirForTest = Directory.systemTemp.createTempSync('host_cache');
    final slow = slowBox.read(roomControllerProvider.notifier)
      ..cacheDirForTest = Directory.systemTemp.createTempSync('slow_cache');
    AppState h() => hostBox.read(roomControllerProvider);
    AppState s() => slowBox.read(roomControllerProvider);

    await host.createRoom(_itUrl, 'host', modeSignal);
    await _until(tester, () => h().room != null);
    final code = h().room!.roomCode;
    await slow.joinRoom(slowUrl, code, 'slow');
    await _until(tester, () => s().room != null);

    host.enqueue(_source);

    await _until(tester, () => h().playing, timeout: const Duration(seconds: 30));
    expect(h().playing, isTrue,
        reason: 'room must start promptly even with a constrained client');

    await _until(tester, () => s().playing, timeout: const Duration(seconds: 120));
    await _wait(tester, const Duration(seconds: 3));
    final gap = (h().positionMs - s().positionMs).abs();
    expect(gap, lessThan(1500),
        reason: 'slow client should resync near live (gap=${gap}ms)');
  }, skip: _itUrl.isEmpty || _source.isEmpty);
}

String _httpFromWs(String ws) {
  final u = Uri.parse(ws);
  return 'http://${u.host}:${u.port}';
}

class _ThrottleProxy {
  _ThrottleProxy(this.target);

  final Uri target;
  late HttpServer _server;
  final _client = HttpClient();

  int get port => _server.port;

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen(_handle);
  }

  Future<void> _handle(HttpRequest req) async {
    if (WebSocketTransformer.isUpgradeRequest(req)) {
      final upstream =
          await WebSocket.connect('ws://${target.host}:${target.port}/ws');
      final ws = await WebSocketTransformer.upgrade(req);
      upstream.listen((d) => ws.add(d),
          onDone: () => ws.close(), onError: (_) => ws.close());
      ws.listen((d) => upstream.add(d),
          onDone: () => upstream.close(), onError: (_) => upstream.close());
      return;
    }
    try {
      final ureq = await _client.openUrl(
          req.method, target.replace(path: req.uri.path));
      final range = req.headers.value('range');
      if (range != null) ureq.headers.set('range', range);
      final uresp = await ureq.close();
      req.response.statusCode = uresp.statusCode;
      uresp.headers.forEach((k, v) {
        try {
          req.response.headers.set(k, v.join(','));
        } catch (_) {}
      });
      await for (final chunk in uresp) {
        for (var i = 0; i < chunk.length; i += 8192) {
          final end = (i + 8192) < chunk.length ? i + 8192 : chunk.length;
          req.response.add(chunk.sublist(i, end));
          await req.response.flush();
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      }
      await req.response.close();
    } catch (_) {
      try {
        await req.response.close();
      } catch (_) {}
    }
  }

  Future<void> stop() async {
    _client.close(force: true);
    await _server.close(force: true);
  }
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
