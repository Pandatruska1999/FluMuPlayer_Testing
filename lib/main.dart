import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'screens/player_screen.dart';
import 'services/native_audio_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await windowManager.ensureInitialized();
  WindowOptions windowOptions = const WindowOptions(
    size: Size(900, 650),
    minimumSize: Size(700, 500),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
  );
  
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  testAudioPlugin();

  runApp(const MusicPlayerApp());
}



void testAudioPlugin() {
  // Test if native audio plugin is working
  try {
    NativeAudioHandler.initialize().then((success) {
      print('Native audio init: $success');
      
      // Test spatial parameters
      NativeAudioHandler.updateSpatialParameters(
        'test_track',
        0.5,  // x
        0.2,  // y  
        0.7,  // z
        0.8,  // volume
      ).then((success) {
        print('Spatial params update: $success');
      });
    });
  } catch (e) {
    print('Audio plugin test failed: $e');
  }
}

class MusicPlayerApp extends StatelessWidget {
  const MusicPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Production Sheet',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      home: const PlayerScreen(),
    );
  }
}