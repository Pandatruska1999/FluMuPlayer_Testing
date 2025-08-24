import 'dart:typed_data';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter_media_metadata/flutter_media_metadata.dart';
import 'cache_service.dart';

class AlbumCoverCache {
  static final DefaultCacheManager _cacheManager = DefaultCacheManager();
  static final Map<String, Uint8List> _memoryCache = {};
  static const int _maxMemoryCacheSize = 50; // Keep 50 covers in memory

  static Future<Uint8List?> getAlbumCover(String filePath, {int size = 200}) async {
    // First check memory cache
    if (_memoryCache.containsKey(filePath)) {
      return _memoryCache[filePath];
    }

    // Check disk cache
    final file = await _cacheManager.getFileFromCache(filePath);
    if (file != null) {
      final bytes = await file.file.readAsBytes();
      _addToMemoryCache(filePath, bytes);
      return bytes;
    }

    // Extract from file and cache
    try {
      final metadata = await MetadataRetriever.fromFile(File(filePath));
      if (metadata.albumArt != null) {
        // Resize to thumbnail for better performance
        final resizedImage = await _resizeImage(metadata.albumArt!, size);
        await _cacheManager.putFile(
          filePath, 
          resizedImage,
          key: filePath,
        );
        _addToMemoryCache(filePath, resizedImage);
        return resizedImage;
      }
    } catch (e) {
      print('Error extracting album art: $e');
    }

    return null;
  }

  static Future<Uint8List> _resizeImage(Uint8List bytes, int size) async {
    // For now, return original - you can implement image resizing later
    // with packages like image or flutter_image_compress
    return bytes;
  }

  static void _addToMemoryCache(String key, Uint8List bytes) {
    // Simple LRU cache implementation
    if (_memoryCache.length >= _maxMemoryCacheSize) {
      _memoryCache.remove(_memoryCache.keys.first);
    }
    _memoryCache[key] = bytes;
  }

  static void clearMemoryCache() {
    _memoryCache.clear();
  }

  static Future<void> clearDiskCache() async {
    await _cacheManager.emptyCache();
  }
}