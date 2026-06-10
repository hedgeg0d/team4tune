import 'package:flutter_test/flutter_test.dart';
import 'package:team4tune/src/protocol.dart';

void main() {
  group('RoomSettings', () {
    test('defaults to everyone for every scope', () {
      const s = RoomSettings();
      expect(s.policyFor(scopeEnqueue), policyEveryone);
      expect(s.policyFor(scopeSkip), policyEveryone);
      expect(s.policyFor(scopeRemove), policyEveryone);
      expect(s.policyFor(scopeControl), policyEveryone);
    });

    test('json round-trip preserves policies', () {
      const s = RoomSettings(
        enqueue: policyHost,
        skip: policyEveryone,
        remove: policyHost,
        control: policyEveryone,
      );
      final back = RoomSettings.fromJson(s.toJson());
      expect(back.enqueue, policyHost);
      expect(back.skip, policyEveryone);
      expect(back.remove, policyHost);
      expect(back.control, policyEveryone);
    });

    test('fromJson(null) yields all-everyone defaults', () {
      final s = RoomSettings.fromJson(null);
      expect(s.policyFor(scopeControl), policyEveryone);
    });
  });

  group('RoomState', () {
    test('parses hostId + settings and derives isSelfHost', () {
      final rs = RoomState.fromJson({
        'roomCode': 'ABCDEF',
        'mode': modeSignal,
        'selfId': 'me',
        'hostId': 'me',
        'settings': {'enqueue': policyHost},
        'members': [],
        'queue': [],
      });
      expect(rs.isSelfHost, isTrue);
      expect(rs.settings.enqueue, policyHost);
      expect(rs.settings.skip, policyEveryone);
    });

    test('isSelfHost false when host differs', () {
      final rs = RoomState.fromJson({
        'roomCode': 'ABCDEF',
        'selfId': 'me',
        'hostId': 'someone',
        'members': [],
        'queue': [],
      });
      expect(rs.isSelfHost, isFalse);
    });
  });
}
