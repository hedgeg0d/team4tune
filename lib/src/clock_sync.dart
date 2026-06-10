import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'protocol.dart';
import 'ws_client.dart';

class ClockSample {
  const ClockSample(this.localMs, this.offsetMs, this.rttMs);

  final int localMs;
  final int offsetMs;
  final int rttMs;

  static ClockSample fromTimestamps(int t0, int t1, int t2, int t3) {
    final offset = ((t1 - t0) + (t2 - t3)) ~/ 2;
    final rtt = (t3 - t0) - (t2 - t1);
    final local = (t0 + t3) ~/ 2;
    return ClockSample(local, offset, rtt < 0 ? 0 : rtt);
  }
}

class ClockEstimate {
  const ClockEstimate(this.offsetMs, this.rttMs, this.samples, this.skewPpm);

  final int offsetMs;
  final int rttMs;
  final int samples;
  final int skewPpm;
}

class ClockModel {
  const ClockModel(this.refMs, this.offsetAtRef, this.slope, this.minRtt, this.kept);

  final int refMs;
  final double offsetAtRef;
  final double slope;
  final int minRtt;
  final int kept;

  double offsetAt(int localMs) => offsetAtRef + slope * (localMs - refMs);

  static ClockModel? fit(List<ClockSample> window) {
    if (window.isEmpty) return null;
    final rtts = window.map((s) => s.rttMs).toList()..sort();
    final median = rtts[rtts.length ~/ 2];
    final cutoff = median * 3 ~/ 2 + 1;
    var kept = window.where((s) => s.rttMs <= cutoff).toList();
    if (kept.length < 2) kept = window;

    var anchor = kept.first;
    for (final s in kept) {
      if (s.rttMs < anchor.rttMs) anchor = s;
    }

    var slope = 0.0;
    final span = kept.last.localMs - kept.first.localMs;
    if (kept.length >= 6 && span >= 8000) {
      final ref = kept.first.localMs;
      var sx = 0.0, sy = 0.0, sxx = 0.0, sxy = 0.0;
      final n = kept.length;
      for (final s in kept) {
        final x = (s.localMs - ref).toDouble();
        final y = s.offsetMs.toDouble();
        sx += x;
        sy += y;
        sxx += x * x;
        sxy += x * y;
      }
      final denom = n * sxx - sx * sx;
      if (denom.abs() > 1e-6) {
        slope = ((n * sxy - sx * sy) / denom).clamp(-0.0002, 0.0002);
      }
    }
    return ClockModel(
        anchor.localMs, anchor.offsetMs.toDouble(), slope, anchor.rttMs, kept.length);
  }
}

class ClockSync {
  ClockSync(
    this._client, {
    this.windowSize = 20,
    this.interval = const Duration(seconds: 1),
    this.burstInterval = const Duration(milliseconds: 250),
    this.burstCount = 8,
  });

  final WsClient _client;
  final int windowSize;
  final Duration interval;
  final Duration burstInterval;
  final int burstCount;

  final List<ClockSample> _window = [];
  Timer? _timer;
  StreamSubscription<Envelope>? _sub;
  int _pingsSent = 0;

  RawDatagramSocket? _udp;
  InternetAddress? _udpTarget;
  int _udpPort = 0;
  bool _udpConfirmed = false;

  bool get usingUdp => _udpConfirmed;

  final _estimates = StreamController<ClockEstimate>.broadcast();
  Stream<ClockEstimate> get estimates => _estimates.stream;

  ClockModel? _model;
  ClockEstimate? _best;
  ClockEstimate? get best => _best;

  int nowServerMs() {
    final local = DateTime.now().millisecondsSinceEpoch;
    final m = _model;
    if (m == null) return local;
    return local + m.offsetAt(local).round();
  }

  void start() {
    _sub = _client.stream.where((e) => e.type == typePong).listen(_onPong);
    _scheduleNext(immediate: true);
  }

  void _scheduleNext({bool immediate = false}) {
    if (immediate) {
      _sendPing();
      return;
    }
    final d = _pingsSent < burstCount ? burstInterval : interval;
    _timer = Timer(d, _sendPing);
  }

  void _sendPing() {
    final t0 = DateTime.now().millisecondsSinceEpoch;
    _pingsSent++;
    final udp = _udp;
    if (udp != null && _udpTarget != null) {
      udp.send(utf8.encode(jsonEncode({'t0': t0})), _udpTarget!, _udpPort);
    }
    if (!_udpConfirmed) {
      _client.send(typePing, {'t0': t0});
    }
    _scheduleNext();
  }

  Future<void> enableUdp(String host, int port) async {
    if (_udp != null || port <= 0) return;
    try {
      final addrs = await InternetAddress.lookup(host);
      if (addrs.isEmpty) return;
      _udpTarget = addrs.first;
      _udpPort = port;
      final sock = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      sock.listen((event) {
        if (event != RawSocketEvent.read) return;
        final dg = sock.receive();
        if (dg != null) _onUdpPong(dg.data);
      });
      _udp = sock;
    } catch (_) {
      _udp = null;
    }
  }

  void _onUdpPong(List<int> bytes) {
    try {
      final d = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final t0 = (d['t0'] as num?)?.toInt();
      final t1 = (d['t1'] as num?)?.toInt();
      final t2 = (d['t2'] as num?)?.toInt();
      if (t0 == null || t1 == null || t2 == null) return;
      _udpConfirmed = true;
      _ingest(t0, t1, t2, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  void _onPong(Envelope env) {
    final t3 = DateTime.now().millisecondsSinceEpoch;
    final d = env.data;
    if (d == null) return;
    final t0 = (d['t0'] as num?)?.toInt();
    final t1 = (d['t1'] as num?)?.toInt();
    final t2 = (d['t2'] as num?)?.toInt();
    if (t0 == null || t1 == null || t2 == null) return;
    _ingest(t0, t1, t2, t3);
  }

  void _ingest(int t0, int t1, int t2, int t3) {
    _window.add(ClockSample.fromTimestamps(t0, t1, t2, t3));
    if (_window.length > windowSize) _window.removeAt(0);

    final model = ClockModel.fit(_window);
    if (model == null) return;
    _model = model;
    final now = DateTime.now().millisecondsSinceEpoch;
    _best = ClockEstimate(
      model.offsetAt(now).round(),
      model.minRtt,
      model.kept,
      (model.slope * 1e6).round(),
    );
    _estimates.add(_best!);
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    await _sub?.cancel();
    _sub = null;
    _udp?.close();
    _udp = null;
    _udpConfirmed = false;
    _window.clear();
    _model = null;
    _best = null;
    _pingsSent = 0;
    if (!_estimates.isClosed) await _estimates.close();
  }
}
