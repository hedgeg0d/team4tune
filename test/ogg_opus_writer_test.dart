import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:team4tune/src/ogg_opus_writer.dart';

int _u32le(Uint8List b, int o) =>
    b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24);

bool _hasAt(Uint8List haystack, String needle, int offset) {
  final n = ascii.encode(needle);
  for (var i = 0; i < n.length; i++) {
    if (haystack[offset + i] != n[i]) return false;
  }
  return true;
}

void main() {
  test('produces a valid Ogg/Opus stream', () {
    final w = OggOpusWriter(channels: 2, serial: 42);
    w.addPacket(Uint8List.fromList([1, 2, 3, 4]), 960);
    w.addPacket(Uint8List.fromList(List.filled(300, 7)), 960);
    final bytes = w.build();

    expect(_hasAt(bytes, 'OggS', 0), isTrue);
    expect(bytes[5], 0x02, reason: 'first page must be BOS');
    expect(_hasAt(bytes, 'OpusHead', 28), isTrue);

    var pageCount = 0;
    var sawTags = false;
    var lastHeaderType = -1;
    for (var i = 0; i + 4 <= bytes.length; i++) {
      if (_hasAt(bytes, 'OggS', i)) {
        pageCount++;
        lastHeaderType = bytes[i + 5];
        final segCount = bytes[i + 26];
        final dataStart = i + 27 + segCount;
        if (dataStart + 8 <= bytes.length && _hasAt(bytes, 'OpusTags', dataStart)) {
          sawTags = true;
        }
      }
    }
    expect(pageCount, 4, reason: 'head + tags + 2 audio pages');
    expect(sawTags, isTrue);
    expect(lastHeaderType, 0x04, reason: 'last page must be EOS');
  });

  test('embedded CRC matches recomputation', () {
    final w = OggOpusWriter(channels: 1, serial: 7);
    w.addPacket(Uint8List.fromList([9, 8, 7]), 960);
    final bytes = w.build();

    var i = 0;
    while (i + 27 <= bytes.length) {
      expect(_hasAt(bytes, 'OggS', i), isTrue);
      final segCount = bytes[i + 26];
      final pageLen = 27 + segCount + _lacingSum(bytes, i + 27, segCount);
      final page = Uint8List.sublistView(bytes, i, i + pageLen);
      final stored = _u32le(page, 22);
      final zeroed = Uint8List.fromList(page);
      zeroed[22] = zeroed[23] = zeroed[24] = zeroed[25] = 0;
      expect(oggCrc32(zeroed), stored);
      i += pageLen;
    }
  });
}

int _lacingSum(Uint8List b, int o, int count) {
  var sum = 0;
  for (var k = 0; k < count; k++) {
    sum += b[o + k];
  }
  return sum;
}
