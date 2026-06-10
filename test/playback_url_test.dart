import 'package:flutter_test/flutter_test.dart';

import 'package:team4tune/src/playback_service.dart';

void main() {
  test('httpBaseFromWs strips /ws and swaps scheme', () {
    expect(httpBaseFromWs('ws://10.0.2.2:8080/ws'), 'http://10.0.2.2:8080');
    expect(httpBaseFromWs('wss://node.example:443/ws'), 'https://node.example:443');
    expect(httpBaseFromWs('ws://localhost/ws'), 'http://localhost');
  });

  test('resolveMediaUrl rebases the media path onto the connected host', () {
    expect(
      resolveMediaUrl('http://10.0.2.2:8080', 'http://localhost:8080/media/abc.opus'),
      'http://10.0.2.2:8080/media/abc.opus',
    );
    expect(
      resolveMediaUrl('http://10.0.2.2:8080', '/media/abc.opus'),
      'http://10.0.2.2:8080/media/abc.opus',
    );
  });
}
