import 'package:flutter_test/flutter_test.dart';

import 'package:team4tune/src/clock_sync.dart';

void main() {
  test('offset and rtt from symmetric path', () {
    final s = ClockSample.fromTimestamps(1000, 1100, 1100, 1200);
    expect(s.offsetMs, 0);
    expect(s.rttMs, 200);
  });

  test('positive offset when server clock ahead', () {
    final s = ClockSample.fromTimestamps(0, 150, 150, 100);
    expect(s.offsetMs, 100);
    expect(s.rttMs, 100);
  });

  test('rtt clamped to zero', () {
    final s = ClockSample.fromTimestamps(0, 50, 80, 10);
    expect(s.rttMs, 0);
  });

  test('model anchors offset on the lowest-rtt sample', () {
    final w = [
      const ClockSample(1000, 480, 90),
      const ClockSample(1100, 500, 12),
      const ClockSample(1200, 520, 80),
    ];
    final m = ClockModel.fit(w)!;
    expect(m.offsetAt(1100).round(), 500);
    expect(m.minRtt, 12);
  });

  test('no skew applied on a short baseline', () {
    final w = [
      for (var i = 0; i < 8; i++) ClockSample(i * 200, 100 + i * 10, 30),
    ];
    final m = ClockModel.fit(w)!;
    expect(m.slope, 0.0);
  });

  test('skew is clamped conservatively on a long baseline', () {
    final w = [
      for (var i = 0; i < 8; i++) ClockSample(i * 2000, 100 + i * 50, 30),
    ];
    final m = ClockModel.fit(w)!;
    expect(m.slope.abs(), lessThanOrEqualTo(0.0002));
    expect(m.slope, greaterThan(0));
  });

  test('model rejects a high-rtt outlier', () {
    final w = [
      for (var i = 0; i < 6; i++) ClockSample(i * 100, 500, 30),
      const ClockSample(600, 5000, 4000),
    ];
    final m = ClockModel.fit(w)!;
    expect(m.offsetAt(300).round(), closeTo(500, 5));
  });
}
