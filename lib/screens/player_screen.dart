import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
// REMOVE audioplayers import
// import 'package:audioplayers/audioplayers.dart' as audio;
import '../models/player_state.dart';
import '../services/audio_service.dart';
import '../services/media_scanner_service.dart';
// import '../services/color_service.dart'; // REMOVE unused import
import '../widgets/custom_title_bar.dart';
import '../widgets/album_cover.dart';
import '../widgets/player_controls.dart';
import '../widgets/progress_bar.dart';
import '../widgets/theme_toggle.dart';
import '../widgets/tab_navigation.dart';
import 'media_library_screen.dart';
import '../widgets/page_transition_switcher.dart';
import '../widgets/loading_dialog.dart';
import '../widgets/spatial_audio_mixer.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> 
    with SingleTickerProviderStateMixin {
  late final AudioService _audioService;
  late MediaScannerService _mediaScannerService;
  late AnimationController _animationController;

  // Separate audio state from UI state
  Duration _currentPosition = Duration.zero;
  Duration _currentDuration = Duration.zero;
  bool _isAudioPlaying = false;
  Timer? _positionUpdateTimer; // NEW: Timer to update position for progress bar
  
  // UI state
  PlayerState _playerState = const PlayerState();

  @override
  void initState() {
    super.initState();
    _audioService = AudioService();
    _mediaScannerService = MediaScannerService(audioService: _audioService);
    
    // NEW: Initialize SoLoud and THEN set up listeners
    _audioService.initialize().then((_) {
      print("SoLoud initialized");
      _initAudioPlayer(); // Set up listeners after init
    });
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  void _applySpatialAudio(Map<String, AudioSourcePosition> positions) {
    // NEW: Call the new method on our AudioService for each track
    positions.forEach((trackId, position) {
      _audioService.setSpatialPosition(trackId, position);
    });
    setState(() { 
      _playerState = _playerState.copyWith(spatialPositions: positions);
    });
  }

  void _openSpatialAudioMixer() {
  showDialog(
    context: context,
    builder: (context) => SpatialAudioMixer(
      playerState: _playerState,
      audioPositions: _playerState.spatialPositions,
      onPositionsChanged: _applySpatialAudio,
      audioService: _audioService, // ✅ add this
    ),
  );
}


  @override
  void dispose() {
    _audioService.dispose();
    _animationController.dispose();
    _positionUpdateTimer?.cancel(); // NEW: Cancel the timer
    super.dispose();
  }

  void _initAudioPlayer() {
  _positionUpdateTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
    setState(() {
      _currentPosition = _audioService.position;  
      _currentDuration = _audioService.duration;   
      _isAudioPlaying = _audioService.isPlaying;  
    });
  });
}


  Future<void> _handleAddFolder(String folderPath) async {
    setState(() {
      _playerState = _playerState.copyWith(isLoading: true);
    });

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const LoadingDialog(
          title: 'Scanning folder...',
          subtitle: 'This may take a moment depending on the size of your library',
        ),
      );
      final tracks = await _mediaScannerService.scanDirectory(folderPath);
      
      final albums = _mediaScannerService.organizeTracksIntoAlbums(tracks);
      
      Navigator.of(context).pop(); // Close progress dialog
      
      setState(() {
        final newFolders = List<String>.from(_playerState.mediaFolders)..add(folderPath);
        _playerState = _playerState.copyWith(
          mediaFolders: newFolders,
          albums: albums,
          allTracks: tracks,
          isLoading: false,
        );
      });
      print('[DEBUG] State updated successfully');
    } catch (e) {
      print('[ERROR] in _handleAddFolder: $e');
      Navigator.of(context).pop(); // Close progress dialog on error
      setState(() {
        _playerState = _playerState.copyWith(isLoading: false);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error scanning folder: $e')),
      );
    }
  }

  // REMOVE: _showScanningProgressDialog() is unused

  void _handlePlayTrack(Track track) {
    _audioService.play(track.path);
    // Update current track info WITHOUT switching tabs
    setState(() {
      _playerState = _playerState.copyWith(
        playlist: [track],
        currentIndex: 0,
      );
    });
  }

  void _handlePlayPause() {
    if (_isAudioPlaying) {
      _audioService.pause();
      setState(() { _isAudioPlaying = false; }); // NEW: Update state directly
    } else {
      if (_playerState.playlist.isNotEmpty) {
        final track = _playerState.playlist[_playerState.currentIndex];
        // NEW: Simplified logic - just play/resume
        if (_isAudioPlaying) {
          _audioService.resume();
        } else {
          _audioService.play(track.path);
        }
        setState(() { _isAudioPlaying = true; }); // NEW: Update state directly
      }
    }
  }

  void _handleSeek(Duration position) {
    _audioService.seek(position);
    setState(() {
      _currentPosition = position;
    });
  }

  void _handleVolumeChange(double volume) {
    _audioService.setVolume(volume);
    setState(() {
      _playerState = _playerState.copyWith(
        volume: volume,
        isMuted: volume == 0.0,
      );
    });
  }

  void _handleToggleMute() {
    final newVolume = _playerState.isMuted ? 0.7 : 0.0;
    _handleVolumeChange(newVolume);
  }

  void _handleThemeToggle(bool value) {
    setState(() {
      _playerState = _playerState.copyWith(isDarkMode: value);
    });
  }

  void _handleTabChange(int index) {
    setState(() {
      _playerState = _playerState.copyWith(selectedTabIndex: index);
    });
  }

  Widget _buildPlayerTab() {
    final hasCurrentTrack = _playerState.playlist.isNotEmpty;
    final currentTrack = hasCurrentTrack 
        ? _playerState.playlist[_playerState.currentIndex]
        : null;

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 20),
          AlbumCover(
            primaryColor: _playerState.primaryColor,
            secondaryColor: _playerState.secondaryColor,
          ),
          const SizedBox(height: 24),
          
          Text(
            hasCurrentTrack ? currentTrack!.displayTitle : 'No track selected',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white.withOpacity(0.9),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            hasCurrentTrack 
              ? '${currentTrack!.displayArtist} • ${currentTrack.displayAlbum}'
              : 'Select a track from Media Library',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          
          // Progress bar with its own state management
          _buildProgressBar(),
          const SizedBox(height: 32),
          
          PlayerControls(
            isPlaying: _isAudioPlaying, // Use audio state
            isMuted: _playerState.isMuted,
            volume: _playerState.volume,
            onPlayPause: _handlePlayPause,
            onPrevious: () {},
            onNext: () {},
            onToggleMute: _handleToggleMute,
            onVolumeChanged: _handleVolumeChange,
          ),
          
          const SizedBox(height: 32),
          
          ThemeToggle(
            isDarkMode: _playerState.isDarkMode,
            onChanged: _handleThemeToggle,
          ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // Separate widget for progress bar to isolate rebuilds
  Widget _buildProgressBar() {
    return ProgressBar(
      position: _currentPosition,
      duration: _currentDuration,
      onSeek: _handleSeek,
    );
  }

  // Optimized background with reduced blur
  Widget _buildOptimizedBackground() {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _playerState.primaryColor,
                  _playerState.secondaryColor,
                ],
              ),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0), // Reduced from 15.0
              child: Container(
                color: Colors.black.withOpacity(0.2),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          _buildOptimizedBackground(),
          
          // Hauptinhalt
          Column(
            children: [
              CustomTitleBar(
                title: 'Production Sheet',
                isDarkMode: _playerState.isDarkMode,
              ),
              
              TabNavigation(
                selectedIndex: _playerState.selectedTabIndex,
                onTabSelected: _handleTabChange,
              ),
              
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: PageTransitionSwitcher(
                    duration: const Duration(milliseconds: 400),
                    reverse: _playerState.selectedTabIndex == 0,
                    transitionBuilder: (child, animation) {
                      final slideAnimation = Tween<Offset>(
                        begin: _playerState.selectedTabIndex == 0 
                            ? const Offset(1, 0) 
                            : const Offset(-1, 0),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeInOutCubic,
                      ));
                      
                      return SlideTransition(
                        position: slideAnimation,
                        child: FadeTransition(
                          opacity: animation,
                          child: child,
                        ),
                      );
                    },
                    child: _playerState.selectedTabIndex == 0
                      ? _buildPlayerTab()
                      : MediaLibraryScreen(
                          key: const ValueKey('media_library'),
                          playerState: _playerState,
                          onPlayTrack: _handlePlayTrack,
                          onAddFolder: _handleAddFolder,
                          mediaScannerService: _mediaScannerService,
                          onSwitchToPlayer: () => _handleTabChange(0),
                          isPlaying: _isAudioPlaying,
                          onPlayPause: _handlePlayPause,
                          onSeek: _handleSeek,
                          position: _currentPosition,
                          duration: _currentDuration,
                          audioService: _audioService,
                        ),
                  ),
                ),
              ),
            ],
          ),

          if (_playerState.selectedTabIndex == 0) // Only show on player tab
            Positioned(
              left: 20,
              bottom: 100,
              child: IconButton(
                icon: Icon(Icons.surround_sound, 
                  color: Colors.white.withOpacity(0.8),
                  size: 28,
                ),
                onPressed: _openSpatialAudioMixer,
                tooltip: 'Spatial Audio Mixer',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withOpacity(0.5),
                  padding: const EdgeInsets.all(12),
                ),
              ),
            ),
          
          if (_playerState.isLoading)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}