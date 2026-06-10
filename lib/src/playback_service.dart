import 'dart:async';
import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';

import 'clock_sync.dart';
import 'downloader.dart';
import 'protocol.dart';
import 'ws_client.dart';

String resolveMediaUrl(String httpBase, String fileUrl) {
  final path = Uri.parse(fileUrl).path;
  return '${httpBase.replaceFirst(RegExp(r'/+$'), '')}$path';
}

String httpBaseFromWs(String wsUrl) {
  final u = Uri.parse(wsUrl);
  final scheme = u.scheme == 'wss' ? 'https' : 'http';
  final port = u.hasPort ? ':${u.port}' : '';
  return '$scheme://${u.host}$port';
}

const driftIgnoreThresholdMs = 35;
const driftSeekThresholdMs = 800;
const _maxNudge = 0.06;
const _nudgeFullScaleMs = 350;
const _minNudge = 0.004;
const _speedEpsilon = 0.001;
const _driftInterval = Duration(milliseconds: 500);
const _startRecheckWindowMs = 120;
const _startPrecisionMs = 8;

enum DriftKind { ignore, nudge, seek }

class DriftAction {
  const DriftAction(this.kind, [this.speed = 1.0]);

  final DriftKind kind;
  final double speed;
}

DriftAction driftActionFor(int driftMs, {double maxNudge = _maxNudge}) {
  final magnitude = driftMs.abs();
  if (magnitude >= driftSeekThresholdMs) {
    return const DriftAction(DriftKind.seek);
  }
  if (magnitude < driftIgnoreThresholdMs) {
    return const DriftAction(DriftKind.ignore);
  }
  final adj = (magnitude / _nudgeFullScaleMs * maxNudge).clamp(
    _minNudge,
    maxNudge,
  );
  return DriftAction(DriftKind.nudge, driftMs > 0 ? 1.0 - adj : 1.0 + adj);
}

int confidenceForFraction(double frac) {
  if (frac >= 0.9) return 3;
  if (frac >= 0.5) return 2;
  if (frac >= 0.2) return 1;
  return 0;
}

int confidenceForDrift(int driftMs) {
  final a = driftMs.abs();
  if (a > 250) return 1;
  if (a > driftIgnoreThresholdMs) return 2;
  return 3;
}

class PlaybackState {
  const PlaybackState({
    this.trackId,
    this.playing = false,
    this.positionMs = 0,
    this.driftMs = 0,
  });

  final String? trackId;
  final bool playing;
  final int positionMs;
  final int driftMs;
}

class PlaybackService {
  PlaybackService(
    this._client,
    this._clock,
    this._httpBase, {
    Directory? cacheDir,
  }) {
    _cacheDir = cacheDir;
  }

  final WsClient _client;
  final ClockSync _clock;
  final String _httpBase;

  final _player = AudioPlayer();
  final _state = StreamController<PlaybackState>.broadcast();
  Stream<PlaybackState> get state => _state.stream;

  String? _trackId;
  bool _paused = true;
  Timer? _startTimer;
  Timer? _driftTimer;
  Directory? _cacheDir;
  Downloader? _downloader;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<double>? _dlProgSub;
  int? _t0;
  int? _s;
  int _driftMs = 0;
  int _durationMs = 0;
  double _appliedSpeed = 1.0;
  double _catchup = _maxNudge;
  int _lastPosEmitMs = 0;
  int _commandSeq = 0;
  bool _correctingDrift = false;
  int _suppressLocalControlUntilMs = 0;
  Map<String, dynamic>? _pendingNowPlaying;
  static const _posEmitIntervalMs = 250;

  void setCatchupStrength(double maxSpeed) {
    _catchup = (maxSpeed - 1.0).clamp(0.01, 0.30);
  }

  static const _prefetchDepth = 2;

