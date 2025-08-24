// lib/services/audio_service.dart
import 'package:flutter_soloud/flutter_soloud.dart';
import '../models/player_state.dart';

class AudioService {
  final SoLoud _soLoud = SoLoud.instance;

  // Loaded AudioSources by path
  final Map<String, AudioSource> _sources = {};

  // Track current playback
  SoundHandle? _currentHandle;
  String? _currentPath;

  // Track whether the current playback for a given path is a 3D voice
  final Map<String, bool> _is3dPlaying = {};

  // Remember last spatial position for a path (so we can start as 3D if requested)
  final Map<String, AudioSourcePosition> _spatialPositions = {};

  bool _initialized = false;

  Future<void> initialize({bool enableLimiter = true}) async {
    if (_initialized) return;
    await _soLoud.init();
    _initialized = true;

    // Set a sensible default listener (center looking forward)
    // NOTE: set3dListenerParameters expects positional args:
    // (posX, posY, posZ, atX, atY, atZ, upX, upY, upZ, velocityX, velocityY, velocityZ)
    _soLoud.set3dListenerParameters(
      0, 0, 0,    // posX, posY, posZ
      0, 0, 1,    // atX, atY, atZ
      0, 1, 0,    // upX, upY, upZ
      0, 0, 0,    // velocityX, velocityY, velocityZ
    );

    // Optional: enable limiter to avoid clipping when many sounds overlap
    if (enableLimiter) {
      try {
        _soLoud.filters.limiterFilter.activate();
        _soLoud.filters.limiterFilter.outputCeiling.value = -6;
      } catch (_) {
        // ignore if platform doesn't expose that filter
      }
    }
  }

  Future<AudioSource> _loadSource(String path) async {
    if (_sources.containsKey(path)) return _sources[path]!;

    AudioSource source;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      source = await _soLoud.loadUrl(path, mode: LoadMode.memory);
    } else if (path.startsWith('assets/')) {
      source = await _soLoud.loadAsset(path, mode: LoadMode.memory);
    } else {
      source = await _soLoud.loadFile(path, mode: LoadMode.memory);
    }

    _sources[path] = source;

    // keep around; optionally dispose later
    source.allInstancesFinished.first.then((_) {
      // _soLoud.disposeSource(source); // optional
    });

