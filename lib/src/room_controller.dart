import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'clock_sync.dart';
import 'local_opus_encoder.dart';
import 'playback_service.dart';
import 'protocol.dart';
import 'room_foreground_service.dart';
import 'share_service.dart';
import 'stream_service.dart';
import 'ws_client.dart';

const shareNoticeAdded = 'added';
const shareNoticePending = 'pending';
const uploadNoticeEncoding = 'encoding';
const uploadNoticeUploading = 'uploading';
const uploadNoticeFailed = 'upload_failed';

final _urlPattern = RegExp(r'https?://\S+');

String? firstUrl(String text) => _urlPattern.firstMatch(text)?.group(0);

class AppState {
  const AppState({
    this.connecting = false,
    this.room,
    this.error,
    this.clockOffsetMs,
    this.clockRttMs,
    this.nowPlayingTrackId,
    this.playing = false,
    this.positionMs = 0,
    this.driftMs = 0,
    this.buffering = false,
    this.reconnecting = false,
    this.catchupSpeed = 1.06,
    this.shareNotice,
    this.noticeSeq = 0,
  });

  final bool connecting;
  final RoomState? room;
  final String? error;
  final int? clockOffsetMs;
  final int? clockRttMs;
  final String? nowPlayingTrackId;
  final bool playing;
  final int positionMs;
  final int driftMs;
  final bool buffering;
  final bool reconnecting;
  final double catchupSpeed;
  final String? shareNotice;
  final int noticeSeq;

  bool get connected => room != null;

  AppState copyWith({
    bool? connecting,
    RoomState? room,
    String? error,
    int? clockOffsetMs,
    int? clockRttMs,
    String? nowPlayingTrackId,
    bool? playing,
    int? positionMs,
    int? driftMs,
    bool? buffering,
    bool? reconnecting,
    double? catchupSpeed,
    String? shareNotice,
    int? noticeSeq,
    bool clearError = false,
    bool clearRoom = false,
    bool clearNowPlaying = false,
  }) {
    return AppState(
      connecting: connecting ?? this.connecting,
      room: clearRoom ? null : (room ?? this.room),
      error: clearError ? null : (error ?? this.error),
      clockOffsetMs: clockOffsetMs ?? this.clockOffsetMs,
      clockRttMs: clockRttMs ?? this.clockRttMs,
      nowPlayingTrackId: clearNowPlaying
          ? null
          : (nowPlayingTrackId ?? this.nowPlayingTrackId),
      playing: playing ?? this.playing,
      positionMs: positionMs ?? this.positionMs,
      driftMs: driftMs ?? this.driftMs,
      buffering: buffering ?? this.buffering,
      reconnecting: reconnecting ?? this.reconnecting,
      catchupSpeed: catchupSpeed ?? this.catchupSpeed,
      shareNotice: shareNotice ?? this.shareNotice,
      noticeSeq: noticeSeq ?? this.noticeSeq,
    );
  }
}

class RoomController extends Notifier<AppState> {
  WsClient? _client;
  StreamSubscription<Envelope>? _sub;
  ClockSync? _clock;
  StreamSubscription<ClockEstimate>? _clockSub;
  PlaybackService? _playback;
  StreamSubscription<PlaybackState>? _playbackSub;
  StreamService? _stream;
  StreamSubscription<bool>? _streamSub;
  String _serverHost = '';
  String _serverUrl = '';
  String _roomCode = '';
  String _nick = '';
  String _resumeToken = '';
  bool _leaving = false;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  Directory? _cacheOverride;
  double _catchupSpeed = 1.06;
  String? _pendingShare;

  set cacheDirForTest(Directory dir) => _cacheOverride = dir;

  @override
  AppState build() {
    RoomForegroundService.instance.configure(
      onPause: pause,
      onResume: resume,
      onLeave: leave,
      onSeekRelative: _seekRelative,
    );
    ref.onDispose(() {
      unawaited(_teardown(stopRoomService: true));
    });
    ShareService.instance.configure(handleSharedUrl);
    unawaited(ShareService.instance.pullInitial());
    return const AppState();
  }

  bool _canEnqueue(RoomState room) =>
      room.settings.policyFor(scopeEnqueue) == policyEveryone ||
      room.isSelfHost;

  void _emitNotice(String notice) {
    state = state.copyWith(shareNotice: notice, noticeSeq: state.noticeSeq + 1);
  }

  void handleSharedUrl(String raw) {
    final url = firstUrl(raw);
    if (url == null) return;
    final room = state.room;
    if (room != null && _client != null && !state.reconnecting && _canEnqueue(room)) {
      enqueue(url);
      _emitNotice(shareNoticeAdded);
    } else {
      _pendingShare = url;
      _emitNotice(shareNoticePending);
    }
  }

  void _submitEnqueue(String sourceUrl) {
    _pendingShare = sourceUrl;
    final room = state.room;
    final live = room != null && _client != null && !state.reconnecting;
    if (live && _canEnqueue(room)) {
      enqueue(sourceUrl);
    }
    _emitNotice(shareNoticeAdded);
  }

