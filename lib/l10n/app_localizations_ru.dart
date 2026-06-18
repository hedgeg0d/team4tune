// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appSubtitle => 'слушайте вместе, в синхроне';

  @override
  String get nicknamePlaceholder => 'Никнейм';

  @override
  String get createRoomTitle => 'Создать комнату';

  @override
  String get createRoomSubtitle => 'Выберите способ передачи звука.';

  @override
  String get modeSignalLabel => 'сигнал';

  @override
  String get modeStreamLabel => 'стрим';

  @override
  String get createRoomButton => 'Создать комнату';

  @override
  String get joinRoomTitle => 'Войти в комнату';

  @override
  String get roomCodePlaceholder => 'Код комнаты';

  @override
  String get joinRoomButton => 'Войти';

  @override
  String get serverSettings => 'Настройки сервера';

  @override
  String get serverLabel => 'Сервер';

  @override
  String get roomTitle => 'Комната';

  @override
  String get roomCodeCopied => 'Код комнаты скопирован';

  @override
  String get syncTuningTooltip => 'Настройка синхронизации';

  @override
  String get roomSettingsTooltip => 'Настройки комнаты';

  @override
  String get leaveTooltip => 'Выйти';

  @override
  String get reconnecting => 'Переподключение…';

  @override
  String get pasteTrackUrl => 'Вставьте URL трека';

  @override
  String get onlyHostCanAdd => 'Только хост может добавлять треки';

  @override
  String queueLabel(int count) {
    return 'Очередь · $count';
  }

  @override
  String get queueEmpty => 'Очередь пуста';

  @override
  String get removeTooltip => 'Удалить';

  @override
  String get nowPlaying => 'СЕЙЧАС ИГРАЕТ';

  @override
  String get clockSyncing => 'синхронизация…';

  @override
  String get syncTuningTitle => 'Настройка синхронизации';

  @override
  String get syncTuningDescription =>
      'Насколько сильно устройство ускоряется для догонки. Выше — быстрее, но заметнее. Жёсткий переход только при большом рассинхроне.';

  @override
  String get maxCatchup => 'Макс. ускорение';

  @override
  String get syncGentle => 'Мягко';

  @override
  String get syncAggressive => 'Агрессивно';

  @override
  String get roomPermissions => 'Права в комнате';

  @override
  String get roomPermissionsSubtitle => 'Кто что может делать в этой комнате.';

  @override
  String get permAddTracks => 'Добавлять треки';

  @override
  String get permSkip => 'Пропустить';

  @override
  String get permRemoveTracks => 'Удалять треки';

  @override
  String get permControlPlayback => 'Управлять воспроизведением';

  @override
  String get syncMode => 'Режим синхронизации';

  @override
  String get syncModeDescription =>
      'Быстрый старт или ожидание всех участников';

  @override
  String get syncResponsiveLabel => 'Отзывчивый';

  @override
  String get syncTightLabel => 'Строгий';

  @override
  String get cacheLimit => 'Лимит кеша';

  @override
  String get cacheLimitDescription =>
      'Сколько аудио сервер держит скачанным целиком для мгновенной перемотки. Длинные треки сверх лимита стримятся по частям.';

  @override
  String cacheLimitValue(int mb) {
    return '$mb МБ';
  }

  @override
  String get policyEveryone => 'Все';

  @override
  String get policyHost => 'Хост';

  @override
  String get sharedTrackAdded => 'Добавлено в очередь';

  @override
  String get sharedTrackPending =>
      'Ссылка сохранена — войдите в комнату, чтобы добавить';

  @override
  String get uploadTrackTooltip => 'Добавить локальный аудиофайл';

  @override
  String get encodingTrack => 'Кодирование…';

  @override
  String get uploadingTrack => 'Загрузка…';

  @override
  String get uploadFailed => 'Не удалось загрузить';

  @override
  String get listeningLabel => 'СЛУШАЮТ';

  @override
  String memberYou(String nick) {
    return '$nick (вы)';
  }
}
