import 'dart:convert';

const typeCreate = 'create';
const typeJoin = 'join';
const typeEnqueue = 'enqueue';
const typeSkip = 'skip';
const typeRemove = 'remove';
const typeControl = 'control';
const typeSetSettings = 'set_settings';
const typeReady = 'ready';
const typeProgress = 'progress';
const typeBye = 'bye';
const typePing = 'ping';
const typeRtc = 'rtc';

const rtcJoin = 'join';
const rtcOffer = 'offer';
const rtcAnswer = 'answer';
const rtcIce = 'ice';

const typeRoomState = 'room_state';
const typeNowPlaying = 'now_playing';
const typePrepare = 'prepare';
const typePong = 'pong';
const typeError = 'error';

const modeSignal = 'signal';
const modeStream = 'stream';

const policyEveryone = 'everyone';
const policyHost = 'host';

const syncResponsive = 'responsive';
const syncTight = 'tight';

const scopeEnqueue = 'enqueue';
const scopeSkip = 'skip';
const scopeRemove = 'remove';
const scopeControl = 'control';

const controlPause = 'pause';
const controlResume = 'resume';
const controlSeek = 'seek';

const memLimitMinMb = 2;
const memLimitMaxMb = 100;
const memLimitDefaultMb = 50;

const streamBitrateMinKbps = 16;
const streamBitrateMaxKbps = 256;
const streamBitrateDefaultKbps = 64;

class RoomSettings {
  const RoomSettings({
    this.enqueue = policyEveryone,
    this.skip = policyEveryone,
    this.remove = policyEveryone,
    this.control = policyEveryone,
    this.sync = syncResponsive,
    this.memLimitMb = memLimitDefaultMb,
    this.streamBitrateKbps = streamBitrateDefaultKbps,
  });

  final String enqueue;
  final String skip;
  final String remove;
  final String control;
  final String sync;
  final int memLimitMb;
  final int streamBitrateKbps;

  String policyFor(String scope) {
    switch (scope) {
      case scopeEnqueue:
        return enqueue;
      case scopeSkip:
        return skip;
      case scopeRemove:
        return remove;
      case scopeControl:
        return control;
      default:
        return policyHost;
    }
  }

  RoomSettings copyWith({
    String? enqueue,
    String? skip,
    String? remove,
    String? control,
    String? sync,
    int? memLimitMb,
    int? streamBitrateKbps,
  }) {
    return RoomSettings(
      enqueue: enqueue ?? this.enqueue,
      skip: skip ?? this.skip,
      remove: remove ?? this.remove,
      control: control ?? this.control,
      sync: sync ?? this.sync,
      memLimitMb: memLimitMb ?? this.memLimitMb,
      streamBitrateKbps: streamBitrateKbps ?? this.streamBitrateKbps,
    );
  }

  Map<String, dynamic> toJson() => {
        'enqueue': enqueue,
        'skip': skip,
        'remove': remove,
        'control': control,
        'sync': sync,
        'memLimitMb': memLimitMb,
        'streamBitrateKbps': streamBitrateKbps,
      };

  static RoomSettings fromJson(Map<String, dynamic>? j) {
    if (j == null) return const RoomSettings();
    return RoomSettings(
      enqueue: j['enqueue'] as String? ?? policyEveryone,
      skip: j['skip'] as String? ?? policyEveryone,
      remove: j['remove'] as String? ?? policyEveryone,
      control: j['control'] as String? ?? policyEveryone,
      sync: j['sync'] as String? ?? syncResponsive,
      memLimitMb: (j['memLimitMb'] as num?)?.toInt() ?? memLimitDefaultMb,
      streamBitrateKbps:
          (j['streamBitrateKbps'] as num?)?.toInt() ?? streamBitrateDefaultKbps,
    );
  }
}

class Envelope {
  Envelope(this.type, this.data);

  final String type;
  final Map<String, dynamic>? data;

  static Envelope decode(String raw) {
    final obj = jsonDecode(raw) as Map<String, dynamic>;
    final data = obj['data'];
    return Envelope(
      obj['type'] as String,
      data == null ? null : (data as Map<String, dynamic>),
    );
  }

  String encode() => jsonEncode({'type': type, if (data != null) 'data': data});
}

class Health {
  const Health({
    this.confidence = 0,
    this.bufferedMs = 0,
    this.bps = 0,
    this.ready = false,
  });

  final int confidence;
  final int bufferedMs;
  final int bps;
  final bool ready;

  static Health? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    return Health(
      confidence: (j['confidence'] as num?)?.toInt() ?? 0,
      bufferedMs: (j['bufferedMs'] as num?)?.toInt() ?? 0,
      bps: (j['bps'] as num?)?.toInt() ?? 0,
      ready: j['ready'] as bool? ?? false,
    );
  }
}

class Member {
  Member(this.id, this.nick, {this.health});

  final String id;
  final String nick;
  final Health? health;

  static Member fromJson(Map<String, dynamic> j) => Member(
        j['id'] as String? ?? '',
        j['nick'] as String? ?? '',
        health: Health.fromJson(j['health'] as Map<String, dynamic>?),
      );
}

class Track {
  Track({
    required this.id,
    required this.sourceUrl,
    required this.status,
    this.title,
    this.fileUrl,
    this.durationMs,
  });

  final String id;
  final String sourceUrl;
  final String status;
  final String? title;
  final String? fileUrl;
  final int? durationMs;

  static Track fromJson(Map<String, dynamic> j) => Track(
        id: j['id'] as String? ?? '',
        sourceUrl: j['sourceUrl'] as String? ?? '',
        status: j['status'] as String? ?? '',
        title: j['title'] as String?,
        fileUrl: j['fileUrl'] as String?,
        durationMs: j['durationMs'] as int?,
      );
}

class RoomState {
  RoomState({
    required this.roomCode,
    required this.mode,
    required this.selfId,
    required this.hostId,
    required this.settings,
    required this.members,
    required this.queue,
    this.playingTrackId = '',
    this.udpPort = 0,
    this.resumeToken = '',
  });

  final String roomCode;
  final String mode;
  final String selfId;
  final String hostId;
  final RoomSettings settings;
  final List<Member> members;
  final List<Track> queue;
  final String playingTrackId;
  final int udpPort;
  final String resumeToken;

  bool get isSelfHost => selfId.isNotEmpty && selfId == hostId;

  static RoomState fromJson(Map<String, dynamic> j) => RoomState(
        roomCode: j['roomCode'] as String? ?? '',
        mode: j['mode'] as String? ?? modeSignal,
        selfId: j['selfId'] as String? ?? '',
        hostId: j['hostId'] as String? ?? '',
        settings: RoomSettings.fromJson(j['settings'] as Map<String, dynamic>?),
        members: ((j['members'] as List?) ?? [])
            .map((m) => Member.fromJson(m as Map<String, dynamic>))
            .toList(),
        queue: ((j['queue'] as List?) ?? [])
            .map((t) => Track.fromJson(t as Map<String, dynamic>))
            .toList(),
        playingTrackId: j['playingTrackId'] as String? ?? '',
        udpPort: (j['udpPort'] as num?)?.toInt() ?? 0,
        resumeToken: j['resumeToken'] as String? ?? '',
      );
}
