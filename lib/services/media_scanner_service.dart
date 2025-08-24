import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import '../models/player_state.dart' as models;
import 'audio_service.dart';
import 'cache_service.dart';
import 'media_scanner_isolate.dart';
import 'metadata_service.dart';

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
    
    // Load covers in isolate and update tracks
    final tracksWithCovers = await _loadCoversInIsolate(tracksWithMetadata);
    
    // Pre-cache album arts
    _preCacheAlbumArtsInBackground(tracksWithCovers);
    
    return tracksWithCovers;
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
        final metadata = await MetadataService.getAudioMetadata(track.path);
        
        final duration = Duration(milliseconds: metadata['duration'] as int);
        
        tracksWithMetadata.add(models.Track(
          path: track.path,
          title: metadata['title'] as String,
          artist: metadata['artist'] as String,
          album: metadata['album'] as String,
          duration: duration,
          albumArtPath: null, // Will be set after isolate loading
          trackIndex: metadata['trackIndex'] as int,
          year: metadata['year'] as int,
          genre: metadata['genre'] as String,
          bitrate: metadata['bitrate'] as int,
        ));
        
      } catch (e) {
        print('[METADATA ERROR] Failed to extract metadata for ${track.path}: $e');
        // Keep the track with basic info if metadata extraction fails
        tracksWithMetadata.add(track);
      }
    }
    
    return tracksWithMetadata;
  }

Future<List<models.Track>> _loadCoversInIsolate(List<models.Track> tracks) async {
  print('[SCAN] Loading covers in isolate for ${tracks.length} tracks...');
  
  final audioPaths = tracks.map((t) => t.path).toList();
  final coverResults = await MetadataService.extractCoversBulk(audioPaths);
  
  // Update tracks with cover art information AND cache the results
  final List<models.Track> tracksWithCovers = [];
  
  for (final track in tracks) {
    final coverArt = coverResults[track.path];
    
    tracksWithCovers.add(models.Track(
      path: track.path,
      title: track.title,
      artist: track.artist,
      album: track.album,
      duration: track.duration,
      albumArtPath: coverArt != null ? track.path : null, // Use track path as key
      trackIndex: track.trackIndex,
      year: track.year,
      genre: track.genre,
      bitrate: track.bitrate,
    ));
    
    // MANUALLY CACHE THE COVER ART - THIS IS THE KEY FIX
    if (coverArt != null) {
      AlbumCoverCache.cacheCoverArt(track.path, coverArt);
    }
  }
  
  print('[SCAN] Cover loading complete, cached ${coverResults.values.where((c) => c != null).length} covers');
  return tracksWithCovers;
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
      return await MetadataService.extractCoverArt(filePath);
    } catch (e) {
      return null;
    }
  }

  Future<void> preCacheAlbumArts(List<models.Track> tracks) async {
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