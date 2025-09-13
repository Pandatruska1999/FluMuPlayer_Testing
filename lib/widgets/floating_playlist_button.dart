// lib/widgets/floating_playlist_button.dart
import 'package:flutter/material.dart';
import '../services/playlist_manager.dart';
import '../models/player_state.dart';
import 'playlist_dialog.dart';
import '../services/audio_service.dart';

class FloatingPlaylistButton extends StatefulWidget {
  final ValueChanged<Track> onTrackSelected;
  final int playlistItemCount;
  final AudioService audioService;

  const FloatingPlaylistButton({
    super.key,
    required this.onTrackSelected,
    required this.playlistItemCount,
    required this.audioService,
  });

  @override
  State<FloatingPlaylistButton> createState() => _FloatingPlaylistButtonState();
}

class _FloatingPlaylistButtonState extends State<FloatingPlaylistButton> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isDialogOpen = false;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isDialogOpen = false;
  }

  void _toggleDialog() {
    if (_isDialogOpen) {
      _removeOverlay();
    } else {
      _showDialog();
    }
  }

  void _showDialog() {
  final overlayState = Overlay.of(context);
  
  _overlayEntry = OverlayEntry(
    builder: (context) => Stack(
      children: [
        // Semi-transparent background
        GestureDetector(
          onTap: _removeOverlay,
          child: Container(
            color: Colors.black.withOpacity(0.5),
          ),
        ),
        // Playlist dialog
        Center(
          child: PlaylistDialog(
            onTrackSelected: (track) {
              widget.onTrackSelected(track);
              _removeOverlay();
            },
            onDismiss: _removeOverlay,
            audioService: widget.audioService, // Pass the audio service
          ),
        ),
      ],
    ),
  );
  
  overlayState.insert(_overlayEntry!);
  _isDialogOpen = true;
}

  void _animateButton() {
    if (_animationController.status == AnimationStatus.completed) {
      _animationController.reverse();
    } else {
      _animationController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 20,
      bottom: 160,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: FloatingActionButton(
          onPressed: () {
            _animateButton();
            _toggleDialog();
          },
          backgroundColor: Colors.black.withOpacity(0.8),
          mini: true,
          child: Stack(
            children: [
              const Icon(Icons.queue_music, size: 20, color: Colors.white),
              if (widget.playlistItemCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      widget.playlistItemCount > 9 ? '9+' : widget.playlistItemCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}