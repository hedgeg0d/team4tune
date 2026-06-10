import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:team4tune/src/clock_sync.dart';
import 'package:team4tune/src/protocol.dart';
import 'package:team4tune/src/ws_client.dart';

void main() {
  final url = Platform.environment['TEAM4TUNE_IT_URL'];

  test('create room round-trip against live server', () async {
    if (url == null) {
      markTestSkipped('set TEAM4TUNE_IT_URL to run');
      return;
    }

    final client = await WsClient.connect(url);
    final first = client.stream.firstWhere((e) => e.type == typeRoomState);
    client.send(typeCreate, {'mode': modeSignal, 'nick': 'tester'});

    final env = await first.timeout(const Duration(seconds: 5));
    final state = RoomState.fromJson(env.data ?? const {});

    expect(state.roomCode, isNotEmpty);
    expect(state.members.length, 1);
    expect(state.selfId, isNotEmpty);

    await client.close();
  }, skip: url == null);

  test('clock sync produces an estimate against live server', () async {
    if (url == null) {
      markTestSkipped('set TEAM4TUNE_IT_URL to run');
      return;
    }

    final client = await WsClient.connect(url);
    final clock = ClockSync(client, interval: const Duration(milliseconds: 200));
    final first = clock.estimates.first;
    clock.start();

    final est = await first.timeout(const Duration(seconds: 5));
    expect(est.samples, greaterThanOrEqualTo(1));
    expect(est.rttMs, greaterThanOrEqualTo(0));
    expect(est.rttMs, lessThan(2000));

    await clock.stop();
    await client.close();
  }, skip: url == null);
}
