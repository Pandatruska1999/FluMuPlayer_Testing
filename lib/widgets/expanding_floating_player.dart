import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/player_state.dart';
import '../services/cache_service.dart';
import '../widgets/progress_bar.dart';
import '../widgets/spatial_audio_mixer.dart';
import '../services/audio_service.dart';

class ExpandingFloatingPlayer extends StatefulWidget {
  final PlayerState playerState;
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback onOpenPlayer;
  final ValueChanged<Duration> onSeek;
  final Duration position;
  final Duration duration;

  final AudioService audioService;

  const ExpandingFloatingPlayer({
    super.key,
    required this.playerState,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onOpenPlayer,
    required this.onSeek,
    required this.position,
    required this.duration,
    required this.audioService,
  });

  @override
  State<ExpandingFloatingPlayer> createState() => _ExpandingFloatingPlayerState();
}

class _ExpandingFloatingPlayerState extends State<ExpandingFloatingPlayer>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  final double _minimizedHeight = 90.0;
  final double _expandedHeight = 260.0;
  final double _minimizedWidth = 320.0;
  final double _expandedWidth = 400.0;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );
    
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Play pop-in animation
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasCurrentTrack = widget.playerState.playlist.isNotEmpty;
    final currentTrack = hasCurrentTrack 
        ? widget.playerState.playlist[widget.playerState.currentIndex]
        : null;

    if (!hasCurrentTrack || currentTrack == null) {
      return const SizedBox.shrink();
    }

    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: _isExpanded ? _expandedWidth : _minimizedWidth,
          height: _isExpanded ? _expandedHeight : _minimizedHeight,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.95),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 25,
                spreadRadius: 8,
              ),
            ],
            border: Border.all(
              color: Colors.white.withOpacity(0.4),
              width: 1.5,
            ),
          ),
          child: _isExpanded ? _buildExpandedView(currentTrack) : _buildMinimizedView(currentTrack),
        ),
      ),
    );
  }

  Widget _buildMinimizedView(Track currentTrack) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Album cover
          FutureBuilder<Uint8List?>(
            future: currentTrack.albumArtPath != null 
                ? AlbumCoverCache.getAlbumCover(currentTrack.albumArtPath!, size: 48)
                : Future.value(null),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                return Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: MemoryImage(snapshot.data!),
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              } else {
                return Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.blue.withOpacity(0.4),
                  ),
                  child: const Icon(Icons.music_note, size: 24, color: Colors.white70),
                );
              }
            },
          ),
          
          const SizedBox(width: 16),
          
          // Track info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  currentTrack.displayTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  currentTrack.displayArtist,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
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
              widget.isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 28,
            ),
            onPressed: widget.onPlayPause,
          ),
          
          // Expand button
          IconButton(
            icon: const Icon(
              Icons.expand,
              color: Colors.white,
              size: 24,
            ),
            onPressed: _toggleExpand,
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedView(Track currentTrack) {
  return Padding(
    padding: const EdgeInsets.all(20),
    child: SingleChildScrollView(
      child: Column(
        children: [
          // Header with minimize button
          Row(
            children: [
              // Album cover
              FutureBuilder<Uint8List?>(
                future: currentTrack.albumArtPath != null 
                    ? AlbumCoverCache.getAlbumCover(currentTrack.albumArtPath!, size: 72)
                    : Future.value(null),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    return Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        image: DecorationImage(
                          image: MemoryImage(snapshot.data!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  } else {
                    return Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.blue.withOpacity(0.4),
                      ),
                      child: const Icon(Icons.music_note, size: 36, color: Colors.white70),
                    );
                  }
                },
              ),
              
              const SizedBox(width: 16),
              
              // Track info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentTrack.displayTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentTrack.displayArtist,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              // Minimize button
              IconButton(
                icon: const Icon(
                  Icons.minimize,
                  color: Colors.white,
                  size: 24,
                ),
                onPressed: _toggleExpand,
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Progress bar for scrubbing
          ProgressBar(
            position: widget.position,
            duration: widget.duration,
            onSeek: widget.onSeek,
          ),
          
          const SizedBox(height: 20),
          
          // Playback controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(
                  widget.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 36,
                ),
                onPressed: widget.onPlayPause,
              ),
              
              const SizedBox(width: 32),

              IconButton(
                icon: const Icon(
                  Icons.surround_sound,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => SpatialAudioMixer(
                      playerState: widget.playerState,
                      audioPositions: {},
                      onPositionsChanged: (positions) {
                        // Handle position changes
                      },
                      audioService: widget.audioService,
                    ),
                  );
                },
                tooltip: 'Spatial Audio Mixer',
              ),
              
              // Open player button (full screen)
              IconButton(
                icon: const Icon(
                  Icons.open_in_full,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: widget.onOpenPlayer,
              ),
            ],
          ),
        ],
      ),
    ),
  );
}}