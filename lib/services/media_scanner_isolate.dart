// media_scanner_isolate.dart
import 'dart:isolate';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/player_state.dart' as models;

class MediaScannerIsolate {
  static Future<List<models.Track>> scanDirectory(String directoryPath) async {
    final receivePort = ReceivePort();
    
    await Isolate.spawn(
      _scanDirectoryIsolate,
      _IsolateMessage(receivePort.sendPort, directoryPath),
    );

    return await receivePort.first as List<models.Track>;
  }

  static void _scanDirectoryIsolate(_IsolateMessage message) async {
    final List<models.Track> tracks = [];
    final directory = Directory(message.directoryPath);

    print('[ISOLATE] Scanning directory: ${message.directoryPath}');
    
    if (!directory.existsSync()) {
      print('[ISOLATE ERROR] Directory does not exist');
      Isolate.exit(message.sendPort, tracks);
      return;
    }

    try {
      final files = directory.listSync(recursive: true);
      print('[ISOLATE] Found ${files.length} total files');
      
      for (var file in files) {
        if (file is File) {
          final filePath = file.path.toLowerCase();
          if (filePath.endsWith('.mp3') || 
              filePath.endsWith('.wav') || 
              filePath.endsWith('.flac')) {
            
            print('[ISOLATE] Found audio file: $filePath');
            
            // Create track with basic info (metadata will be extracted later)
            tracks.add(models.Track(
              path: file.path,
              title: _getTitleFromFileName(file.path),
              artist: 'Unknown Artist',
              album: 'Unknown Album',
              duration: Duration.zero,
              albumArtPath: null, // Will be extracted later
            ));
          }
        }
      }
    } catch (e) {
      print('[ISOLATE ERROR] Directory scanning failed: $e');
    }

    print('[ISOLATE] Scan complete, found ${tracks.length} tracks');
    Isolate.exit(message.sendPort, tracks);
  }

  static String _getTitleFromFileName(String filePath) {
    final fileName = path.basename(filePath);
    return fileName
        .replaceAll('.mp3', '')
        .replaceAll('.wav', '')
        .replaceAll('.flac', '')
        .replaceAll('_', ' ')
        .replaceAll('-', ' ');
  }
}

class _IsolateMessage {
  final SendPort sendPort;
  final String directoryPath;

  _IsolateMessage(this.sendPort, this.directoryPath);
}