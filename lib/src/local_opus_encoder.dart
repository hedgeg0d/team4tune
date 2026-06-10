import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audio_decoder/audio_decoder.dart';
import 'package:flutter_opus/flutter_opus.dart';
import 'package:path_provider/path_provider.dart';

import 'ogg_opus_writer.dart';

class EncodedTrack {
  EncodedTrack(this.path, this.title, this.durationMs);

  final String path;
  final String title;
  final int durationMs;
}

class LocalOpusEncoder {
  static const _rate = 48000;
  static const _channels = 2;
  static const _frame = 960;
  static const _bitrate = 128000;

  static Future<EncodedTrack> encodeFile(String inputPath) async {
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final wavPath = '${dir.path}/decode_$stamp.wav';
    await AudioDecoder.convertToWav(
      inputPath,
      wavPath,
      sampleRate: _rate,
      channels: _channels,
      bitDepth: 16,
    );
    final wavFile = File(wavPath);
    final wav = await wavFile.readAsBytes();
    unawaited(wavFile.delete().catchError((_) => wavFile));
    final dataOffset = _wavDataOffset(wav);
    final pcm = wav.buffer.asInt16List(
      wav.offsetInBytes + dataOffset,
      (wav.lengthInBytes - dataOffset) ~/ 2,
    );

    final encoder = OpusEncoder.create(sampleRate: _rate, channels: _channels);
    if (encoder == null) {
      throw StateError('opus encoder init failed');
    }
    encoder.setBitrate(_bitrate);
    encoder.setComplexity(10);

    final writer = OggOpusWriter(channels: _channels);
    final perFrame = _frame * _channels;
    var totalSamples = 0;
    try {
      for (var off = 0; off < pcm.length; off += perFrame) {
        final Int16List frame;
        if (off + perFrame <= pcm.length) {
          frame = Int16List.sublistView(pcm, off, off + perFrame);
        } else {
          frame = Int16List(perFrame)..setRange(0, pcm.length - off, pcm, off);
        }
        final packet = encoder.encode(frame, _frame);
        if (packet == null) continue;
        writer.addPacket(Uint8List.fromList(packet), _frame);
        totalSamples += _frame;
      }
    } finally {
      encoder.dispose();
    }

    final out = File('${dir.path}/upload_$stamp.opus');
    await out.writeAsBytes(writer.build(), flush: true);

    return EncodedTrack(
      out.path,
      _titleFromPath(inputPath),
      totalSamples * 1000 ~/ _rate,
    );
  }

  static int _wavDataOffset(Uint8List wav) {
    var i = 12;
    while (i + 8 <= wav.length) {
      final size = wav.buffer.asByteData().getUint32(wav.offsetInBytes + i + 4, Endian.little);
      if (wav[i] == 0x64 && wav[i + 1] == 0x61 && wav[i + 2] == 0x74 && wav[i + 3] == 0x61) {
        return i + 8;
      }
      i += 8 + size + (size & 1);
    }
    return 44;
  }

  static String _titleFromPath(String path) {
    var name = path.split('/').last;
    final dot = name.lastIndexOf('.');
    if (dot > 0) name = name.substring(0, dot);
    return name.isEmpty ? 'Local file' : name;
  }
}
