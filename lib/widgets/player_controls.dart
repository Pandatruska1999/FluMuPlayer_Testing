import 'package:flutter/material.dart';

class PlayerControls extends StatelessWidget {
  final bool isPlaying;
  final bool isMuted;
  final double volume;
  final VoidCallback onPlayPause;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToggleMute;
  final ValueChanged<double> onVolumeChanged;

  const PlayerControls({
    super.key,
    required this.isPlaying,
    required this.isMuted,
    required this.volume,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
    required this.onToggleMute,
    required this.onVolumeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.skip_previous, size: 32),
          color: Colors.white,
          onPressed: onPrevious,
        ),
        const SizedBox(width: 24),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              size: 36,
            ),
            color: Colors.white,
            onPressed: onPlayPause,
          ),
        ),
        const SizedBox(width: 24),
        IconButton(
          icon: const Icon(Icons.skip_next, size: 32),
          color: Colors.white,
          onPressed: onNext,
        ),
        const SizedBox(width: 32),
        IconButton(
          icon: Icon(
            isMuted ? Icons.volume_off : Icons.volume_up,
            size: 24,
          ),
          color: Colors.white,
          onPressed: onToggleMute,
        ),
        SizedBox(
          width: 100,
          child: Slider(
            value: volume,
            onChanged: onVolumeChanged,
            activeColor: Colors.white,
            inactiveColor: Colors.white.withOpacity(0.3),
          ),
        ),
      ],
    );
  }
}