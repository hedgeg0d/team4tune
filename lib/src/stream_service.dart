import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'protocol.dart';
import 'ws_client.dart';

class StreamService {
  StreamService(this._client);

  final WsClient _client;
  RTCPeerConnection? _pc;
  StreamSubscription<Envelope>? _sub;
  MediaStream? _remote;
  bool _joined = false;

  final _connected = StreamController<bool>.broadcast();

  Stream<bool> get connected => _connected.stream;

  void attach(Stream<Envelope> stream) {
    _sub = stream.listen((env) {
      if (env.type == typeRtc) unawaited(_onSignal(env.data));
    });
  }

  void join() {
    if (_joined) return;
    _joined = true;
    _client.send(typeRtc, {'kind': rtcJoin});
  }

  Future<void> _onSignal(Map<String, dynamic>? d) async {
    if (d == null) return;
    try {
      switch (d['kind'] as String?) {
        case rtcOffer:
          await _onOffer(d['sdp'] as String? ?? '');
          break;
        case rtcIce:
          await _onIce(d['candidate']);
          break;
      }
    } catch (e, st) {
      debugPrint('StreamService signal failed: $e\n$st');
    }
  }

  Future<void> _ensurePc() async {
    if (_pc != null) return;
    final pc = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    });
    pc.onIceCandidate = (c) {
      _client.send(typeRtc, {'kind': rtcIce, 'candidate': c.toMap()});
    };
    pc.onConnectionState = (s) {
      final up = s == RTCPeerConnectionState.RTCPeerConnectionStateConnected;
      if (!_connected.isClosed) _connected.add(up);
    };
    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) _remote = event.streams.first;
    };
    _pc = pc;
  }

  Future<void> _onOffer(String sdp) async {
    await _ensurePc();
    final pc = _pc!;
    await pc.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);
    _client.send(typeRtc, {'kind': rtcAnswer, 'sdp': answer.sdp});
  }

  Future<void> _onIce(dynamic candidate) async {
    final pc = _pc;
    if (pc == null || candidate is! Map<String, dynamic>) return;
    await pc.addCandidate(
      RTCIceCandidate(
        candidate['candidate'] as String?,
        candidate['sdpMid'] as String?,
        (candidate['sdpMLineIndex'] as num?)?.toInt(),
      ),
    );
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    await _pc?.close();
    _pc = null;
    await _remote?.dispose();
    _remote = null;
    if (!_connected.isClosed) await _connected.close();
  }
}
