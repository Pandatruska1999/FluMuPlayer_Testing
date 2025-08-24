// cover_loader_isolate.dart
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter_media_metadata/flutter_media_metadata.dart';
import 'package:flutter/services.dart';

class CoverLoaderIsolate {
  static Future<Map<String, Uint8List?>> loadCovers(List<String> audioPaths) async {
    final receivePort = ReceivePort();
    
    // Get the root isolate token from the main isolate
    final RootIsolateToken rootIsolateToken = RootIsolateToken.instance!;
    
    await Isolate.spawn(
      _loadCoversIsolate,
      _CoverIsolateMessage(
        receivePort.sendPort, 
        audioPaths,
        rootIsolateToken, // Pass the token to the isolate
      ),
    );

    return await receivePort.first as Map<String, Uint8List?>;
  }

  static void _loadCoversIsolate(_CoverIsolateMessage message) async {
    // ✅ CORRECT: Initialize with RootIsolateToken
    BackgroundIsolateBinaryMessenger.ensureInitialized(message.rootIsolateToken);
    
    final Map<String, Uint8List?> coverResults = {};
    
    for (final audioPath in message.audioPaths) {
      try {
        final metadata = await MetadataRetriever.fromFile(File(audioPath));
        coverResults[audioPath] = metadata.albumArt;
        print('[COVER ISOLATE] Loaded cover for: ${audioPath.split('/').last}');
      } catch (e) {
        print('[COVER ISOLATE ERROR] Failed to load cover for $audioPath: $e');
        coverResults[audioPath] = null;
      }
    }

    Isolate.exit(message.sendPort, coverResults);
  }
}

class _CoverIsolateMessage {
  final SendPort sendPort;
  final List<String> audioPaths;
  final RootIsolateToken rootIsolateToken; // Add this field

  _CoverIsolateMessage(this.sendPort, this.audioPaths, this.rootIsolateToken);
}