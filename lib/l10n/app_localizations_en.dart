// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appSubtitle => 'listen together, in sync';

  @override
  String get nicknamePlaceholder => 'Nickname';

  @override
  String get createRoomTitle => 'Create a room';

  @override
  String get createRoomSubtitle => 'Pick how audio travels to everyone.';

  @override
  String get modeSignalLabel => 'signal';

  @override
  String get modeStreamLabel => 'stream';

  @override
  String get createRoomButton => 'Create room';

  @override
  String get joinRoomTitle => 'Join a room';

  @override
  String get roomCodePlaceholder => 'Room code';

  @override
  String get joinRoomButton => 'Join room';

  @override
  String get serverSettings => 'Server settings';

  @override
  String get serverLabel => 'Server';

  @override
  String get roomTitle => 'Room';

  @override
  String get roomCodeCopied => 'Room code copied';

  @override
  String get syncTuningTooltip => 'Sync tuning';

  @override
  String get roomSettingsTooltip => 'Room settings';

  @override
  String get leaveTooltip => 'Leave';

  @override
  String get reconnecting => 'Reconnecting…';

  @override
  String get pasteTrackUrl => 'Paste a track URL';

  @override
  String get onlyHostCanAdd => 'Only the host can add tracks';

  @override
  String queueLabel(int count) {
    return 'Queue · $count';
  }

  @override
  String get queueEmpty => 'Queue is empty';

  @override
  String get removeTooltip => 'Remove';

  @override
  String get nowPlaying => 'NOW PLAYING';

  @override
  String get clockSyncing => 'syncing…';

  @override
  String get syncTuningTitle => 'Sync tuning';

  @override
  String get syncTuningDescription =>
      'How hard this device speeds up to catch up. Higher converges faster but is more audible. Hard seeks only on big desync.';

  @override
  String get maxCatchup => 'Max catch-up';

  @override
  String get syncGentle => 'Gentle';

  @override
  String get syncAggressive => 'Aggressive';

  @override
  String get roomPermissions => 'Room permissions';

  @override
  String get roomPermissionsSubtitle => 'Choose who can do what in this room.';

  @override
  String get permAddTracks => 'Add tracks';

  @override
  String get permSkip => 'Skip';

  @override
  String get permRemoveTracks => 'Remove tracks';

  @override
  String get permControlPlayback => 'Control playback';

  @override
  String get syncMode => 'Sync mode';

  @override
  String get syncModeDescription =>
      'Start fast for ready listeners, or wait for everyone';

  @override
  String get syncResponsiveLabel => 'Responsive';

  @override
  String get syncTightLabel => 'Tight';

  @override
  String get cacheLimit => 'Cache limit';

  @override
  String get cacheLimitDescription =>
      'How much audio the server keeps fully downloaded for instant seeking. Longer tracks beyond the budget stream on demand.';

  @override
  String cacheLimitValue(int mb) {
    return '$mb MB';
  }

  @override
  String get streamBitrate => 'Stream bitrate';

  @override
  String get streamBitrateDescription =>
      'Opus quality the server broadcasts to everyone in stream mode. Higher sounds better but needs more bandwidth. Applies to the next track.';

  @override
  String streamBitrateValue(int kbps) {
    return '$kbps kbps';
  }

  @override
  String get policyEveryone => 'Everyone';

  @override
  String get policyHost => 'Host';

  @override
  String get sharedTrackAdded => 'Added to queue';

  @override
  String get sharedTrackPending => 'Link saved — join a room to add it';

  @override
  String get uploadTrackTooltip => 'Add a local audio file';

  @override
  String get encodingTrack => 'Encoding…';

  @override
  String get uploadingTrack => 'Uploading…';

  @override
  String get uploadFailed => 'Upload failed';

  @override
  String get listeningLabel => 'LISTENING';

  @override
  String memberYou(String nick) {
    return '$nick (you)';
  }
}
