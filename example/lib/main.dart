import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'controllers/audio_controller.dart';
import 'controllers/local_audio_controller.dart';
import 'controllers/recordings_controller.dart';
import 'screens/home_screen.dart';
import 'screens/local_files_screen.dart';
import 'screens/recordings_screen.dart';
import 'examples/advanced_player_example.dart';
import 'examples/playlist_example.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';

  @override
  void initState() {
    super.initState();
    _initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> _initPlatformState() async {
    String platformVersion;
    try {
      platformVersion = defaultTargetPlatform.toString();

      // Request storage permissions at startup
      await _requestPermissions();
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  // Request necessary permissions
  Future<void> _requestPermissions() async {
    // Request storage permission
    var storageStatus = await Permission.storage.request();

    // For Android 11+, also request manage external storage permission
    if (defaultTargetPlatform == TargetPlatform.android) {
      var externalStatus = await Permission.manageExternalStorage.request();

      // Log permission status
      debugPrint('Storage permission: $storageStatus');
      debugPrint('External storage permission: $externalStatus');
    }

    // Request notification permission for background playback
    await Permission.notification.request();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AudioController()),
        ChangeNotifierProvider(create: (_) => LocalAudioController()),
        ChangeNotifierProvider(create: (_) => RecordingsController()),
      ],
      // Force rebuild when any provider changes
      builder: (context, child) {
        debugPrint('Main app rebuilding due to provider change');
        return child!;
      },
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.createTheme(),
        initialRoute: '/',
        routes: {
          '/': (context) => HomeScreen(platformVersion: _platformVersion),
          '/local_files': (context) => const LocalFilesScreen(),
          '/recordings': (context) => const RecordingsScreen(),
          '/advanced_player': (context) => const AdvancedPlayerExample(),
          '/playlist': (context) => const PlaylistExample(),
        },
      ),
    );
  }
}
