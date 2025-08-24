// lib/services/audio_service.dart
import 'package:flutter_soloud/flutter_soloud.dart';
import '../models/player_state.dart';

class PlayerSettings {
  final double volume;
  final double pan;
  final bool looping;
  final bool is3DEnabled;
  final AudioSourcePosition? spatialPosition;

  const PlayerSettings({
    this.volume = 1.0,
    this.pan = 0.0,
    this.looping = false,
    this.is3DEnabled = false,
    this.spatialPosition,
  });

  PlayerSettings copyWith({
    double? volume,
    double? pan,
    bool? looping,
    bool? is3DEnabled,
    AudioSourcePosition? spatialPosition,
  }) {
    return PlayerSettings(
      volume: volume ?? this.volume,
      pan: pan ?? this.pan,
      looping: looping ?? this.looping,
      is3DEnabled: is3DEnabled ?? this.is3DEnabled,
      spatialPosition: spatialPosition ?? this.spatialPosition,
    );
  }
}

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

  // Settings management
  PlayerSettings _pendingSettings = PlayerSettings();
  PlayerSettings _appliedSettings = PlayerSettings();

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

  // Settings management methods
  void updatePendingSettings({
    double? volume,
    double? pan,
    bool? looping,
    bool? is3DEnabled,
    AudioSourcePosition? spatialPosition,
  }) {
    _pendingSettings = _pendingSettings.copyWith(
      volume: volume,
      pan: pan,
      looping: looping,
      is3DEnabled: is3DEnabled,
      spatialPosition: spatialPosition,
    );
  }

  void applySettings() {
    // Overwrite applied settings with pending settings
    _appliedSettings = _pendingSettings;
    
    // Apply to currently playing audio if any
    if (_currentHandle != null && _soLoud.getIsValidVoiceHandle(_currentHandle!)) {
      final is3D = _is3dPlaying[_currentPath] ?? false;
      
      _soLoud.setVolume(_currentHandle!, _appliedSettings.volume);
      _soLoud.setLooping(_currentHandle!, _appliedSettings.looping);
      
      // Only apply pan to non-3D audio
      if (!is3D) {
        _soLoud.setPan(_currentHandle!, _appliedSettings.pan);
      }
      
      // Apply 3D settings if enabled
      if (_appliedSettings.is3DEnabled && _appliedSettings.spatialPosition != null) {
        final position = _appliedSettings.spatialPosition!;
        _soLoud.set3dSourcePosition(_currentHandle!, position.x, position.y, position.z);
        _soLoud.setVolume(_currentHandle!, position.volume);
      }
    }
  }

  PlayerSettings get pendingSettings => _pendingSettings;
  PlayerSettings get appliedSettings => _appliedSettings;

  Future<void> play(
  String path, {
  double? volume,
  double? pan,
  bool? looping,
  bool? is3DEnabled,
  AudioSourcePosition? spatialPosition,
}) async {
  try {
    final samePath = _currentPath == path && 
                    _currentHandle != null && 
                    _soLoud.getIsValidVoiceHandle(_currentHandle!);
    
    if (samePath) {
      // Same song - check if paused and resume
      if (_soLoud.getPause(_currentHandle!)) {
        await resume();
      }
      // If already playing, do nothing or update settings if needed
      return;
    }
    
    // Different song or no song playing - stop current and start new
    await stop();

    final src = await _loadSource(path);

    // Use applied settings unless specifically overridden
    final actualVolume = volume ?? _appliedSettings.volume;
    final actualPan = pan ?? _appliedSettings.pan;
    final actualLooping = looping ?? _appliedSettings.looping;
    final actualIs3DEnabled = is3DEnabled ?? _appliedSettings.is3DEnabled;
    final actualSpatialPosition = spatialPosition ?? _appliedSettings.spatialPosition;

    // Check if we should use 3D (either path-specific or from settings)
    final bool shouldUse3D = _spatialPositions.containsKey(path) || 
                            (actualIs3DEnabled && actualSpatialPosition != null);
    
    if (shouldUse3D) {
      // Use path-specific position if available, otherwise use settings position
      final position = _spatialPositions[path] ?? actualSpatialPosition!;
      final handle = await _soLoud.play3d(
        src,
        position.x, position.y, position.z,
        velX: 0, velY: 0, velZ: 0,
        volume: actualVolume,
        looping: actualLooping,
      );
      _currentHandle = handle;
      _currentPath = path;
      _is3dPlaying[path] = true;

      _soLoud.set3dSourceMinMaxDistance(handle, 1.0, 100.0);
      _soLoud.set3dSourceAttenuation(handle, 1, 1.0);
    } else {
      final handle = await _soLoud.play(
        src,
        volume: actualVolume,
        pan: actualPan,
        looping: actualLooping,
      );
      _currentHandle = handle;
      _currentPath = path;
      _is3dPlaying[path] = false;
    }
  } catch (e) {
    print('AudioService.play() error: $e');
  }
}

  Future<void> setSpatialPosition(
  String path,
  AudioSourcePosition spatialPosition,  // Renamed parameter
) async {
  try {
    // Store position for this specific path
    _spatialPositions[path] = spatialPosition;
    
    // Update settings to enable 3D and set position for future songs
    updatePendingSettings(
      is3DEnabled: true,
      spatialPosition: spatialPosition,
    );
    
    // Apply settings immediately to affect current playback
    applySettings();

    final src = await _loadSource(path);
    final samePath = _currentPath == path &&
        _currentHandle != null &&
        _soLoud.getIsValidVoiceHandle(_currentHandle!);

    if (!samePath) {
      // Not currently playing this path - just store the position for future use
      return;
    }

    // We are playing this path - update or convert to 3D
    final handle = _currentHandle!;
    final was3d = _is3dPlaying[path] ?? false;

    if (!was3d) {
      // Convert stereo to 3D
      final currentPosition = _soLoud.getPosition(handle);  // Renamed local variable
      final wasLooping = _soLoud.getLooping(handle);
      
      await _soLoud.stop(handle);
      
      final newHandle = await _soLoud.play3d(
        src,
        spatialPosition.x,  // Use the renamed parameter
        spatialPosition.y,
        spatialPosition.z,
        velX: 0,
        velY: 0,
        velZ: 0,
        volume: _appliedSettings.volume,
        looping: wasLooping,
      );
      
      _soLoud.seek(newHandle, currentPosition);  // Use the renamed local variable
      _currentHandle = newHandle;
      _is3dPlaying[path] = true;

      _soLoud.set3dSourceMinMaxDistance(newHandle, 1.0, 100.0);
      _soLoud.set3dSourceAttenuation(newHandle, 1, 1.0);
    } else {
      // Already 3D - just update position
      _soLoud.set3dSourcePosition(handle, spatialPosition.x, spatialPosition.y, spatialPosition.z);
      _soLoud.setVolume(handle, _appliedSettings.volume);
      _soLoud.set3dSourceMinMaxDistance(handle, 1.0, 100.0);
      _soLoud.set3dSourceAttenuation(handle, 1, 1.0);
    }
  } catch (e) {
    print('AudioService.setSpatialPosition error: $e');
  }
}


