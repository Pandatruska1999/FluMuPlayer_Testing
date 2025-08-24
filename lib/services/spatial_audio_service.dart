import 'dart:math';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import '../models/player_state.dart' as models;
import 'native_audio_handler.dart';

class SpatialAudioService {
  static const double speedOfSound = 343.0;
  static const double headRadius = 0.0875;
  static const int sampleRate = 44100;

  final AudioPlayer _audioPlayer;
  final Map<String, models.AudioSourcePosition> _positions = {};
  Timer? _updateTimer;
  bool _isInitialized = false;

  SpatialAudioService(this._audioPlayer) {
    _initializeAudioProcessing();
  }

  Function(String trackId, List<double> processedSamples)? onAudioProcessed;

  // Initialize audio processing
  void _initializeAudioProcessing() async {
    _isInitialized = await NativeAudioHandler.initialize();
    if (_isInitialized) {
      _startParameterUpdates();
      print('Spatial audio service initialized successfully');
    } else {
      print('Failed to initialize spatial audio service');
    }
  }

  // Start sending periodic updates to native side
  void _startParameterUpdates() {
    _updateTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _sendPositionUpdates();
    });
  }

  // Send all position updates to native audio handler
  void _sendPositionUpdates() {
    if (!_isInitialized) return;
    
    _positions.forEach((trackId, position) {
      NativeAudioHandler.updateSpatialParameters(
        trackId,
        position.x,
        position.y,
        position.z,
        position.volume,
      );
    });
  }

  models.AudioSourcePosition? getPosition(String trackId) {
    return _positions[trackId];
  }

  void updatePositions(Map<String, models.AudioSourcePosition> positions) {
    _positions.clear();
    _positions.addAll(positions);
    _sendPositionUpdates(); // Immediately send updates
  }

  void applySpatialAudio(String filePath, models.AudioSourcePosition position) {
    _positions[filePath] = position;
    _processAudioPosition(filePath, position);
    _sendPositionUpdates(); // Send update immediately
  }

  void _processAudioPosition(String trackId, models.AudioSourcePosition position) {
    final spherical = _cartesianToSpherical(position.x, position.y, position.z);
    
    final itd = _calculateITD(spherical.azimuth);
    final ild = _calculateILD(spherical.azimuth);
    final distanceGain = 1.0 / (1.0 + spherical.distance * spherical.distance);
    
    print('Spatial audio applied to $trackId: '
          'ITD: ${itd.toStringAsFixed(4)}s, '
          'ILD: ${ild.toStringAsFixed(2)}, '
          'Distance: ${spherical.distance.toStringAsFixed(2)}');
  }

  // Add this method to load audio data into the native processor
  Future<bool> loadAudioTrack(String trackId, List<double> audioData, int sampleRate) async {
    if (!_isInitialized) return false;
    
    return await NativeAudioHandler.addAudioTrack(trackId, audioData, sampleRate);
  }

  // Remove audio track from native processor
  Future<bool> unloadAudioTrack(String trackId) async {
    if (!_isInitialized) return false;
    
    return await NativeAudioHandler.removeAudioTrack(trackId);
  }

  double _calculateITD(double azimuth) {
    return (headRadius * (azimuth + sin(azimuth))) / speedOfSound;
  }

  double _calculateILD(double azimuth) {
    return cos(azimuth) * 0.5 + 0.5;
  }

  SphericalCoordinates _cartesianToSpherical(double x, double y, double z) {
    final distance = sqrt(x*x + y*y + z*z);
    final azimuth = atan2(y, x);
    final elevation = asin(z / distance);
    
    return SphericalCoordinates(distance, azimuth, elevation);
  }

  (double, double) processSample(double inputSample, String trackId) {
    final position = _positions[trackId];
    if (position == null) return (inputSample, inputSample);

    final spherical = _cartesianToSpherical(position.x, position.y, position.z);
    final itd = _calculateITD(spherical.azimuth);
    final ild = _calculateILD(spherical.azimuth);
    final distanceGain = 1.0 / (1.0 + spherical.distance);

    final leftGain = ild * distanceGain * position.volume;
    final rightGain = (1.0 - ild) * distanceGain * position.volume;

    return (inputSample * leftGain, inputSample * rightGain);
  }

  // Cleanup
  void dispose() {
    _updateTimer?.cancel();
    _positions.clear();
  }
}

class SphericalCoordinates {
  final double distance;
  final double azimuth;
  final double elevation;

  SphericalCoordinates(this.distance, this.azimuth, this.elevation);
}