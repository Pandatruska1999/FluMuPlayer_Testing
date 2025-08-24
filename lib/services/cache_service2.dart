import 'dart:typed_data';
import 'dart:collection';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'metadata_service.dart'; // Add this import

class AlbumCoverCache {
  static final LRUCache<String, Uint8List> _memoryCache = LRUCache(200);
  static final Map<String, Completer<Uint8List?>> _loadingCompleters = {};
  static final Set<String> _failedLoads = {};

  static Future<Uint8List?> getAlbumCover(String? audioFilePath, {int size = 120}) async {
    if (audioFilePath == null || audioFilePath.isEmpty) {
      return _createPlaceholderImage(size);
    }

    // Return null for known failed loads to prevent retries
    if (_failedLoads.contains(audioFilePath)) {
      return _createPlaceholderImage(size);
    }

    // Check memory cache first
    if (_memoryCache.containsKey(audioFilePath)) {
      return _memoryCache[audioFilePath];
    }

    // Check if already loading this image
    if (_loadingCompleters.containsKey(audioFilePath)) {
      return _loadingCompleters[audioFilePath]!.future;
    }

    final completer = Completer<Uint8List?>();
    _loadingCompleters[audioFilePath] = completer;

    try {
      // Use the metadata service to get cover art (which uses isolate)
      final coverArt = await MetadataService.extractCoverArt(audioFilePath);
      
      if (coverArt != null) {
        _memoryCache[audioFilePath] = coverArt;
        completer.complete(coverArt);
      } else {
        _failedLoads.add(audioFilePath);
        final placeholder = await _createPlaceholderImage(size);
        completer.complete(placeholder);
      }
      
    } catch (e) {
      print('Error loading cover art for $audioFilePath: $e');
      _failedLoads.add(audioFilePath);
      final placeholder = await _createPlaceholderImage(size);
      completer.complete(placeholder);
    } finally {
      _loadingCompleters.remove(audioFilePath);
    }

    return completer.future;
  }

  static Future<Uint8List> _createPlaceholderImage(int size) async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()));
      
      // Draw background
      final paint = ui.Paint()
        ..color = const ui.Color(0xFF2D2D2D)
        ..style = ui.PaintingStyle.fill;
      
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(
          ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
          const ui.Radius.circular(8),
        ),
        paint,
      );
      
      // Draw music note icon
      final musicNotePaint = ui.Paint()
        ..color = const ui.Color(0xFFFFFFFF)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 2.0;
      
      final notePath = ui.Path();
      
      // Draw a simple music note shape
      notePath.moveTo(size * 0.4, size * 0.3);
      notePath.lineTo(size * 0.4, size * 0.7);
      
      notePath.moveTo(size * 0.4, size * 0.3);
      notePath.quadraticBezierTo(
        size * 0.5, size * 0.25,
        size * 0.6, size * 0.3
      );
      
      notePath.moveTo(size * 0.4, size * 0.7);
      notePath.quadraticBezierTo(
        size * 0.5, size * 0.65,
        size * 0.6, size * 0.7
      );
      
      canvas.drawPath(notePath, musicNotePaint);
      
      // Draw note heads
      canvas.drawCircle(
        ui.Offset(size * 0.6, size * 0.3),
        size * 0.05,
        ui.Paint()..color = const ui.Color(0xFFFFFFFF),
      );
      
      canvas.drawCircle(
        ui.Offset(size * 0.6, size * 0.7),
        size * 0.05,
        ui.Paint()..color = const ui.Color(0xFFFFFFFF),
      );
      
      final picture = recorder.endRecording();
      final image = await picture.toImage(size, size);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      return byteData!.buffer.asUint8List();
    } catch (e) {
      // Fallback: return empty bytes
      return Uint8List(0);
    }
  }

  static void clearCache() {
    _memoryCache.clear();
    _failedLoads.clear();
    _loadingCompleters.clear();
  }

  static void removeFromCache(String path) {
    _memoryCache.remove(path);
    _failedLoads.remove(path);
  }

  static void preloadImages(List<String?> paths, {int size = 120}) {
    for (final path in paths) {
      if (path != null && 
          !_memoryCache.containsKey(path) && 
          !_loadingCompleters.containsKey(path) &&
          !_failedLoads.contains(path)) {
        getAlbumCover(path, size: size);
      }
    }
  }

  // Add this method to manually cache cover art
  static void cacheCoverArt(String audioFilePath, Uint8List coverArt) {
    _memoryCache[audioFilePath] = coverArt;
    _failedLoads.remove(audioFilePath);
  }
}

class LRUCache<K, V> {
  final int maxSize;
  final LinkedHashMap<K, V> _map = LinkedHashMap<K, V>();

  LRUCache(this.maxSize);

  V? operator [](K key) {
    if (_map.containsKey(key)) {
      final value = _map.remove(key);
      _map[key] = value!;
      return value;
    }
    return null;
  }

  void operator []=(K key, V value) {
    if (_map.length >= maxSize) {
      final firstKey = _map.keys.first;
      _map.remove(firstKey);
    }
    _map[key] = value;
  }

  bool containsKey(K key) => _map.containsKey(key);

  void remove(K key) => _map.remove(key);

  void clear() => _map.clear();

  int get length => _map.length;

  Iterable<K> get keys => _map.keys;
}