import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/player_state.dart';
import '../services/cache_service.dart';

class FloatingPlayer extends StatelessWidget {
  final PlayerState playerState;
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback onOpenPlayer;

  const FloatingPlayer({
    super.key,
    required this.playerState,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onOpenPlayer,
  });

  @override
  Widget build(BuildContext context) {
    final hasCurrentTrack = playerState.playlist.isNotEmpty;
    final currentTrack = hasCurrentTrack 
        ? playerState.playlist[playerState.currentIndex]
        : null;

    if (!hasCurrentTrack || currentTrack == null) {
      return const SizedBox.shrink();
    }

    return AnimatedSlide(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      offset: const Offset(0, 0), // Always visible when called
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 15,
              spreadRadius: 3,
            ),
          ],
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Album cover with caching
            FutureBuilder<Uint8List?>(
              future: currentTrack.albumArtPath != null 
                  ? AlbumCoverCache.getAlbumCover(currentTrack.albumArtPath!, size: 40)
                  : Future.value(null),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  return Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      image: DecorationImage(
                        image: MemoryImage(snapshot.data!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                } else {
                  return Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: Colors.blue.withOpacity(0.3),
                    ),
                    child: const Icon(Icons.music_note, size: 20, color: Colors.white70),
                  );
                }
              },
            ),
            
            const SizedBox(width: 12),
            
            // Track info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    currentTrack.displayTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    currentTrack.displayArtist,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            
            // Play/Pause button
            IconButton(
              icon: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 24,
              ),
              onPressed: onPlayPause,
            ),
            
            // Open player button
            IconButton(
              icon: const Icon(
                Icons.open_in_full,
                color: Colors.white,
                size: 20,
              ),
              onPressed: onOpenPlayer,
            ),
          ],
        ),
      ),
    );
  }
}