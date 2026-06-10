import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:permission_handler/permission_handler.dart';

import 'l10n/app_localizations.dart';

import 'src/room_controller.dart';
import 'src/screens/home_screen.dart';
import 'src/screens/room_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isLinux || Platform.isWindows) {
    JustAudioMediaKit.ensureInitialized();
  }
  if (Platform.isAndroid || Platform.isIOS) {
    await Permission.notification.request();
    await Permission.ignoreBatteryOptimizations.request();
    try {
      await JustAudioBackground.init(
        androidNotificationChannelId: 'com.team4tune.team4tune.playback',
        androidNotificationChannelName: 'Playback',
        androidNotificationIcon: 'drawable/notification_icon',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: false,
      );
    } catch (e, st) {
      debugPrint('JustAudioBackground.init failed: $e\n$st');
    }
  }
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
  ));
  runApp(ProviderScope(child: Team4tuneApp()));
}

const _seed = Color(0xFF6C4DF4);

class Team4tuneApp extends ConsumerWidget {
  Team4tuneApp({super.key});

  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inRoom = ref.watch(roomControllerProvider.select((s) => s.connected));

    ref.listen(roomControllerProvider.select((s) => s.noticeSeq), (_, _) {
      final notice = ref.read(roomControllerProvider).shareNotice;
      if (notice == null) return;
      final messenger = _messengerKey.currentState;
      if (messenger == null) return;
      final l10n = AppLocalizations.of(messenger.context)!;
      final text = switch (notice) {
        shareNoticeAdded => l10n.sharedTrackAdded,
        shareNoticePending => l10n.sharedTrackPending,
        uploadNoticeEncoding => l10n.encodingTrack,
        uploadNoticeUploading => l10n.uploadingTrack,
        uploadNoticeFailed => l10n.uploadFailed,
        _ => l10n.sharedTrackAdded,
      };
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(text)));
    });

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final light = lightDynamic?.harmonized() ??
            ColorScheme.fromSeed(seedColor: _seed);
        final dark = darkDynamic?.harmonized() ??
            ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.dark);

        return MaterialApp(
          title: 'team4tune',
          scaffoldMessengerKey: _messengerKey,
          debugShowCheckedModeBanner: false,
          theme: _themeFor(light),
          darkTheme: _themeFor(dark),
          themeMode: ThemeMode.system,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'),
            Locale('ru'),
            Locale('es'),
          ],
          home: inRoom ? const RoomScreen() : const HomeScreen(),
        );
      },
    );
  }
}

ThemeData _themeFor(ColorScheme scheme) {
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: scheme.surfaceTint,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    listTileTheme: const ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
  );
}