  Future<void> createRoom(String serverUrl, String nick, String mode) async {
    _leaving = false;
    _nick = nick;
    _resumeToken = '';
    await _open(serverUrl);
    _client?.send(typeCreate, {'mode': mode, 'nick': nick});
  }

  Future<void> joinRoom(String serverUrl, String code, String nick) async {
    _leaving = false;
    _nick = nick;
    _roomCode = code.toUpperCase().trim();
    _resumeToken = '';
    await _open(serverUrl);
    _client?.send(typeJoin, {'roomCode': _roomCode, 'nick': nick});
  }

  void enqueue(String sourceUrl) {
    _client?.send(typeEnqueue, {'sourceUrl': sourceUrl.trim()});
  }

  Future<void> uploadAndEnqueue(String pickedPath) async {
    if (_serverUrl.isEmpty) {
      _emitNotice(uploadNoticeFailed);
      return;
    }
    try {
      _emitNotice(uploadNoticeEncoding);
      final track = await LocalOpusEncoder.encodeFile(pickedPath);
      _emitNotice(uploadNoticeUploading);
      final uri = Uri.parse('${httpBaseFromWs(_serverUrl)}/upload');
      final req = http.MultipartRequest('POST', uri)
        ..fields['title'] = track.title
        ..files.add(await http.MultipartFile.fromPath('file', track.path));
      final resp = await req.send();
      final body = await resp.stream.bytesToString();
      unawaited(File(track.path).delete().catchError((_) => File(track.path)));
      if (resp.statusCode != 200) {
        _emitNotice(uploadNoticeFailed);
        return;
      }
      final sourceUrl =
          (jsonDecode(body) as Map<String, dynamic>)['sourceUrl'] as String?;
      if (sourceUrl == null || sourceUrl.isEmpty) {
        _emitNotice(uploadNoticeFailed);
        return;
      }
      _submitEnqueue(sourceUrl);
    } catch (_) {
      _emitNotice(uploadNoticeFailed);
    }
  }

  void skip() => _client?.send(typeSkip, const {});

  void removeTrack(String trackId) =>
      _client?.send(typeRemove, {'trackId': trackId});

  void pause() => _client?.send(typeControl, {'action': controlPause});

  void resume() => _client?.send(typeControl, {'action': controlResume});

  void seek(int ms) =>
      _client?.send(typeControl, {'action': controlSeek, 'seekMs': ms});

  void _seekRelative(int deltaMs) {
    final max = _currentDurationMs();
    final target = (state.positionMs + deltaMs).clamp(0, max).toInt();
    seek(target);
  }

  void setSettings(RoomSettings settings) =>
      _client?.send(typeSetSettings, settings.toJson());

  void setCatchupSpeed(double maxSpeed) {
    _catchupSpeed = maxSpeed.clamp(1.02, 1.30);
    _playback?.setCatchupStrength(_catchupSpeed);
    state = state.copyWith(catchupSpeed: _catchupSpeed);
  }

  Future<void> leave() async {
    _leaving = true;
    _reconnectTimer?.cancel();
    _client?.send(typeBye, const {});
    await _teardown(stopRoomService: true);
    _roomCode = '';
    _resumeToken = '';
    _pendingShare = null;
    state = const AppState();
  }

  Future<void> _open(String serverUrl, {bool reconnect = false}) async {
    await _teardown();
    _serverUrl = serverUrl;
    _serverHost = Uri.tryParse(serverUrl)?.host ?? '';
    state = reconnect
        ? state.copyWith(reconnecting: true)
        : const AppState(connecting: true);
    try {
      final client = await WsClient.connect(serverUrl);
      _client = client;
      _sub = client.stream.listen(
        _onMessage,
        onError: (e) {
          if (!ref.mounted) return;
          _onDisconnect();
        },
        onDone: () {
          if (!ref.mounted) return;
          _onDisconnect();
        },
      );
      _clock = ClockSync(client);
      _clockSub = _clock!.estimates.listen((est) {
        if (!ref.mounted) return;
        state = state.copyWith(
          clockOffsetMs: est.offsetMs,
          clockRttMs: est.rttMs,
        );
      });
      _clock!.start();
      _playback = PlaybackService(
        client,
        _clock!,
        httpBaseFromWs(serverUrl),
        cacheDir: _cacheOverride,
      )..setCatchupStrength(_catchupSpeed);
      _playbackSub = _playback!.state.listen((ps) {
        if (!ref.mounted) return;
        state = state.copyWith(
          nowPlayingTrackId: ps.trackId,
          playing: ps.playing,
          positionMs: ps.positionMs,
          driftMs: ps.driftMs,
          buffering: ps.buffering,
        );
        _syncRoomService();
      });
      _playback!.attach(client.stream);
      _stream = StreamService(client);
      _streamSub = _stream!.connected.listen((up) {
        if (!ref.mounted) return;
        state = state.copyWith(playing: up);
      });
      _stream!.attach(client.stream);
    } catch (e) {
      if (reconnect) {
        _scheduleReconnect();
      } else {
        state = AppState(error: 'connect failed: $e');
      }
    }
  }

