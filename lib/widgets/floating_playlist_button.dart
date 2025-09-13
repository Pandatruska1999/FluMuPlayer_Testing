// lib/widgets/floating_playlist_button.dart
import 'package:flutter/material.dart';
import '../services/playlist_manager.dart';
import '../models/player_state.dart';
import 'playlist_dialog.dart';

class FloatingPlaylistButton extends StatefulWidget {
  final ValueChanged<Track> onTrackSelected;
  final int playlistItemCount;

  const FloatingPlaylistButton({
    super.key,
    required this.onTrackSelected,
    required this.playlistItemCount,
  });

  @override
  State<FloatingPlaylistButton> createState() => _FloatingPlaylistButtonState();
}

class _FloatingPlaylistButtonState extends State<FloatingPlaylistButton> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isDialogOpen = false;

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
    super.dispose();
  }

  void _toggleDialog() {
    if (_isDialogOpen) {
      Navigator.of(context).pop();
      _isDialogOpen = false;
    } else {
      showDialog(
        context: context,
        builder: (context) => PlaylistDialog(
          onTrackSelected: (track) {
            widget.onTrackSelected(track);
            Navigator.of(context).pop();
            _isDialogOpen = false;
          },
          onDismiss: () {
            Navigator.of(context).pop();
            _isDialogOpen = false;
          },
        ),
      );
      _isDialogOpen = true;
    }
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
      bottom: 160, // Positioned above the spatial audio button
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