import 'package:flutter/material.dart';
import 'spring_button.dart';

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
        SpringButton(
          onPressed: onPrevious,
          child: IconButton(
            icon: const Icon(Icons.skip_previous, size: 32),
            color: Colors.white,
            onPressed: onPrevious,
          ),
        ),
        
        const SizedBox(width: 24),
        
        SpringButton(
          onPressed: onPlayPause,
          scaleFactor: 0.85,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.2),
            ),
            child: Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              size: 36,
              color: Colors.white,
            ),
          ),
        ),
        
        const SizedBox(width: 24),
        
        SpringButton(
          onPressed: onNext,
          child: IconButton(
            icon: const Icon(Icons.skip_next, size: 32),
            color: Colors.white,
            onPressed: onNext,
          ),
        ),
      ],
    );
  }
}