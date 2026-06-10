import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

class DownloadProgress {
  const DownloadProgress({
    required this.haveBytes,
    required this.totalBytes,
    required this.bps,
    required this.complete,
  });

  final int haveBytes;
  final int totalBytes;
  final int bps;
  final bool complete;

  double get fraction =>
      totalBytes > 0 ? (haveBytes / totalBytes).clamp(0.0, 1.0) : 0.0;
}

class Downloader {
  Downloader(this._dir, {http.Client? client, this.maxRetries = 8})
      : _client = client ?? http.Client();

  final Directory _dir;
  final http.Client _client;
  final int maxRetries;

  final _active = <String, Future<File>>{};

  File fileFor(String id) => File('${_dir.path}/$id.opus');

  Future<bool> isCached(String id) async {
    final f = fileFor(id);
    return await f.exists() && await f.length() > 0;
  }

  Future<File> fetch(
    String id,
    String url, {
    void Function(DownloadProgress)? onProgress,
  }) {
    final existing = _active[id];
    if (existing != null) return existing;
    final future = _run(id, url, onProgress);
    _active[id] = future;
    return future.whenComplete(() => _active.remove(id));
  }

  Future<File> _run(
    String id,
    String url,
    void Function(DownloadProgress)? onProgress,
  ) async {
    final done = fileFor(id);
    if (await isCached(id)) {
      final len = await done.length();
      onProgress?.call(DownloadProgress(
          haveBytes: len, totalBytes: len, bps: 0, complete: true));
      return done;
    }

    final part = File('${_dir.path}/$id.part');
    var have = await part.exists() ? await part.length() : 0;
    int total = 0;
    var attempt = 0;

    while (true) {
      try {
        final req = http.Request('GET', Uri.parse(url));
        if (have > 0) req.headers['range'] = 'bytes=$have-';
        final resp = await _client.send(req);

        if (resp.statusCode == 200) {
          have = 0;
          total = resp.contentLength ?? 0;
          if (await part.exists()) await part.delete();
        } else if (resp.statusCode == 206) {
          total = _parseTotal(resp.headers['content-range']) ??
              (resp.contentLength != null ? have + resp.contentLength! : total);
        } else {
          throw HttpException('status ${resp.statusCode}');
        }

        final sink =
            part.openWrite(mode: have > 0 ? FileMode.append : FileMode.write);
        final sw = Stopwatch()..start();
        var sinceBytes = 0;
        try {
          await for (final chunk in resp.stream) {
            sink.add(chunk);
            have += chunk.length;
            sinceBytes += chunk.length;
            if (sw.elapsedMilliseconds >= 500) {
              final bps = (sinceBytes * 1000 / sw.elapsedMilliseconds).round();
              onProgress?.call(DownloadProgress(
                  haveBytes: have, totalBytes: total, bps: bps, complete: false));
              sw.reset();
              sinceBytes = 0;
            }
          }
        } finally {
          await sink.close();
        }

        if (total == 0 || have >= total) {
          await part.rename(done.path);
          onProgress?.call(DownloadProgress(
              haveBytes: have,
              totalBytes: total == 0 ? have : total,
              bps: 0,
              complete: true));
          return done;
        }
        throw HttpException('incomplete $have/$total');
      } catch (e) {
        attempt++;
        if (attempt > maxRetries) rethrow;
        await Future<void>.delayed(_backoff(attempt));
        have = await part.exists() ? await part.length() : 0;
      }
    }
  }

  void close() => _client.close();
}

Duration _backoff(int attempt) {
  final base = min(8000, 200 * (1 << (attempt - 1)));
  final jitter = Random().nextInt(250);
  return Duration(milliseconds: base + jitter);
}

int? _parseTotal(String? contentRange) {
  if (contentRange == null) return null;
  final slash = contentRange.lastIndexOf('/');
  if (slash < 0) return null;
  final tail = contentRange.substring(slash + 1).trim();
  if (tail == '*') return null;
  return int.tryParse(tail);
}
