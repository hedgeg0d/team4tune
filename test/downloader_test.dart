import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:team4tune/src/downloader.dart';

Future<HttpServer> _serve(
  void Function(HttpRequest) handler,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen(handler);
  return server;
}

Uint8List _payload(int n) =>
    Uint8List.fromList(List<int>.generate(n, (i) => i % 251));

void _serveRange(HttpRequest req, Uint8List data) {
  final range = req.headers.value('range');
  var start = 0;
  if (range != null && range.startsWith('bytes=')) {
    start = int.tryParse(range.substring(6).split('-').first) ?? 0;
  }
  final slice = data.sublist(start);
  if (start > 0) {
    req.response.statusCode = HttpStatus.partialContent;
    req.response.headers
        .set('content-range', 'bytes $start-${data.length - 1}/${data.length}');
  }
  req.response.headers.contentType = ContentType.binary;
  req.response.contentLength = slice.length;
  req.response.add(slice);
  req.response.close();
}

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('dl_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('downloads a full file and reports completion', () async {
    final data = _payload(5000);
    final server = await _serve((req) => _serveRange(req, data));
    addTearDown(() => server.close(force: true));
    final url = 'http://127.0.0.1:${server.port}/x';

    final dl = Downloader(dir);
    var sawComplete = false;
    final file = await dl.fetch('id1', url, onProgress: (p) {
      if (p.complete) sawComplete = true;
    });

    expect(await file.length(), data.length);
    expect(await file.readAsBytes(), data);
    expect(sawComplete, isTrue);
    expect(await dl.isCached('id1'), isTrue);
  });

  test('resumes from a partial .part file via Range', () async {
    final data = _payload(8000);
    final part = File('${dir.path}/id2.part');
    await part.writeAsBytes(data.sublist(0, 3000));

    var rangedRequests = 0;
    final server = await _serve((req) {
      if (req.headers.value('range') != null) rangedRequests++;
      _serveRange(req, data);
    });
    addTearDown(() => server.close(force: true));
    final url = 'http://127.0.0.1:${server.port}/y';

    final dl = Downloader(dir);
    final file = await dl.fetch('id2', url);

    expect(await file.readAsBytes(), data);
    expect(rangedRequests, greaterThan(0));
  });

  test('retries transient failures then succeeds', () async {
    final data = _payload(2000);
    var hits = 0;
    final server = await _serve((req) {
      hits++;
      if (hits <= 2) {
        req.response.statusCode = HttpStatus.internalServerError;
        req.response.close();
        return;
      }
      _serveRange(req, data);
    });
    addTearDown(() => server.close(force: true));
    final url = 'http://127.0.0.1:${server.port}/z';

    final dl = Downloader(dir, maxRetries: 5);
    final file = await dl.fetch('id3', url);
    expect(await file.readAsBytes(), data);
    expect(hits, greaterThanOrEqualTo(3));
  });

  test('returns cached file without re-fetching', () async {
    final data = _payload(1000);
    var hits = 0;
    final server = await _serve((req) {
      hits++;
      _serveRange(req, data);
    });
    addTearDown(() => server.close(force: true));
    final url = 'http://127.0.0.1:${server.port}/c';

    final dl = Downloader(dir);
    await dl.fetch('id4', url);
    await dl.fetch('id4', url);
    expect(hits, 1);
  });
}
