// lib/widgets/playlist_dialog.dart
import 'package:flutter/material.dart';
import '../models/player_state.dart';
import '../services/playlist_manager.dart';
import '../services/cache_service.dart';
import '../services/audio_service.dart';
import 'dart:typed_data';

class PlaylistDialog extends StatefulWidget {
  final ValueChanged<Track> onTrackSelected;
  final VoidCallback onDismiss;
  final AudioService audioService; // Add audioService parameter

  const PlaylistDialog({
    super.key,
    required this.onTrackSelected,
    required this.onDismiss,
    required this.audioService, // Add audioService parameter
  });

  @override
  State<PlaylistDialog> createState() => _PlaylistDialogState();
}

class _PlaylistDialogState extends State<PlaylistDialog> {
  DateTime _lastSelectionTime = DateTime.now(); // Add this variable

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black.withOpacity(0.9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: Container(
        width: 400,
        height: 500,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Playlist',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: widget.onDismiss,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _buildPlaylist(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylist() {
    if (PlaylistManager.playlist.isEmpty) {
      return Center(
        child: Text(
          'Playlist is empty',
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 16,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: PlaylistManager.playlist.length,
      itemBuilder: (context, index) {
        final track = PlaylistManager.playlist[index];
        final isCurrent = index == PlaylistManager.currentIndex;
        
        return _PlaylistItem(
          track: track,
          isCurrent: isCurrent,
          audioService: widget.audioService, // Pass audioService
          onTap: () {
            // Prevent rapid selection
            final now = DateTime.now();
            if (now.difference(_lastSelectionTime) < Duration(milliseconds: 500)) {
              return;
            }
            _lastSelectionTime = now;
  
            PlaylistManager.setCurrentIndex(index);
            widget.onTrackSelected(track);
          },
          onRemove: () {
            setState(() {
              PlaylistManager.removeFromPlaylist(index);
            });
          },
        );
      },
    );
  }
}

class _PlaylistItem extends StatelessWidget {
  final Track track;
  final bool isCurrent;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final AudioService audioService; // Add audioService parameter

  const _PlaylistItem({
    required this.track,
    required this.isCurrent,
    required this.onTap,
    required this.onRemove,
    required this.audioService, // Add audioService parameter
  });

  @override
  Widget build(BuildContext context) {
    final isCurrentlyPlaying = isCurrent && 
        audioService.currentFilePath == track.path &&
        audioService.isPlaying;
    
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      leading: Stack(
        children: [
          FutureBuilder<Uint8List?>(
            future: AlbumCoverCache.getAlbumCover(track.albumArtPath, size: 40),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                return Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    image: DecorationImage(
                      image: MemoryImage(snapshot.data!),
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              }
              return Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.blue.withOpacity(0.3),
                ),
                child: const Icon(Icons.music_note, size: 20, color: Colors.white70),
              );
            },
          ),
          if (isCurrentlyPlaying)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.play_arrow,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
      title: Text(
        track.displayTitle,
        style: TextStyle(
          color: isCurrent ? Colors.blue : Colors.white,
          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          fontSize: 14,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        track.displayArtist,
        style: TextStyle(
          color: isCurrent ? Colors.blue.withOpacity(0.8) : Colors.white70,
          fontSize: 12,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        icon: const Icon(Icons.close, size: 16, color: Colors.white70),
        onPressed: onRemove,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
      onTap: onTap,
    );
  }
}