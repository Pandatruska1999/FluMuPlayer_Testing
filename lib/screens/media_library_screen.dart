import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/player_state.dart';
import '../widgets/album_grid.dart';
import '../widgets/track_list.dart';
import '../services/media_scanner_service.dart';
import '../services/audio_service.dart';
import '../widgets/expanding_floating_player.dart';
import '../services/audio_service.dart';
import '../widgets/expanding_floating_player.dart';

class MediaLibraryScreen extends StatefulWidget {
  final PlayerState playerState;
  final ValueChanged<Track> onPlayTrack;
  final ValueChanged<String> onAddFolder;
  final MediaScannerService mediaScannerService;
  final VoidCallback onSwitchToPlayer;
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final ValueChanged<Duration> onSeek;
  final Duration position;
  final Duration duration;

  final AudioService audioService;

  const MediaLibraryScreen({
    super.key,
    required this.playerState,
    required this.onPlayTrack,
    required this.onAddFolder,
    required this.mediaScannerService,
    required this.onSwitchToPlayer,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onSeek,
    required this.position,
    required this.duration,
    required this.audioService,
  });

  @override
  State<MediaLibraryScreen> createState() => _MediaLibraryScreenState();
}

class _MediaLibraryScreenState extends State<MediaLibraryScreen> {
  int _selectedViewIndex = 0; // 0: Albums, 1: Tracks, 2: Artists
  int _previousViewIndex = 0; // Track previous view for animation direction

  // Add pagination state
  int _albumPage = 0;
  int _trackPage = 0;
  final int _pageSize = 20;
  List<Album> _loadedAlbums = [];
  List<Track> _loadedTracks = [];

  Future<void> _pickFolder(BuildContext context) async {
  try {
    print('[DEBUG] Opening folder picker...');
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    print('[DEBUG] Folder selected: $selectedDirectory');
    
    if (selectedDirectory != null) {
      print('[DEBUG] Calling onAddFolder with: $selectedDirectory');
      widget.onAddFolder(selectedDirectory);
      print('[DEBUG] onAddFolder call completed');
    } else {
      print('[DEBUG] No folder selected');
    }
  } catch (e) {
    print('[ERROR] in _pickFolder: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error selecting folder: $e')),
    );
  }
}

  Widget _buildViewSelector() {
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildViewButton(0, 'Albums', Icons.album),
          _buildViewButton(1, 'Tracks', Icons.music_note),
          _buildViewButton(2, 'Artists', Icons.person),
        ],
      ),
    );
  }

  Widget _buildViewButton(int index, String label, IconData icon) {
    final isSelected = _selectedViewIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_selectedViewIndex != index) {
            setState(() {
              _previousViewIndex = _selectedViewIndex;
              _selectedViewIndex = index;
            });
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.white70),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({Key? key}) {
  // REMOVE the loading check here - the LoadingDialog handles this now
  return Center(
    key: key,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.music_note,
          size: 64,
          color: Colors.white.withOpacity(0.3),
        ),
        const SizedBox(height: 16),
        Text(
          'Media Library Empty',
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Add music folders to get started',
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => _pickFolder(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.1),
            foregroundColor: Colors.white,
          ),
          child: const Text('Add Music Folder'),
        ),
      ],
    ),
  );
}

  Widget _buildContent() {
  final hasAlbums = widget.playerState.albums.isNotEmpty;
  final hasTracks = widget.playerState.allTracks.isNotEmpty;

  if (!hasAlbums && !hasTracks) {
    return _buildEmptyState();
  }

  return AnimatedSwitcher(
    duration: const Duration(milliseconds: 300),
    switchInCurve: Curves.easeInOut,
    switchOutCurve: Curves.easeInOut,
    transitionBuilder: (child, animation) {
      // Determine animation direction based on view change
      final isMovingForward = _selectedViewIndex > _previousViewIndex;
      
      return _buildViewTransition(child, animation, isMovingForward);
    },
    child: RepaintBoundary( // Keep the RepaintBoundary isolation
      key: ValueKey('view_$_selectedViewIndex'),
      child: _getCurrentView(),
    ),
  );
}

  Widget _buildViewTransition(Widget child, Animation<double> animation, bool isMovingForward) {
    // Subtle slide animation
    final slideAnimation = Tween<Offset>(
      begin: Offset(isMovingForward ? 0.15 : -0.15, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    ));

    // Smooth fade animation
    final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOut,
      ),
    );

    return SlideTransition(
      position: slideAnimation,
      child: FadeTransition(
        opacity: fadeAnimation,
        child: child,
      ),
    );
  }

  Widget _getCurrentView() {
  final hasAlbums = widget.playerState.albums.isNotEmpty;
  final hasTracks = widget.playerState.allTracks.isNotEmpty;
  final currentTrack = widget.playerState.playlist.isNotEmpty 
      ? widget.playerState.playlist[widget.playerState.currentIndex]
      : null;

  switch (_selectedViewIndex) {
    case 0: // Albums
      return hasAlbums
          ? AlbumGrid(
              key: const ValueKey('albums_view'),
              albums: widget.playerState.albums,
              onPlayTrack: widget.onPlayTrack,
              currentlyPlayingTrack: currentTrack,
            )
          : _buildEmptyState(key: const ValueKey('albums_empty'));
    
    case 1: // Tracks
      return hasTracks
          ? TrackList(
              key: const ValueKey('tracks_view'),
              tracks: widget.playerState.allTracks,
              onPlayTrack: widget.onPlayTrack,
              currentlyPlayingTrack: currentTrack,
            )
          : _buildEmptyState(key: const ValueKey('tracks_empty'));
      
    case 2: // Artists
      return Center(
        key: const ValueKey('artists_view'),
        child: Text(
          'Artists view coming soon',
          style: TextStyle(color: Colors.white.withOpacity(0.6)),
        ),
      );
      
    default:
      return _buildEmptyState(key: const ValueKey('default_empty'));
  }
}

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            // Header with add button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Text(
                    'Media Library',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.white),
                    onPressed: () => _pickFolder(context),
                    tooltip: 'Add music folder',
                  ),
                ],
              ),
            ),
            
            // View selector (only show if we have content)
            if (widget.playerState.albums.isNotEmpty || 
                widget.playerState.allTracks.isNotEmpty)
              _buildViewSelector(),
            
            // Content with animation
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
        
        // Floating player
        Positioned(
          left: 20.0,
          bottom: 20.0,
          child: ExpandingFloatingPlayer(
            playerState: widget.playerState,
            isPlaying: widget.isPlaying,
            onPlayPause: widget.onPlayPause,
            onOpenPlayer: widget.onSwitchToPlayer,
            onSeek: widget.onSeek,
            position: widget.position,
            duration: widget.duration,
            audioService: widget.audioService,
          ),
        ),
      ],
    );
  }
}