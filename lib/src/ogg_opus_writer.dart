import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

class OggOpusWriter {
  OggOpusWriter({required this.channels, this.preSkip = 312, int? serial})
      : _serial = serial ?? Random().nextInt(0x7fffffff);

  final int channels;
  final int preSkip;
  final int _serial;
  final List<Uint8List> _packets = [];
  final List<int> _samples = [];

  void addPacket(Uint8List packet, int samplesPerChannel) {
    _packets.add(packet);
    _samples.add(samplesPerChannel);
  }

  Uint8List build() {
    final out = BytesBuilder();
    var seq = 0;
    out.add(_page(_opusHead(), headerType: 0x02, granule: 0, seq: seq++));
    out.add(_page(_opusTags(), headerType: 0x00, granule: 0, seq: seq++));
    var granule = preSkip;
    for (var i = 0; i < _packets.length; i++) {
      granule += _samples[i];
      final last = i == _packets.length - 1;
      out.add(_page(
        _packets[i],
        headerType: last ? 0x04 : 0x00,
        granule: granule,
        seq: seq++,
      ));
    }
    return out.toBytes();
  }

  Uint8List _opusHead() {
    final b = BytesBuilder();
    b.add(ascii.encode('OpusHead'));
    b.addByte(1);
    b.addByte(channels);
    b.add(_u16le(preSkip));
    b.add(_u32le(48000));
    b.add(_u16le(0));
    b.addByte(0);
    return b.toBytes();
  }

  Uint8List _opusTags() {
    final vendor = ascii.encode('team4tune');
    final b = BytesBuilder();
    b.add(ascii.encode('OpusTags'));
    b.add(_u32le(vendor.length));
    b.add(vendor);
    b.add(_u32le(0));
    return b.toBytes();
  }

  Uint8List _page(
    Uint8List data, {
    required int headerType,
    required int granule,
    required int seq,
  }) {
    final segs = <int>[];
    var remaining = data.length;
    while (remaining >= 255) {
      segs.add(255);
      remaining -= 255;
    }
    segs.add(remaining);

    final page = BytesBuilder();
    page.add(ascii.encode('OggS'));
    page.addByte(0);
    page.addByte(headerType);
    page.add(_u64le(granule));
    page.add(_u32le(_serial));
    page.add(_u32le(seq));
    page.add(_u32le(0));
    page.addByte(segs.length);
    page.add(Uint8List.fromList(segs));
    page.add(data);

    final bytes = page.toBytes();
    final crc = oggCrc32(bytes);
    bytes[22] = crc & 0xff;
    bytes[23] = (crc >> 8) & 0xff;
    bytes[24] = (crc >> 16) & 0xff;
    bytes[25] = (crc >> 24) & 0xff;
    return bytes;
  }

  static Uint8List _u16le(int v) =>
      Uint8List(2)..buffer.asByteData().setUint16(0, v, Endian.little);

  static Uint8List _u32le(int v) =>
      Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little);

  static Uint8List _u64le(int v) =>
      Uint8List(8)..buffer.asByteData().setUint64(0, v, Endian.little);
}

final Uint32List _crcTable = _buildCrcTable();

Uint32List _buildCrcTable() {
  final table = Uint32List(256);
  for (var i = 0; i < 256; i++) {
    var r = i << 24;
    for (var j = 0; j < 8; j++) {
      r = (r & 0x80000000) != 0 ? (r << 1) ^ 0x04c11db7 : r << 1;
    }
    table[i] = r & 0xffffffff;
  }
  return table;
}

int oggCrc32(Uint8List data) {
  var crc = 0;
  for (final byte in data) {
    crc = ((crc << 8) & 0xffffffff) ^ _crcTable[((crc >> 24) & 0xff) ^ byte];
  }
  return crc & 0xffffffff;
}
