import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

typedef RoomAction = FutureOr<void> Function();
typedef SeekAction = FutureOr<void> Function(int deltaMs);

class RoomForegroundService {
  RoomForegroundService._();

  static final instance = RoomForegroundService._();
  static const _channel = MethodChannel('team4tune/room_foreground');

  RoomAction? _onPause;
  RoomAction? _onResume;
  RoomAction? _onLeave;
  SeekAction? _onSeekRelative;
  bool _configured = false;
  bool _started = false;

  void configure({
    required RoomAction onPause,
    required RoomAction onResume,
    required RoomAction onLeave,
    required SeekAction onSeekRelative,
  }) {
    _onPause = onPause;
    _onResume = onResume;
    _onLeave = onLeave;
    _onSeekRelative = onSeekRelative;
    if (_configured) return;
    _configured = true;
    _channel.setMethodCallHandler(_handle);
  }

  Future<void> _handle(MethodCall call) async {
    if (call.method != 'action') return;
    switch (call.arguments as String?) {
      case 'pause':
        await _onPause?.call();
        break;
      case 'resume':
        await _onResume?.call();
        break;
      case 'rewind':
        await _onSeekRelative?.call(-10000);
        break;
      case 'forward':
        await _onSeekRelative?.call(10000);
        break;
      case 'leave':
        await _onLeave?.call();
        break;
    }
  }

  Future<void> startOrUpdate({
    required String roomCode,
    required bool playing,
    required String title,
  }) async {
    if (!Platform.isAndroid) return;
    final method = _started ? 'update' : 'start';
    _started = true;
    await _channel.invokeMethod<void>(method, {
      'roomCode': roomCode,
      'playing': playing,
      'title': title,
    });
  }

  Future<void> stop() async {
    if (!Platform.isAndroid || !_started) return;
    _started = false;
    await _channel.invokeMethod<void>('stop');
  }
}
