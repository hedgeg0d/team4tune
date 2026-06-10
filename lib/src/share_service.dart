import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

typedef SharedTextHandler = void Function(String text);

class ShareService {
  ShareService._();

  static final instance = ShareService._();
  static const _channel = MethodChannel('team4tune/share');

  SharedTextHandler? _onShared;
  bool _configured = false;

  void configure(SharedTextHandler onShared) {
    _onShared = onShared;
    if (_configured) return;
    _configured = true;
    _channel.setMethodCallHandler(_handle);
  }

  Future<void> _handle(MethodCall call) async {
    if (call.method != 'shared') return;
    final text = call.arguments as String?;
    if (text != null && text.isNotEmpty) _onShared?.call(text);
  }

  Future<void> pullInitial() async {
    if (!Platform.isAndroid) return;
    final text = await _channel.invokeMethod<String>('getInitial');
    if (text != null && text.isNotEmpty) _onShared?.call(text);
  }
}
