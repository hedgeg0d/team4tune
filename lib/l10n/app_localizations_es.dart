// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appSubtitle => 'escucha juntos, sincronizados';

  @override
  String get nicknamePlaceholder => 'Apodo';

  @override
  String get createRoomTitle => 'Crear una sala';

  @override
  String get createRoomSubtitle => 'Elige cómo se transmite el audio a todos.';

  @override
  String get modeSignalLabel => 'señal';

  @override
  String get modeStreamLabel => 'stream';

  @override
  String get createRoomButton => 'Crear sala';

  @override
  String get joinRoomTitle => 'Unirse a una sala';

  @override
  String get roomCodePlaceholder => 'Código de sala';

  @override
  String get joinRoomButton => 'Unirse';

  @override
  String get serverSettings => 'Configuración del servidor';

  @override
  String get serverLabel => 'Servidor';

  @override
  String get roomTitle => 'Sala';

  @override
  String get roomCodeCopied => 'Código de sala copiado';

  @override
  String get syncTuningTooltip => 'Ajuste de sincronización';

  @override
  String get roomSettingsTooltip => 'Configuración de sala';

  @override
  String get leaveTooltip => 'Salir';

  @override
  String get reconnecting => 'Reconectando…';

  @override
  String get pasteTrackUrl => 'Pega la URL de una pista';

  @override
  String get onlyHostCanAdd => 'Solo el anfitrión puede añadir pistas';

  @override
  String queueLabel(int count) {
    return 'Cola · $count';
  }

  @override
  String get queueEmpty => 'La cola está vacía';

  @override
  String get removeTooltip => 'Eliminar';

  @override
  String get nowPlaying => 'REPRODUCIENDO';

  @override
  String get clockSyncing => 'sincronizando…';

  @override
  String get syncTuningTitle => 'Ajuste de sincronización';

  @override
  String get syncTuningDescription =>
      'Qué tan fuerte se acelera este dispositivo para ponerse al día. Más alto converge más rápido pero es más audible. Salto duro solo en gran desincronización.';

  @override
  String get maxCatchup => 'Aceleración máxima';

  @override
  String get syncGentle => 'Suave';

  @override
  String get syncAggressive => 'Agresivo';

  @override
  String get roomPermissions => 'Permisos de la sala';

  @override
  String get roomPermissionsSubtitle =>
      'Elige quién puede hacer qué en esta sala.';

  @override
  String get permAddTracks => 'Añadir pistas';

  @override
  String get permSkip => 'Saltar';

  @override
  String get permRemoveTracks => 'Eliminar pistas';

  @override
  String get permControlPlayback => 'Controlar reproducción';

  @override
  String get syncMode => 'Modo de sincronización';

  @override
  String get syncModeDescription => 'Empieza rápido o espera a todos';

  @override
  String get syncResponsiveLabel => 'Receptivo';

  @override
  String get syncTightLabel => 'Estricto';

  @override
  String get cacheLimit => 'Límite de caché';

  @override
  String get cacheLimitDescription =>
      'Cuánto audio mantiene el servidor descargado por completo para saltar al instante. Las pistas largas que excedan el límite se transmiten bajo demanda.';

  @override
  String cacheLimitValue(int mb) {
    return '$mb MB';
  }

  @override
  String get streamBitrate => 'Bitrate de transmisión';

  @override
  String get streamBitrateDescription =>
      'Calidad de Opus que el servidor transmite a todos en modo transmisión. Más alto suena mejor pero usa más ancho de banda. Se aplica a la siguiente pista.';

  @override
  String streamBitrateValue(int kbps) {
    return '$kbps kbps';
  }

  @override
  String get policyEveryone => 'Todos';

  @override
  String get policyHost => 'Anfitrión';

  @override
  String get sharedTrackAdded => 'Añadido a la cola';

  @override
  String get sharedTrackPending =>
      'Enlace guardado — únete a una sala para añadirlo';

  @override
  String get uploadTrackTooltip => 'Añadir un archivo de audio local';

  @override
  String get encodingTrack => 'Codificando…';

  @override
  String get uploadingTrack => 'Subiendo…';

  @override
  String get uploadFailed => 'Error al subir';

  @override
  String get listeningLabel => 'ESCUCHANDO';

  @override
  String memberYou(String nick) {
    return '$nick (tú)';
  }
}
