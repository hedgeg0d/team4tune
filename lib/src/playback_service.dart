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

const streamDurationThresholdMs = 10 * 60 * 1000;
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
    this.buffering = false,
  });

  final String? trackId;
  final bool playing;
  final int positionMs;
  final int driftMs;
  final bool buffering;
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

  bool _streaming = false;
  bool _buffering = false;
  int _segmentBaseMs = 0;
  int _playAtMs = 0;
  String? _fileUrl;
  String? _title;

  void setCatchupStrength(double maxSpeed) {
    _catchup = (maxSpeed - 1.0).clamp(0.01, 0.30);
  }

  static const _prefetchDepth = 2;

  void attach(Stream<Envelope> stream) {
    _posSub = _player.positionStream.listen((pos) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastPosEmitMs >= _posEmitIntervalMs) {
        _lastPosEmitMs = now;
        _emit(positionMs: _segmentBaseMs + pos.inMilliseconds);
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
    _fileUrl = fileUrl;
    _title = title;
    _segmentBaseMs = 0;
    await _dlProgSub?.cancel();
    _dlProgSub = null;
    try {
      final dl = await _dl();
      final cached = await dl.isCached(trackId);
      _streaming = !cached && durationMs >= streamDurationThresholdMs;

      if (_streaming) {
        _trackId = trackId;
        _emit();
        _client.send(typeReady, {'trackId': trackId});
        _sendProgress(trackId, ready: true, frac: 1.0, bps: 0);
      } else {
        final tag = _mediaTag(trackId);
        final AudioSource source;
        if (cached) {
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
      }

      final pending = _pendingNowPlaying;
      _pendingNowPlaying = null;
      if (pending != null && (pending['trackId'] as String?) == trackId) {
        await _onNowPlaying(pending);
      }
    } catch (_) {}
  }

  MediaItem _mediaTag(String trackId) => MediaItem(
        id: trackId,
        title: (_title == null || _title!.isEmpty) ? 'team4tune' : _title!,
        album: 'team4tune',
        duration: _durationMs > 0 ? Duration(milliseconds: _durationMs) : null,
      );

  String _segUrl(int baseMs) {
    final url = resolveMediaUrl(_httpBase, _fileUrl!);
    if (baseMs < 1000) return url;
    final sec = baseMs ~/ 1000;
    if (url.endsWith('.opus')) {
      return '${url.substring(0, url.length - 5)}__t$sec.opus';
    }
    return '${url}__t$sec';
  }

  Future<bool> _loadSegmentAt(int baseMs, int seq) async {
    final tid = _trackId;
    if (tid == null) return false;
    final base = baseMs < 1000 ? 0 : (baseMs ~/ 1000) * 1000;
    _buffering = true;
    _emit();
    try {
      final source = AudioSource.uri(Uri.parse(_segUrl(base)), tag: _mediaTag(tid));
      await _player.setAudioSource(source);
    } catch (_) {
      _buffering = false;
      _emit();
      return false;
    }
    if (seq != _commandSeq) {
      _buffering = false;
      return false;
    }
    _segmentBaseMs = base;
    _buffering = false;
    _emit();
    return true;
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

    if (_streaming) {
      await _onNowPlayingStreaming(seq, t0, s);
      return;
    }

    _playAtMs = t0;
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

  Future<void> _onNowPlayingStreaming(int seq, int t0, int s) async {
    final serverNow = _clock.nowServerMs();
    final base = serverNow >= t0 ? _expectedPosition(serverNow, t0, s) : s;

    final ok = await _loadSegmentAt(base, seq);
    if (!ok || seq != _commandSeq) return;

    await _runRemote(() => _setSpeed(1.0));
    if (seq != _commandSeq) return;

    if (_paused) {
      await _runRemote(() => _player.pause());
    } else if (_clock.nowServerMs() < t0) {
      _playAtMs = t0;
      _scheduleStart(seq);
    } else {
      final within =
          (_expectedPosition(_clock.nowServerMs(), t0, s) - _segmentBaseMs)
              .clamp(0, 1 << 30);
      await _runRemote(() => _player.seek(Duration(milliseconds: within)));
      if (seq != _commandSeq) return;
      await _runRemote(() => _player.play());
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
    final t0 = _playAtMs;
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
    if (seq != _commandSeq || _paused) return;
    final t0 = _playAtMs;
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

  Future<void> _reseekStreaming() async {
    final t0 = _t0;
    final s = _s;
    if (t0 == null || s == null) return;
    final seq = ++_commandSeq;
    _startTimer?.cancel();
    await _onNowPlayingStreaming(seq, t0, s);
  }

  Future<void> _correctDrift() async {
    if (_correctingDrift || _buffering) return;
    final t0 = _t0;
    final s = _s;
    if (t0 == null || s == null || _paused || !_player.playing) return;
    _correctingDrift = true;
    try {
      final expected = _expectedPosition(_clock.nowServerMs(), t0, s);
      final actual = (_streaming ? _segmentBaseMs : 0) +
          _player.position.inMilliseconds;
      _driftMs = actual - expected;
      final action = driftActionFor(_driftMs, maxNudge: _catchup);
      switch (action.kind) {
        case DriftKind.seek:
          if (_streaming) {
            unawaited(_reseekStreaming());
          } else {
            await _runRemote(
              () => _player.seek(Duration(milliseconds: expected)),
            );
            await _runRemote(() => _setSpeed(1.0));
          }
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
    _streaming = false;
    _buffering = false;
    _segmentBaseMs = 0;
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
      if ((t.durationMs ?? 0) >= streamDurationThresholdMs) continue;
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
        positionMs: positionMs ??
            (_segmentBaseMs + _player.position.inMilliseconds),
        driftMs: _driftMs,
        buffering: _buffering,
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