    return source;
  }

  Future<void> play(
    String path, {
    double volume = 1.0,
    double pan = 0.0,
    bool looping = false,
  }) async {
    try {
      await stop();

      final src = await _loadSource(path);

      if (_spatialPositions.containsKey(path)) {
        final p = _spatialPositions[path]!;
        final handle = await _soLoud.play3d(
          src,
          p.x, p.y, p.z,        // positional posX, posY, posZ
          velX: 0, velY: 0, velZ: 0,
          volume: p.volume,
          looping: looping,
        );
        _currentHandle = handle;
        _currentPath = path;
        _is3dPlaying[path] = true;

        _soLoud.set3dSourceMinMaxDistance(handle, 1.0, 100.0);
        _soLoud.set3dSourceAttenuation(handle, 1, 1.0);
      } else {
        final handle = await _soLoud.play(
          src,
          volume: volume,
          pan: pan,
          looping: looping,
        );
        _currentHandle = handle;
        _currentPath = path;
        _is3dPlaying[path] = false;
      }
    } catch (e) {
      // ignore: avoid_print
      print('AudioService.play() error: $e');
    }
  }


    Future<void> setSpatialPosition(
    String path,
    AudioSourcePosition position,
  ) async {
    // store last-known requested position
    _spatialPositions[path] = position;

    try {
      final src = await _loadSource(path);

      final samePath = _currentPath == path &&
          _currentHandle != null &&
          _soLoud.getIsValidVoiceHandle(_currentHandle!);

      if (!samePath) {
        // IMPORTANT: stop any currently playing handle to avoid leaving orphan voices
        // (this prevents the "pause doesn't pause everything" bug)
        await stop();

        // Not playing this path right now: start it as a 3D voice
        final handle = await _soLoud.play3d(
          src,
          position.x,
          position.y,
          position.z,
          velX: 0,
          velY: 0,
          velZ: 0,
          volume: position.volume,
        );
        _currentHandle = handle;
        _currentPath = path;
        _is3dPlaying[path] = true;

        _soLoud.set3dSourceMinMaxDistance(handle, 1.0, 100.0);
        _soLoud.set3dSourceAttenuation(handle, 1, 1.0); // inverse distance, rolloff
        return;
      }

      // We are playing this path already — ensure it's a 3D handle
      final handle = _currentHandle!;
      final was3d = _is3dPlaying[path] ?? false;

      if (!was3d) {
        // Replace stereo handle with a 3D handle at the requested position
        await _soLoud.stop(handle);
        final newHandle = await _soLoud.play3d(
          src,
          position.x,
          position.y,
          position.z,
          velX: 0,
          velY: 0,
          velZ: 0,
          volume: position.volume,
        );
        _currentHandle = newHandle;
        _is3dPlaying[path] = true;

        _soLoud.set3dSourceMinMaxDistance(newHandle, 1.0, 100.0);
        _soLoud.set3dSourceAttenuation(newHandle, 1, 1.0); // INVERSE_DISTANCE
        return;
      }

      // Already a 3D handle — just update parameters
      _soLoud.set3dSourcePosition(handle, position.x, position.y, position.z);
      _soLoud.setVolume(handle, position.volume);
      _soLoud.set3dSourceMinMaxDistance(handle, 1.0, 100.0);
      _soLoud.set3dSourceAttenuation(handle, 1, 1.0); // INVERSE_DISTANCE
    } catch (e) {
      // ignore errors but log
      // ignore: avoid_print
      print('AudioService.setSpatialPosition error: $e');
    }
  }


  Future<void> pause() async {
    final h = _currentHandle;
    if (h != null && _soLoud.getIsValidVoiceHandle(h)) {
      _soLoud.setPause(h, true);
    }
  }

  Future<void> resume() async {
    final h = _currentHandle;
    if (h != null && _soLoud.getIsValidVoiceHandle(h)) {
      _soLoud.setPause(h, false);
    }
  }

  Future<void> stop() async {
    final h = _currentHandle;
    if (h != null && _soLoud.getIsValidVoiceHandle(h)) {
      await _soLoud.stop(h);
    }
    _currentHandle = null;
    _currentPath = null;
  }

  Future<void> seek(Duration position) async {
    final h = _currentHandle;
    if (h != null && _soLoud.getIsValidVoiceHandle(h)) {
      _soLoud.seek(h, position);
    }
  }

  Future<void> setVolume(double volume) async {
    final h = _currentHandle;
    if (h != null && _soLoud.getIsValidVoiceHandle(h)) {
      _soLoud.setVolume(h, volume);
    } else {
      _soLoud.setGlobalVolume(volume);
    }
  }

  Duration get position {
    final h = _currentHandle;
    if (h != null && _soLoud.getIsValidVoiceHandle(h)) {
      return _soLoud.getPosition(h);
    }
    return Duration.zero;
  }

  Duration get duration {
    final path = _currentPath;
    if (path == null) return Duration.zero;
    final src = _sources[path];
    if (src == null) return Duration.zero;
    return _soLoud.getLength(src);
  }

  bool get isPlaying {
    final h = _currentHandle;
    if (h == null) return false;
    if (!_soLoud.getIsValidVoiceHandle(h)) return false;
    final paused = _soLoud.getPause(h);
    return !paused;
  }

  // Set listener parameters via positional arguments (matches SoLoud API)
  void setListenerParameters({
    required double px, required double py, required double pz,
    required double atx, required double aty, required double atz,
    required double upx, required double upy, required double upz,
    double vx = 0, double vy = 0, double vz = 0,
  }) {
    _soLoud.set3dListenerParameters(
      px, py, pz,    // posX, posY, posZ
      atx, aty, atz, // atX, atY, atZ
      upx, upy, upz, // upX, upY, upZ
      vx, vy, vz,    // velocityX, velocityY, velocityZ
    );
  }

    /// Revert currently playing track back to normal (non-3D) playback
  Future<void> revertToStereo() async {
  if (_currentPath == null) return;

  try {
    final src = await _loadSource(_currentPath!);

    // Save current state
    final position = _soLoud.getPosition(_currentHandle!);
    final looping = _soLoud.getLooping(_currentHandle!);
    final volume = _soLoud.getVolume(_currentHandle!);

    // Stop 3D playback
    await _soLoud.stop(_currentHandle!);

    // Start stereo playback
    final newHandle = await _soLoud.play(
      src,
      volume: volume,
      looping: looping,
    );
    
    // Restore position
    _soLoud.seek(newHandle, position);

    // Update state
    _currentHandle = newHandle;
    _is3dPlaying[_currentPath!] = false;
    
  } catch (e) {
    print("AudioService.revertToStereo error: $e");
  }
}


  void dispose() {
    try {
      _soLoud.deinit();
    } catch (_) {}
  }

  String? get currentFilePath => _currentPath;
}