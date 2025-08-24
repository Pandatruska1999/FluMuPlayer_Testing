import 'package:flutter/material.dart';
import '../models/player_state.dart';
import 'package:flumu/services/audio_service.dart';

class SpatialAudioMixer extends StatefulWidget {
  final PlayerState playerState;
  final Map<String, AudioSourcePosition> audioPositions;
  final ValueChanged<Map<String, AudioSourcePosition>> onPositionsChanged;
  final AudioService audioService; // <-- Inject dependency

  const SpatialAudioMixer({
    super.key,
    required this.playerState,
    required this.audioPositions,
    required this.onPositionsChanged,
    required this.audioService,
  });

  @override
  State<SpatialAudioMixer> createState() => _SpatialAudioMixerState();
}

class _SpatialAudioMixerState extends State<SpatialAudioMixer> {
  final Map<String, AudioSourcePosition> _currentPositions = {};
  String? _selectedTrackId;

  void _applyPositionsToAudio(Map<String, AudioSourcePosition> positions) {
  positions.forEach((trackId, position) {
    final bool isCurrentInPlayerState = widget.playerState.playlist.isNotEmpty &&
        widget.playerState.playlist[widget.playerState.currentIndex].path == trackId;

    final bool isCurrentInAudioService =
        widget.audioService.currentFilePath != null && widget.audioService.currentFilePath == trackId;

    if (isCurrentInPlayerState || isCurrentInAudioService) {
      widget.audioService.setSpatialPosition(trackId, position);
    }
  });

  widget.onPositionsChanged(positions);
}


  void _updatePosition(String trackId, double dx, double dy, double dz) {
  setState(() {
    final oldPosition = _currentPositions[trackId]!;
    _currentPositions[trackId] = oldPosition.copyWith(
      x: (oldPosition.x + dx).clamp(-10.0, 10.0),
      y: (oldPosition.y + dy).clamp(-10.0, 10.0),
      z: (oldPosition.z + dz).clamp(0.0, 10.0),
    );
  });

  // Send update to SoLoud via our AudioService only for the playing track
  final position = _currentPositions[trackId]!;

  final bool isCurrentInPlayerState = widget.playerState.playlist.isNotEmpty &&
      widget.playerState.playlist[widget.playerState.currentIndex].path == trackId;

  final bool isCurrentInAudioService =
      widget.audioService.currentFilePath != null && widget.audioService.currentFilePath == trackId;

  if (isCurrentInPlayerState || isCurrentInAudioService) {
    widget.audioService.setSpatialPosition(trackId, position);
  }

  widget.onPositionsChanged(_currentPositions);
}

void _updateVolume(String trackId, double volume) {
  setState(() {
    _currentPositions[trackId]!.volume = volume.clamp(0.0, 1.0);
  });

  final position = _currentPositions[trackId]!;

  final bool isCurrentInPlayerState = widget.playerState.playlist.isNotEmpty &&
      widget.playerState.playlist[widget.playerState.currentIndex].path == trackId;

  final bool isCurrentInAudioService =
      widget.audioService.currentFilePath != null && widget.audioService.currentFilePath == trackId;

  if (isCurrentInPlayerState || isCurrentInAudioService) {
    widget.audioService.setSpatialPosition(trackId, position);
  }

  widget.onPositionsChanged(_currentPositions);
}



  @override
  void initState() {
    super.initState();
    _currentPositions.addAll(widget.audioPositions);

    // Ensure each track has a position entry
    for (final track in widget.playerState.playlist) {
      _currentPositions.putIfAbsent(
        track.path,
        () => AudioSourcePosition(trackId: track.path),
      );
    }
  }

