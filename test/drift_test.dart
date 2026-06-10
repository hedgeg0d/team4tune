import 'package:flutter_test/flutter_test.dart';
import 'package:team4tune/src/playback_service.dart';

void main() {
  group('driftActionFor', () {
    test('ignores drift inside the deadband', () {
      expect(driftActionFor(0).kind, DriftKind.ignore);
      expect(driftActionFor(34).kind, DriftKind.ignore);
      expect(driftActionFor(-34).kind, DriftKind.ignore);
    });

    test('nudges within the correction band', () {
      expect(driftActionFor(35).kind, DriftKind.nudge);
      expect(driftActionFor(150).kind, DriftKind.nudge);
      expect(driftActionFor(-350).kind, DriftKind.nudge);
      expect(driftActionFor(799).kind, DriftKind.nudge);
    });

    test('a steady output-latency offset corrects without seeking', () {
      expect(driftActionFor(-350).kind, DriftKind.nudge);
      expect(driftActionFor(-110).kind, DriftKind.nudge);
    });

    test('nudge is gentle and bounded', () {
      for (final d in [35, 100, 200, 350, 799, -200, -350, -799]) {
        expect(
          (driftActionFor(d).speed - 1.0).abs(),
          lessThanOrEqualTo(0.0601),
        );
      }
    });

    test('nudge slows down when ahead and speeds up when behind', () {
      expect(driftActionFor(200).speed, lessThan(1.0));
      expect(driftActionFor(-200).speed, greaterThan(1.0));
    });

    test('seeks only beyond the catastrophic threshold', () {
      expect(driftActionFor(800).kind, DriftKind.seek);
      expect(driftActionFor(-800).kind, DriftKind.seek);
      expect(driftActionFor(5000).kind, DriftKind.seek);
    });
  });
}