  void attach(Stream<Envelope> stream) {
    _posSub = _player.positionStream.listen((pos) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastPosEmitMs >= _posEmitIntervalMs) {
        _lastPosEmitMs = now;
        _emit(positionMs: pos.inMilliseconds);
      }
    });
    _playingSub = _player.playingStream.listen((playing) {
      _emit();
      final tid = _trackId;
      if (tid == null) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now < _suppressLocalControlUntilMs) return;
      if (playing && _paused) {
        _client.send(typeControl, {'action': controlResume});
      } else if (!playing && !_paused) {
        _client.send(typeControl, {'action': controlPause});
      }
    });
    stream.listen((env) {
      switch (env.type) {
        case typePrepare:
          final d = env.data;
          if (d != null) {
            _onPrepare(
              d['trackId'] as String?,
              d['fileUrl'] as String?,
              (d['durationMs'] as num?)?.toInt() ?? 0,
              d['title'] as String?,
            );
          }
          break;
        case typeNowPlaying:
          final d = env.data;
          if (d != null) unawaited(_onNowPlaying(d));
          break;
      }
    });
  }

  Future<void> _onPrepare(
    String? trackId,
    String? fileUrl,
    int durationMs,
    String? title,
  ) async {
    if (trackId == null || fileUrl == null) return;
    _durationMs = durationMs;
    await _dlProgSub?.cancel();
    _dlProgSub = null;
    try {
      final dl = await _dl();
      final tag = MediaItem(
        id: trackId,
        title: (title == null || title.isEmpty) ? 'team4tune' : title,
        album: 'team4tune',
        duration: durationMs > 0 ? Duration(milliseconds: durationMs) : null,
      );
      final AudioSource source;
      if (await dl.isCached(trackId)) {
        source = AudioSource.file(dl.fileFor(trackId).path, tag: tag);
        _sendProgress(trackId, ready: true, frac: 1.0, bps: 0);
      } else {
        final url = resolveMediaUrl(_httpBase, fileUrl);
        source = LockCachingAudioSource(Uri.parse(url), tag: tag);
        _dlProgSub = (source as LockCachingAudioSource).downloadProgressStream
            .listen(
              (p) => _sendProgress(trackId, ready: p >= 1.0, frac: p, bps: 0),
            );
      }
      await _player.setAudioSource(source);
      _trackId = trackId;
      _emit();
      _client.send(typeReady, {'trackId': trackId});
      final pending = _pendingNowPlaying;
      _pendingNowPlaying = null;
      if (pending != null && (pending['trackId'] as String?) == trackId) {
        await _onNowPlaying(pending);
      }
    } catch (_) {}
  }

  void _sendProgress(
    String trackId, {
    required bool ready,
    required double frac,
    required int bps,
  }) {
    final confidence = ready ? 3 : confidenceForFraction(frac);
    _client.send(typeProgress, {
      'trackId': trackId,
      'haveMs': (frac * _durationMs).round(),
      'totalMs': _durationMs,
      'bps': bps,
      'ready': ready,
      'confidence': confidence,
    });
  }

  Future<void> _onNowPlaying(Map<String, dynamic> d) async {
    final trackId = d['trackId'] as String?;
    if (trackId == null) return;
    if (trackId != _trackId) {
      _pendingNowPlaying = d;
      return;
    }
    _pendingNowPlaying = null;
    final seq = ++_commandSeq;
    final t0 = (d['t0'] as num?)?.toInt() ?? 0;
    final s = (d['s'] as num?)?.toInt() ?? 0;
    _paused = (d['paused'] as bool?) ?? false;
    _t0 = t0;
    _s = s;
    _driftMs = 0;

    _startTimer?.cancel();
    _correctingDrift = false;
    await _runRemote(() => _setSpeed(1.0));
    if (seq != _commandSeq) return;

    final serverNow = _clock.nowServerMs();
    if (_paused) {
      await _runRemote(() => _player.pause());
      if (seq != _commandSeq) return;
      await _runRemote(
        () => _player.seek(Duration(milliseconds: _clampPosition(s))),
      );
    } else if (serverNow >= t0) {
      await _runRemote(
        () => _player.seek(
          Duration(milliseconds: _expectedPosition(serverNow, t0, s)),
        ),
      );
      if (seq != _commandSeq) return;
      await _runRemote(() => _player.play());
    } else {
      await _runRemote(
        () => _player.seek(Duration(milliseconds: _clampPosition(s))),
      );
      if (seq != _commandSeq) return;
      _scheduleStart(seq);
    }
    _startDriftLoop();
    _emit();
  }

  void _startDriftLoop() {
    _driftTimer ??= Timer.periodic(
      _driftInterval,
      (_) => unawaited(_correctDrift()),
    );
  }

  void _scheduleStart(int seq) {
    if (seq != _commandSeq || _paused) return;
    final t0 = _t0;
    if (t0 == null) return;
    final remaining = t0 - _clock.nowServerMs();
    if (remaining <= _startPrecisionMs) {
      unawaited(_startAt(seq));
      return;
    }
    final delay = remaining > _startRecheckWindowMs
        ? remaining - _startRecheckWindowMs
        : remaining;
    _startTimer = Timer(
      Duration(milliseconds: delay),
      () => _scheduleStart(seq),
    );
  }

  Future<void> _startAt(int seq) async {
    final t0 = _t0;
    if (seq != _commandSeq || _paused || t0 == null) return;
    final remaining = t0 - _clock.nowServerMs();
    if (remaining > _startPrecisionMs) {
      _scheduleStart(seq);
      return;
    }
    if (remaining > 0) {
      await Future<void>.delayed(Duration(milliseconds: remaining));
    }
    if (seq != _commandSeq || _paused) return;
    await _runRemote(() => _player.play());
  }

  Future<T> _runRemote<T>(Future<T> Function() action) async {
    _suppressLocalControlUntilMs = DateTime.now().millisecondsSinceEpoch + 800;
    try {
      return await action();
    } finally {
      _suppressLocalControlUntilMs =
          DateTime.now().millisecondsSinceEpoch + 800;
    }
  }

  Future<void> _setSpeed(double v) async {
    if ((v - _appliedSpeed).abs() < _speedEpsilon) return;
    _appliedSpeed = v;
    await _player.setSpeed(v);
  }

  int _expectedPosition(int serverNow, int t0, int s) {
    final pos = serverNow >= t0 ? s + (serverNow - t0) : s;
    return _clampPosition(pos);
  }

  int _clampPosition(int pos) {
    if (pos < 0) return 0;
    if (_durationMs > 0 && pos > _durationMs) return _durationMs;
    return pos;
  }

  Future<void> _correctDrift() async {
    if (_correctingDrift) return;
    final t0 = _t0;
    final s = _s;
    if (t0 == null || s == null || _paused || !_player.playing) return;
    _correctingDrift = true;
    try {
      final expected = _expectedPosition(_clock.nowServerMs(), t0, s);
      _driftMs = _player.position.inMilliseconds - expected;
      final action = driftActionFor(_driftMs, maxNudge: _catchup);
      switch (action.kind) {
        case DriftKind.seek:
          await _runRemote(
            () => _player.seek(Duration(milliseconds: expected)),
          );
          await _runRemote(() => _setSpeed(1.0));
          break;
        case DriftKind.nudge:
          await _runRemote(() => _setSpeed(action.speed));
          break;
        case DriftKind.ignore:
          await _runRemote(() => _setSpeed(1.0));
          break;
      }
      final tid = _trackId;
      if (tid != null) {
        _client.send(typeProgress, {
          'trackId': tid,
          'haveMs': _durationMs,
          'totalMs': _durationMs,
          'bps': 0,
          'ready': true,
          'confidence': confidenceForDrift(_driftMs),
        });
      }
      _emit();
    } finally {
      _correctingDrift = false;
    }
  }

  Future<void> stopTrack(String trackId) async {
    if (_trackId != trackId) return;
    _startTimer?.cancel();
    _paused = true;
    _t0 = null;
    _s = null;
    _driftMs = 0;
    _pendingNowPlaying = null;
    await _runRemote(() => _setSpeed(1.0));
    await _runRemote(() => _player.stop());
    _trackId = null;
    _emit();
  }

  Future<Downloader> _dl() async {
    _cacheDir ??= await getTemporaryDirectory();
    return _downloader ??= Downloader(_cacheDir!);
  }

  Future<void> prefetch(List<Track> upcoming) async {
    final dl = await _dl();
    var scheduled = 0;
    for (final t in upcoming) {
      if (scheduled >= _prefetchDepth) break;
      final url = t.fileUrl;
      if (t.id == _trackId || url == null || url.isEmpty) continue;
      if (await dl.isCached(t.id)) continue;
      scheduled++;
      unawaited(
        dl.fetch(t.id, resolveMediaUrl(_httpBase, url)).catchError((_) {
          return dl.fileFor(t.id);
        }),
      );
    }
  }

  void _emit({int? positionMs}) {
    _state.add(
      PlaybackState(
        trackId: _trackId,
        playing: _player.playing,
        positionMs: positionMs ?? _player.position.inMilliseconds,
        driftMs: _driftMs,
      ),
    );
  }

  Future<void> dispose() async {
    _startTimer?.cancel();
    _driftTimer?.cancel();
    _downloader?.close();
    await _dlProgSub?.cancel();
    await _posSub?.cancel();
    await _playingSub?.cancel();
    await _player.dispose();
    if (!_state.isClosed) await _state.close();
  }
}
