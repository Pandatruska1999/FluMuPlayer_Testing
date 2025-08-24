import 'dart:typed_data';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:flutter_media_metadata/flutter_media_metadata.dart';
import 'cover_loader_isolate.dart'; // Add this import

class MetadataService {
  static Future<Uint8List?> extractCoverArt(String audioFilePath) async {
    try {
      // Use isolate for cover loading
      final covers = await CoverLoaderIsolate.loadCovers([audioFilePath]);
      return covers[audioFilePath];
    } catch (e) {
      print('Error extracting cover art from $audioFilePath: $e');
      return null;
    }
  }

  static Future<Map<String, Uint8List?>> extractCoversBulk(List<String> audioFilePaths) async {
  return await CoverLoaderIsolate.loadCovers(audioFilePaths);
}

  static Future<Map<String, dynamic>> getAudioMetadata(String audioFilePath) async {
    try {
      // Load metadata on main thread (lightweight)
      final metadata = await MetadataRetriever.fromFile(File(audioFilePath));
      
      Duration duration = Duration.zero;
      if (metadata.trackDuration != null) {
        if (metadata.trackDuration is Duration) {
          duration = metadata.trackDuration as Duration;
        } else if (metadata.trackDuration is int) {
          duration = Duration(milliseconds: metadata.trackDuration as int);
        }
      }

      // Get the available metadata properties
      String title = metadata.trackName ?? path.basenameWithoutExtension(audioFilePath);
      String artist = 'Unknown Artist';
      String album = 'Unknown Album';
      int trackNumber = 0;
      int year = 0;
      String genre = '';
      int bitrate = 0;

      // Extract available metadata safely
      if (metadata.trackArtistNames != null && metadata.trackArtistNames!.isNotEmpty) {
        artist = metadata.trackArtistNames!.join(', ');
      }
      
      if (metadata.albumName != null && metadata.albumName!.isNotEmpty) {
        album = metadata.albumName!;
      }
      
      if (metadata.trackNumber != null) {
        trackNumber = metadata.trackNumber!;
      }
      
      if (metadata.year != null) {
        year = metadata.year!;
      }
      
      if (metadata.genre != null && metadata.genre!.isNotEmpty) {
        genre = metadata.genre!;
      }
      
      if (metadata.bitrate != null) {
        bitrate = metadata.bitrate!;
      }

      return {
        'title': title,
        'artist': artist,
        'album': album,
        'trackIndex': trackNumber,
        'year': year,
        'genre': genre,
        'duration': duration.inMilliseconds,
        'bitrate': bitrate,
        // Cover art will be loaded separately in isolate
      };
    } catch (e) {
      print('Error reading metadata from $audioFilePath: $e');
      final fileName = path.basenameWithoutExtension(audioFilePath);
      
      return {
        'title': fileName,
        'artist': 'Unknown Artist',
        'album': 'Unknown Album',
        'trackIndex': 0,
        'year': 0,
        'genre': '',
        'duration': 0,
        'bitrate': 0,
      };
    }
  }

  static Future<Duration> getAudioDuration(String audioFilePath) async {
    try {
      final metadata = await MetadataRetriever.fromFile(File(audioFilePath));
      
      if (metadata.trackDuration != null) {
        if (metadata.trackDuration is Duration) {
          return metadata.trackDuration as Duration;
        } else if (metadata.trackDuration is int) {
          return Duration(milliseconds: metadata.trackDuration as int);
        }
      }
      
      return Duration.zero;
    } catch (e) {
      print('Error getting duration from $audioFilePath: $e');
      return Duration.zero;
    }
  }

  // Note: flutter_media_metadata doesn't support writing metadata
  // These methods will be no-ops or return false
  static Future<void> updateAudioMetadata(String audioFilePath, Map<String, dynamic> metadata) async {
    print('Metadata writing not supported with flutter_media_metadata');
  }

  static Future<bool> updateCoverArt(String audioFilePath, Uint8List coverArt) async {
    print('Cover art writing not supported with flutter_media_metadata');
    return false;
  }

  static Future<String?> getLyrics(String audioFilePath) async {
    try {
      // flutter_media_metadata doesn't support lyrics extraction
      // You might need a different package for this
      return null;
    } catch (e) {
      print('Error getting lyrics from $audioFilePath: $e');
      return null;
    }
  }

  static Future<bool> setLyrics(String audioFilePath, String lyrics) async {
    print('Lyrics writing not supported with flutter_media_metadata');
    return false;
  }
}