  Widget _buildRoomView() {
    return Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        border: Border.all(color: Colors.white30),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          // Room grid
          _buildRoomGrid(),
          // Audio source indicators
          ..._currentPositions.entries.map((entry) {
            final position = entry.value;
            final track = widget.playerState.playlist.firstWhere(
              (t) => t.path == entry.key,
              orElse: () => Track(path: entry.key, title: 'Unknown'),
            );

            return Positioned(
              left: 150 + position.x * 130, // Center + offset
              top: 150 - position.y * 130, // Center - offset (invert Y)
              child: GestureDetector(
                onTap: () => setState(() => _selectedTrackId = entry.key),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _selectedTrackId == entry.key
                        ? Colors.blue
                        : Colors.white.withOpacity(0.7),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.music_note,
                    size: 12,
                    color: Colors.black,
                  ),
                ),
              ),
            );
          }).toList(),
          // Listener position (center)
          Positioned(
            left: 150 - 8,
            top: 150 - 8,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(
                Icons.person,
                size: 10,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomGrid() {
    return CustomPaint(
      painter: _RoomGridPainter(),
      size: const Size(300, 300),
    );
  }

  Widget _buildTrackControls() {
    if (_selectedTrackId == null) {
      return const Text(
        'Select a track to adjust',
        style: TextStyle(color: Colors.white70),
      );
    }

    final position = _currentPositions[_selectedTrackId]!;
    final track = widget.playerState.playlist.firstWhere(
      (t) => t.path == _selectedTrackId,
      orElse: () => Track(path: _selectedTrackId!, title: 'Unknown'),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          track.displayTitle,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 16),
        Text(
          'Position: X: ${position.x.toStringAsFixed(2)}, '
          'Y: ${position.y.toStringAsFixed(2)}, '
          'Z: ${position.z.toStringAsFixed(2)}',
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 8),
        Text(
          'Volume: ${(position.volume * 100).toStringAsFixed(0)}%',
          style: TextStyle(color: Colors.white70),
        ),
        Slider(
          value: position.volume,
          onChanged: (value) => _updateVolume(_selectedTrackId!, value),
          min: 0.0,
          max: 1.0,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildPositionButton(Icons.arrow_left, () => _updatePosition(_selectedTrackId!, -0.1, 0, 0)),
            _buildPositionButton(Icons.arrow_right, () => _updatePosition(_selectedTrackId!, 0.1, 0, 0)),
            _buildPositionButton(Icons.arrow_upward, () => _updatePosition(_selectedTrackId!, 0, 0.1, 0)),
            _buildPositionButton(Icons.arrow_downward, () => _updatePosition(_selectedTrackId!, 0, -0.1, 0)),
            _buildPositionButton(Icons.arrow_drop_up, () => _updatePosition(_selectedTrackId!, 0, 0, 0.1)),
            _buildPositionButton(Icons.arrow_drop_down, () => _updatePosition(_selectedTrackId!, 0, 0, -0.1)),
          ],
        ),
      ],
    );
  }

  Widget _buildPositionButton(IconData icon, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, size: 20),
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.1),
      ),
    );
  }

    @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black.withOpacity(0.9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.white30),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Spatial Audio Mixer',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Drag tracks around the room to position them in 3D space',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRoomView(),
                const SizedBox(width: 20),
                Expanded(child: _buildTrackControls()),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
  TextButton(
    onPressed: () {
      // Revert the live 3D preview back to normal stereo
      widget.audioService.revertToStereo();
      Navigator.of(context).pop();
    },
    child: const Text('Close'),
  ),
  const SizedBox(width: 12),
  ElevatedButton(
    onPressed: () {
      _applyPositionsToAudio(_currentPositions);
      Navigator.of(context).pop(_currentPositions);
    },
    child: const Text('Apply'),
  ),
],

            ),
          ],
        ),
      ),
    );
  }
}

class _RoomGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white30
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Draw room outline
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Draw grid lines
    for (int i = 1; i < 3; i++) {
      final x = size.width / 3 * i;
      final y = size.height / 3 * i;
      
      // Vertical lines
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      // Horizontal lines
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Draw center cross
    final centerPaint = Paint()
      ..color = Colors.green.withOpacity(0.5)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      centerPaint,
    );
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      centerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}