/// Revert currently playing track back to normal (non-3D) playback
Future<void> revertToStereo() async {
  if (_currentPath == null || _currentHandle == null) return;
  
  // Check if we're actually in 3D mode
  final is3D = _is3dPlaying[_currentPath] ?? false;
  if (!is3D) return; // Already in stereo mode

  try {
    // Update settings to disable 3D for future songs
    updatePendingSettings(is3DEnabled: false);
    applySettings();

    final src = await _loadSource(_currentPath!);

    // Save current state
    final position = _soLoud.getPosition(_currentHandle!);
    final wasLooping = _soLoud.getLooping(_currentHandle!);
    
    // Stop 3D playback
    await _soLoud.stop(_currentHandle!);

    // Start stereo playback with applied settings
    final newHandle = await _soLoud.play(
      src,
      volume: _appliedSettings.volume,
      pan: _appliedSettings.pan,
      looping: _appliedSettings.looping,
    );
    
    // Restore position
    _soLoud.seek(newHandle, position);

    // Update state
    _currentHandle = newHandle;
    _is3dPlaying[_currentPath!] = false;
    
    // Clear spatial position for this path
    _spatialPositions.remove(_currentPath!);
    
  } catch (e) {
    print("AudioService.revertToStereo error: $e");
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

  void dispose() {
    try {
      _soLoud.deinit();
    } catch (_) {}
  }

  String? get currentFilePath => _currentPath;
}