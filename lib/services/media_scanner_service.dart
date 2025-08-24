import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'package:flutter_media_metadata/flutter_media_metadata.dart';
import '../models/player_state.dart' as models;
import 'audio_service.dart';
import 'cache_service.dart'; // Added import for AlbumCoverCache
import 'media_scanner_isolate.dart'; // Add this import


class MediaScannerService {
  final AudioService audioService;
  bool _isScanning = false;

  MediaScannerService({required this.audioService});

    Future<List<models.Track>> scanDirectory(String directoryPath) async {
  if (_isScanning) {
    throw Exception('Scan already in progress');
  }
  
  _isScanning = true;
  try {
    print('[SCAN] Starting directory scan: $directoryPath');
    
    // Use isolate for fast file discovery
    final tracks = await MediaScannerIsolate.scanDirectory(directoryPath);
    print('[SCAN] Found ${tracks.length} tracks, now extracting metadata...');
    
    // Extract metadata on main thread (where plugins work)
    final tracksWithMetadata = await _extractMetadataForTracks(tracks);
    
    // Pre-cache album arts
    _preCacheAlbumArtsInBackground(tracksWithMetadata);
    
    return tracksWithMetadata;
  } catch (e) {
    print('[SCAN ERROR] $e');
    rethrow;
  } finally {
    _isScanning = false;
  }
}

Future<List<models.Track>> _extractMetadataForTracks(List<models.Track> tracks) async {
  final List<models.Track> tracksWithMetadata = [];
  
  for (final track in tracks) {
    try {
      final metadata = await MetadataRetriever.fromFile(File(track.path));
      
      Duration duration = Duration.zero;
      if (metadata.trackDuration != null) {
        if (metadata.trackDuration is Duration) {
          duration = metadata.trackDuration as Duration;
        } else if (metadata.trackDuration is int) {
          duration = Duration(milliseconds: metadata.trackDuration as int);
        }
      }
      
      tracksWithMetadata.add(models.Track(
        path: track.path,
        title: metadata.trackName ?? track.title,
        artist: metadata.trackArtistNames?.join(', ') ?? track.artist,
        album: metadata.albumName ?? track.album,
        duration: duration,
        albumArtPath: metadata.albumArt != null ? track.path : null,
      ));
      
    } catch (e) {
      print('[METADATA ERROR] Failed to extract metadata for ${track.path}: $e');
      // Keep the track with basic info if metadata extraction fails
      tracksWithMetadata.add(track);
    }
  }
  
  return tracksWithMetadata;
}

  void _preCacheAlbumArtsInBackground(List<models.Track> tracks) {
    Future.microtask(() async {
      for (final track in tracks) {
        if (track.albumArtPath != null) {
          try {
            await AlbumCoverCache.getAlbumCover(track.albumArtPath!);
          } catch (e) {
            // Silently fail for pre-caching
          }
        }
      }
    });
  }

  List<models.Album> organizeTracksIntoAlbums(List<models.Track> tracks) {
    final albumMap = <String, models.Album>{};
    
    for (final track in tracks) {
      final albumKey = '${track.album}::${track.artist}';
      
      if (!albumMap.containsKey(albumKey)) {
        albumMap[albumKey] = models.Album(
          name: track.album,
          artist: track.artist,
          tracks: [],
          coverArtPath: track.albumArtPath,
        );
      }
      
      albumMap[albumKey]!.tracks.add(track);
    }
    
    return albumMap.values.toList();
  }

  // Helper method to extract album art from a track
  Future<Uint8List?> extractAlbumArt(String filePath) async {
    try {
      final file = File(filePath);
      final metadata = await MetadataRetriever.fromFile(file);
      return metadata.albumArt;
    } catch (e) {
      return null;
    }
  }

  Future<void> preCacheAlbumArts(List<models.Track> tracks) async { // Fixed: changed Track to models.Track
    for (final track in tracks) {
      if (track.albumArtPath != null) {
        // Pre-cache in background
        AlbumCoverCache.getAlbumCover(track.albumArtPath!).catchError((e) {
          // Silently handle errors - it's just pre-caching
        });
      }
    }
  }
}