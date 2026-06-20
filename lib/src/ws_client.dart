import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'protocol.dart';

class WsClient {
  WsClient._(this._channel);

  final WebSocketChannel _channel;
  final _controller = StreamController<Envelope>.broadcast();
  StreamSubscription? _sub;

  static Future<WsClient> connect(String url) async {
    final channel = WebSocketChannel.connect(Uri.parse(url));
    await channel.ready;
    final client = WsClient._(channel);
    client._listen();
    return client;
  }

  void _listen() {
    _sub = _channel.stream.listen(
      (raw) {
        try {
          _controller.add(Envelope.decode(raw as String));
        } catch (_) {}
      },
      onError: (e) => _controller.addError(e),
      onDone: () => _controller.close(),
    );
  }

  Stream<Envelope> get stream => _controller.stream;

  void send(String type, [Map<String, dynamic>? data]) {
    try {
      _channel.sink.add(Envelope(type, data).encode());
    } catch (_) {}
  }

  Future<void> close() async {
    await _sub?.cancel();
    await _channel.sink.close();
    if (!_controller.isClosed) await _controller.close();
  }

  Future<void> forceClose() async {
    await _sub?.cancel();
    await _channel.sink.close();
    if (!_controller.isClosed) await _controller.close();
  }
}
