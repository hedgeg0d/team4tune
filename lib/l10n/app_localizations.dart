import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('ru'),
  ];

  /// No description provided for @appSubtitle.
  ///
  /// In en, this message translates to:
  /// **'listen together, in sync'**
  String get appSubtitle;

  /// No description provided for @nicknamePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Nickname'**
  String get nicknamePlaceholder;

  /// No description provided for @createRoomTitle.
  ///
  /// In en, this message translates to:
  /// **'Create a room'**
  String get createRoomTitle;

  /// No description provided for @createRoomSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick how audio travels to everyone.'**
  String get createRoomSubtitle;

  /// No description provided for @modeSignalLabel.
  ///
  /// In en, this message translates to:
  /// **'signal'**
  String get modeSignalLabel;

  /// No description provided for @modeStreamLabel.
  ///
  /// In en, this message translates to:
  /// **'stream'**
  String get modeStreamLabel;

  /// No description provided for @createRoomButton.
  ///
  /// In en, this message translates to:
  /// **'Create room'**
  String get createRoomButton;

  /// No description provided for @joinRoomTitle.
  ///
  /// In en, this message translates to:
  /// **'Join a room'**
  String get joinRoomTitle;

  /// No description provided for @roomCodePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Room code'**
  String get roomCodePlaceholder;

  /// No description provided for @joinRoomButton.
  ///
  /// In en, this message translates to:
  /// **'Join room'**
  String get joinRoomButton;

  /// No description provided for @serverSettings.
  ///
  /// In en, this message translates to:
  /// **'Server settings'**
  String get serverSettings;

  /// No description provided for @serverLabel.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get serverLabel;

  /// No description provided for @roomTitle.
  ///
  /// In en, this message translates to:
  /// **'Room'**
  String get roomTitle;

  /// No description provided for @roomCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Room code copied'**
  String get roomCodeCopied;

  /// No description provided for @syncTuningTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sync tuning'**
  String get syncTuningTooltip;

  /// No description provided for @roomSettingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Room settings'**
  String get roomSettingsTooltip;

  /// No description provided for @leaveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leaveTooltip;

  /// No description provided for @reconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting…'**
  String get reconnecting;

  /// No description provided for @pasteTrackUrl.
  ///
  /// In en, this message translates to:
  /// **'Paste a track URL'**
  String get pasteTrackUrl;

  /// No description provided for @onlyHostCanAdd.
  ///
  /// In en, this message translates to:
  /// **'Only the host can add tracks'**
  String get onlyHostCanAdd;

  /// No description provided for @queueLabel.
  ///
  /// In en, this message translates to:
  /// **'Queue · {count}'**
  String queueLabel(int count);

  /// No description provided for @queueEmpty.
  ///
  /// In en, this message translates to:
  /// **'Queue is empty'**
  String get queueEmpty;

  /// No description provided for @removeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeTooltip;

  /// No description provided for @nowPlaying.
  ///
  /// In en, this message translates to:
  /// **'NOW PLAYING'**
  String get nowPlaying;

  /// No description provided for @clockSyncing.
  ///
  /// In en, this message translates to:
  /// **'syncing…'**
  String get clockSyncing;

  /// No description provided for @syncTuningTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync tuning'**
  String get syncTuningTitle;

  /// No description provided for @syncTuningDescription.
  ///
  /// In en, this message translates to:
  /// **'How hard this device speeds up to catch up. Higher converges faster but is more audible. Hard seeks only on big desync.'**
  String get syncTuningDescription;

  /// No description provided for @maxCatchup.
  ///
  /// In en, this message translates to:
  /// **'Max catch-up'**
  String get maxCatchup;

  /// No description provided for @syncGentle.
  ///
  /// In en, this message translates to:
  /// **'Gentle'**
  String get syncGentle;

  /// No description provided for @syncAggressive.
  ///
  /// In en, this message translates to:
  /// **'Aggressive'**
  String get syncAggressive;

  /// No description provided for @roomPermissions.
  ///
  /// In en, this message translates to:
  /// **'Room permissions'**
  String get roomPermissions;

  /// No description provided for @roomPermissionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose who can do what in this room.'**
  String get roomPermissionsSubtitle;

  /// No description provided for @permAddTracks.
  ///
  /// In en, this message translates to:
  /// **'Add tracks'**
  String get permAddTracks;

  /// No description provided for @permSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get permSkip;

  /// No description provided for @permRemoveTracks.
  ///
  /// In en, this message translates to:
  /// **'Remove tracks'**
  String get permRemoveTracks;

  /// No description provided for @permControlPlayback.
  ///
  /// In en, this message translates to:
  /// **'Control playback'**
  String get permControlPlayback;

  /// No description provided for @syncMode.
  ///
  /// In en, this message translates to:
  /// **'Sync mode'**
  String get syncMode;

  /// No description provided for @syncModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Start fast for ready listeners, or wait for everyone'**
  String get syncModeDescription;

  /// No description provided for @syncResponsiveLabel.
  ///
  /// In en, this message translates to:
  /// **'Responsive'**
  String get syncResponsiveLabel;

  /// No description provided for @syncTightLabel.
  ///
  /// In en, this message translates to:
  /// **'Tight'**
  String get syncTightLabel;

  /// No description provided for @policyEveryone.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get policyEveryone;

  /// No description provided for @policyHost.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get policyHost;

  /// No description provided for @sharedTrackAdded.
  ///
  /// In en, this message translates to:
  /// **'Added to queue'**
  String get sharedTrackAdded;

  /// No description provided for @sharedTrackPending.
  ///
  /// In en, this message translates to:
  /// **'Link saved — join a room to add it'**
  String get sharedTrackPending;

  /// No description provided for @uploadTrackTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add a local audio file'**
  String get uploadTrackTooltip;

  /// No description provided for @encodingTrack.
  ///
  /// In en, this message translates to:
  /// **'Encoding…'**
  String get encodingTrack;

  /// No description provided for @uploadingTrack.
  ///
  /// In en, this message translates to:
  /// **'Uploading…'**
  String get uploadingTrack;

  /// No description provided for @uploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed'**
  String get uploadFailed;

  /// No description provided for @listeningLabel.
  ///
  /// In en, this message translates to:
  /// **'LISTENING'**
  String get listeningLabel;

  /// No description provided for @memberYou.
  ///
  /// In en, this message translates to:
  /// **'{nick} (you)'**
  String memberYou(String nick);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
