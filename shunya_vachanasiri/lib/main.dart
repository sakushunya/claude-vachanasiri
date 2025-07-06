// /lib/main.dart
import 'dart:developer' as developer;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audio_session/audio_session.dart';
import 'package:audio_service/audio_service.dart';
import 'package:shunya_vachanasiri/firebase_options.dart';
import 'package:shunya_vachanasiri/providers/app_state.dart';
import 'package:shunya_vachanasiri/providers/audio_handler.dart';
import 'package:shunya_vachanasiri/providers/audio_service_manager.dart';
import 'package:shunya_vachanasiri/services/auth_service.dart';
import 'package:shunya_vachanasiri/screens/splash_screen.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    context.read<AudioPlayerHandler>().dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh lock screen metadata when app returns from background
      AudioServiceManager.handler.updateMetadataForCurrentTrack();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VachanaSiri',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Poppins',
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure audio session
  // final session = await AudioSession.instance;
  // // await session.configure(const AudioSessionConfiguration.music());
  // await session.configure(const AudioSessionConfiguration(
  //   avAudioSessionCategory: AVAudioSessionCategory.playback,
  //   avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.allowBluetooth,
  //   //AVAudioSessionCategoryOptions.allowBluetoothA2dp, // use this later if above does not work
  //   avAudioSessionMode: AVAudioSessionMode.defaultMode,
  //   avAudioSessionRouteSharingPolicy:
  //       AVAudioSessionRouteSharingPolicy.defaultPolicy,
  //   androidAudioAttributes: AndroidAudioAttributes(
  //     contentType: AndroidAudioContentType.music,
  //     usage: AndroidAudioUsage.media,
  //     flags: AndroidAudioFlags.none,
  //   ),
  //   androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
  //   androidWillPauseWhenDucked: true,
  // ));

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await AuthService.ensureAuthenticated();

  final appState = AppState();
  await appState.initialize();

  // Initialize audio service
  final audioHandler = await AudioService.init(
    builder: () => AudioPlayerHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.shunya.vachanasiri.channel.audio',
      androidNotificationChannelName: 'Vachana Siri Audio',
      androidNotificationIcon: 'mipmap/ic_launcher',
      androidStopForegroundOnPause: true,
      androidNotificationOngoing: true,
      notificationColor: Colors.blue,
    ),
  );

// In main() after AudioService.init
  AudioService.customEventStream.listen((event) {
    developer.log('AudioService custom event: $event', name: 'Main');
  });

  AudioService.playbackStateStream.listen((state) {
    developer.log('AudioService playback state: $state', name: 'Main');
  });

  AudioService.currentMediaItemStream.listen((item) {
    developer.log('AudioService media item: ${item?.title}', name: 'Main');
  });

  // Set handler
  AudioServiceManager.setHandler(audioHandler as AudioPlayerHandler);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appState),
        Provider<AudioPlayerHandler>.value(value: audioHandler),
        StreamProvider<MediaItem?>(
          create: (context) => AudioService.currentMediaItemStream,
          initialData: null,
        ),
        StreamProvider<PlaybackState>(
          create: (context) => AudioService.playbackStateStream,
          initialData: PlaybackState(
            controls: const [],
            systemActions: const {},
            androidCompactActionIndices: const [],
            processingState: AudioProcessingState.idle,
            playing: false,
            updatePosition: Duration.zero,
            updateTime: DateTime.now(),
            queueIndex: 0,
          ),
        ),
      ],
      child: const MyApp(),
    ),
  );

  // Monitor connectivity
  final connectivity = Connectivity();
  connectivity.onConnectivityChanged.listen((status) {
    if (status != ConnectivityResult.none) {
      appState.refreshData();
    }
  });
}

// import 'package:firebase_core/firebase_core.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:audio_session/audio_session.dart';
// import 'package:audio_service/audio_service.dart';
// import 'package:shunya_vachanasiri/firebase_options.dart';
// import 'package:shunya_vachanasiri/providers/app_state.dart';
// import 'package:shunya_vachanasiri/providers/audio_handler.dart';
// import 'package:shunya_vachanasiri/services/auth_service.dart';
// import 'package:shunya_vachanasiri/screens/splash_screen.dart';

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp(
//     options: DefaultFirebaseOptions.currentPlatform,
//   );

//   await AuthService.ensureAuthenticated();

//   await configureAudioSession();

//   final appState = AppState();
//   await appState.initialize();

//   // Initialize audio service with the correct handler
//   await AudioService.init(
//     builder: () => AudioPlayerHandler(),
//     config: const AudioServiceConfig(
//       androidNotificationChannelId: 'com.yourcompany.audio',
//       androidNotificationChannelName: 'Vachana Playback',
//       androidNotificationOngoing: true,
//       androidStopForegroundOnPause: true,
//     ),
//   );

//   runApp(
//     MultiProvider(
//       providers: [
//         ChangeNotifierProvider(create: (context) => appState),
//         // ChangeNotifierProvider(create: (context) => AudioPlayerService()),
//       ],
//       child: const MyApp(),
//     ),
//   );
// }