  void _onDisconnect() {
    if (_leaving || _roomCode.isEmpty || _resumeToken.isEmpty) {
      state = state.copyWith(clearRoom: true, error: 'disconnected');
      return;
    }
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_leaving || !ref.mounted) return;
    _reconnectTimer?.cancel();
    state = state.copyWith(reconnecting: true);
    final delayMs = (500 * (1 << _reconnectAttempts.clamp(0, 5)))
        .clamp(500, 15000)
        .toInt();
    _reconnectAttempts++;
    _reconnectTimer = Timer(Duration(milliseconds: delayMs), _reconnect);
  }

  Future<void> _reconnect() async {
    if (_leaving || !ref.mounted) return;
    await _open(_serverUrl, reconnect: true);
    _client?.send(typeJoin, {
      'roomCode': _roomCode,
      'nick': _nick,
      'resumeToken': _resumeToken,
    });
  }

  void _onMessage(Envelope env) {
    if (!ref.mounted) return;
    switch (env.type) {
      case typeRoomState:
        final room = RoomState.fromJson(env.data ?? const {});
        _roomCode = room.roomCode;
        if (room.resumeToken.isNotEmpty) _resumeToken = room.resumeToken;
        _reconnectAttempts = 0;
        if (room.mode == modeStream) {
          _stream?.join();
          final np = room.playingTrackId.isEmpty ? null : room.playingTrackId;
          state = state.copyWith(
            room: room,
            connecting: false,
            reconnecting: false,
            clearError: true,
            nowPlayingTrackId: np,
            clearNowPlaying: np == null,
          );
          _syncRoomService(room: room);
          if (_pendingShare != null && _canEnqueue(room)) {
            enqueue(_pendingShare!);
            _pendingShare = null;
            _emitNotice(shareNoticeAdded);
          }
          break;
        }
        final removedTrackId = _removedNowPlayingTrack(room);
        if (removedTrackId != null) {
          unawaited(_playback?.stopTrack(removedTrackId));
        }
        state = state.copyWith(
          room: room,
          connecting: false,
          reconnecting: false,
          clearError: true,
          clearNowPlaying: removedTrackId != null,
        );
        _syncRoomService(room: room);
        if (_pendingShare != null && _canEnqueue(room)) {
          enqueue(_pendingShare!);
          _pendingShare = null;
          _emitNotice(shareNoticeAdded);
        }
        final upcoming = room.queue
            .where((t) => t.status == 'ready' && (t.fileUrl ?? '').isNotEmpty)
            .toList();
        _playback?.prefetch(upcoming);
        if (room.udpPort > 0 && _serverHost.isNotEmpty) {
          _clock?.enableUdp(_serverHost, room.udpPort);
        }
        break;
      case typeError:
        final d = env.data ?? const {};
        state = state.copyWith(
          connecting: false,
          error: (d['message'] as String?) ?? (d['code'] as String?) ?? 'error',
        );
        break;
      default:
        break;
    }
  }

  Future<void> debugDrop() async => _client?.forceClose();

  String? _removedNowPlayingTrack(RoomState room) {
    final id = state.nowPlayingTrackId;
    if (id == null) return null;
    for (final track in room.queue) {
      if (track.id == id) return null;
    }
    return id;
  }

  int _currentDurationMs() {
    final room = state.room;
    final id = state.nowPlayingTrackId;
    if (room == null || id == null) return 0x7fffffff;
    for (final track in room.queue) {
      final duration = track.durationMs ?? 0;
      if (track.id == id && duration > 0) return duration;
    }
    return 0x7fffffff;
  }

  String _roomServiceTitle() {
    final room = state.room;
    final id = state.nowPlayingTrackId;
    if (room == null || id == null) return 'Connected';
    for (final track in room.queue) {
      if (track.id == id) {
        final title = track.title ?? '';
        return title.isEmpty ? 'Playing' : title;
      }
    }
    return state.reconnecting ? 'Reconnecting…' : 'Connected';
  }

  void _syncRoomService({RoomState? room}) {
    final activeRoom = room ?? state.room;
    if (activeRoom == null) return;
    unawaited(
      RoomForegroundService.instance
          .startOrUpdate(
            roomCode: activeRoom.roomCode,
            playing: state.playing,
            title: _roomServiceTitle(),
          )
          .catchError((_) {}),
    );
  }

  Future<void> _teardown({bool stopRoomService = false}) async {
    await _playbackSub?.cancel();
    _playbackSub = null;
    await _playback?.dispose();
    _playback = null;
    await _streamSub?.cancel();
    _streamSub = null;
    await _stream?.dispose();
    _stream = null;
    await _clockSub?.cancel();
    _clockSub = null;
    await _clock?.stop();
    _clock = null;
    await _sub?.cancel();
    _sub = null;
    await _client?.close();
    _client = null;
    if (stopRoomService) {
      await RoomForegroundService.instance.stop();
    }
  }
}

final roomControllerProvider = NotifierProvider<RoomController, AppState>(
  RoomController.new,
);
