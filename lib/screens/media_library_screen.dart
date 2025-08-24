import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/player_state.dart';
import '../widgets/album_grid.dart';
import '../widgets/track_list.dart';
import '../services/media_scanner_service.dart';
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
  int _selectedViewIndex = 0;
  int _previousViewIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _pageController.addListener(_pageListener);
  }

  @override
  void dispose() {
    _pageController.removeListener(_pageListener);
    _pageController.dispose();
    super.dispose();
  }

  void _pageListener() {
    final page = _pageController.page?.round() ?? 0;
    if (page != _selectedViewIndex) {
      setState(() {
        _previousViewIndex = _selectedViewIndex;
        _selectedViewIndex = page;
      });
    }
  }

  Future<void> _pickFolder(BuildContext context) async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      
      if (selectedDirectory != null) {
        widget.onAddFolder(selectedDirectory);
      }
    } catch (e) {
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
        onTap: () => _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        ),
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

  Widget _buildEmptyState() {
    return Center(
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

    return PageView(
      controller: _pageController,
      children: [
        _buildAlbumsView(),
        _buildTracksView(),
        _buildArtistsView(),
      ],
    );
  }

  Widget _buildAlbumsView() {
    final hasAlbums = widget.playerState.albums.isNotEmpty;
    final currentTrack = widget.playerState.playlist.isNotEmpty 
        ? widget.playerState.playlist[widget.playerState.currentIndex]
        : null;

    return hasAlbums
        ? AlbumGrid(
            key: const ValueKey('albums_view'),
            albums: widget.playerState.albums,
            onPlayTrack: widget.onPlayTrack,
            currentlyPlayingTrack: currentTrack,
          )
        : _buildEmptyState();
  }

  Widget _buildTracksView() {
    final hasTracks = widget.playerState.allTracks.isNotEmpty;
    final currentTrack = widget.playerState.playlist.isNotEmpty 
        ? widget.playerState.playlist[widget.playerState.currentIndex]
        : null;

    return hasTracks
        ? TrackList(
            key: const ValueKey('tracks_view'),
            tracks: widget.playerState.allTracks,
            onPlayTrack: widget.onPlayTrack,
            currentlyPlayingTrack: currentTrack,
          )
        : _buildEmptyState();
  }

  Widget _buildArtistsView() {
    return Center(
      child: Text(
        'Artists view coming soon',
        style: TextStyle(color: Colors.white.withOpacity(0.6)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
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
            
            if (widget.playerState.albums.isNotEmpty || 
                widget.playerState.allTracks.isNotEmpty)
              _buildViewSelector(),
            
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
        
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