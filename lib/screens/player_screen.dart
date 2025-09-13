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
  import 'dart:typed_data';
  import 'package:image/image.dart' as img;
  import '../services/cache_service.dart';
  import 'enhanced_player_screen.dart';
  import 'morph_transition.dart';
  import '../services/playlist_manager.dart';
  import '../widgets/floating_playlist_button.dart';

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

    bool _isProcessingPlayRequest = false;

    DateTime _lastPlayTime = DateTime.now();

    List<Color> _currentTrackColors = [Colors.blue, Colors.purple, Colors.pink];


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
    
    PlaylistManager.addListener(_handlePlaylistChanged);

    _audioService.initialize().then((_) {
      print("SoLoud initialized");
      _initAudioPlayer();
    });
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
    
    // Initialize with multiple colors
    _currentTrackColors = [
      Colors.blue.withOpacity(0.7),
      Colors.purple.withOpacity(0.7),
      Colors.pink.withOpacity(0.7),
    ];

    PlaylistManager.addListener(_handlePlaylistChanged);
  }

    void _openEnhancedPlayerView() {
    if (_playerState.playlist.isEmpty) return;
    
    final currentTrack = _playerState.playlist[_playerState.currentIndex];
    
    showGeneralDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      barrierDismissible: true,
      barrierLabel: "Close enhanced player", // ADD THIS LINE
      transitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (context, animation, secondaryAnimation) {
        return MorphTransition(
          isOpen: true,
          child: EnhancedPlayerScreen(
            currentTrack: currentTrack,
            isPlaying: _isAudioPlaying,
            position: _currentPosition,
            duration: _currentDuration,
            onPlayPause: _handlePlayPause,
            onSeek: _handleSeek,
            onClose: () => Navigator.of(context).pop(),
            audioService: _audioService,
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOutCubic,
        );
        
        return ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(curvedAnimation),
          child: FadeTransition(
            opacity: curvedAnimation,
            child: child,
          ),
        );
      },
    );
  }

    void _handleNext() {
    if (PlaylistManager.playlist.isEmpty) return;
    
    PlaylistManager.nextTrack();
    final nextTrack = PlaylistManager.currentTrack;
    if (nextTrack != null) {
      _audioService.play(nextTrack.path);
      _updateTrackColors(nextTrack);
      setState(() {
        _playerState = _playerState.copyWith(
          playlist: PlaylistManager.playlist,
          currentIndex: PlaylistManager.currentIndex,
        );
      });
    }
  }

  void _handlePrevious() {
    if (PlaylistManager.playlist.isEmpty) return;
    
    PlaylistManager.previousTrack();
    final previousTrack = PlaylistManager.currentTrack;
    if (previousTrack != null) {
      _audioService.play(previousTrack.path);
      _updateTrackColors(previousTrack);
      setState(() {
        _playerState = _playerState.copyWith(
          playlist: PlaylistManager.playlist,
          currentIndex: PlaylistManager.currentIndex,
        );
      });
    }
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
      PlaylistManager.removeListener(_handlePlaylistChanged);
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

void _handlePlayTrack(Track track) async {
  // Prevent rapid clicking (at least 200ms between plays)
  final now = DateTime.now();
  if (now.difference(_lastPlayTime) < Duration(milliseconds: 200)) {
    return;
  }
  _lastPlayTime = now;
  
  // If already processing a play request, ignore this one
  if (_isProcessingPlayRequest) {
    return;
  }
  
  _isProcessingPlayRequest = true;
  
  try {
    // If the same track is already playing, just toggle play/pause
    if (_audioService.isTrackPlaying(track.path)) {
      _handlePlayPause();
      return;
    }
    
    // Stop any currently playing track before starting a new one
    await _audioService.stop();
    
    // Add to playlist if not already there
    if (!PlaylistManager.playlist.any((t) => t.path == track.path)) {
      PlaylistManager.addToPlaylist(track);
    }
    
    // Set as current track
    final index = PlaylistManager.playlist.indexWhere((t) => t.path == track.path);
    if (index != -1) {
      PlaylistManager.setCurrentIndex(index);
    }
    
    await _audioService.play(track.path);
    _updateTrackColors(track);
    
    // Update current track info WITHOUT switching tabs
    if (mounted) {
      setState(() {
        _playerState = _playerState.copyWith(
          playlist: PlaylistManager.playlist,
          currentIndex: PlaylistManager.currentIndex,
        );
        _isAudioPlaying = true;
      });
    }
  } catch (e) {
    print('Error playing track: $e');
  } finally {
    _isProcessingPlayRequest = false;
  }
}
  // In your _PlayerScreenState class, modify the _handlePlaylistChanged method
void _handlePlaylistChanged() {
  // Check if the currently playing track is still in the playlist
  final currentTrackPath = _audioService.currentFilePath;
  if (currentTrackPath != null) {
    final isTrackStillInPlaylist = PlaylistManager.playlist
        .any((track) => track.path == currentTrackPath);
    
    if (!isTrackStillInPlaylist) {
      // The currently playing track was removed from the playlist
      _audioService.stop();
      setState(() {
        _isAudioPlaying = false;
      });
    }
  }
  
  setState(() {
    _playerState = _playerState.copyWith(
      playlist: PlaylistManager.playlist,
      currentIndex: PlaylistManager.currentIndex,
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

    Future<List<Color>> _sampleAlbumColors(String? imagePath) async {
    if (imagePath == null) return [_playerState.primaryColor, _playerState.secondaryColor];
    
    try {
      final coverData = await AlbumCoverCache.getAlbumCover(imagePath);
      if (coverData != null && coverData.isNotEmpty) {
        final image = img.decodeImage(coverData);
        if (image != null) {
          // Sample colors from different regions of the image
          final List<Offset> samplePoints = [
            Offset(image.width * 0.2, image.height * 0.2), // Top-left
            Offset(image.width * 0.8, image.height * 0.2), // Top-right
            Offset(image.width * 0.5, image.height * 0.5), // Center
            Offset(image.width * 0.2, image.height * 0.8), // Bottom-left
            Offset(image.width * 0.8, image.height * 0.8), // Bottom-right
          ];
          
          final List<Color> colors = [];
          
          for (final point in samplePoints) {
            final x = point.dx.toInt();
            final y = point.dy.toInt();
            if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
              final pixel = image.getPixel(x, y);
              // Create a color from the pixel data
              final color = Color.fromRGBO(
                pixel.r.toInt(),
                pixel.g.toInt(),
                pixel.b.toInt(),
                1.0,
              );
              colors.add(color);
            }
          }
          
          return colors;
        }
      }
    } catch (e) {
      print('Error sampling colors: $e');
    }
    
    // Fallback colors
    return [
      Colors.blue.withOpacity(0.7),
      Colors.purple.withOpacity(0.7),
      Colors.pink.withOpacity(0.7),
    ];
  }

  void _updateTrackColors(Track track) async {
    final sampledColors = await _sampleAlbumColors(track.albumArtPath);
    setState(() {
      _currentTrackColors = sampledColors;
    });
  }

  Widget _buildCurrentAlbumCover(Track? currentTrack) {
    if (currentTrack == null || currentTrack.albumArtPath == null) {
      return GestureDetector(
        onTap: _openEnhancedPlayerView,
        child: AlbumCover(
          primaryColor: _playerState.primaryColor,
          secondaryColor: _playerState.secondaryColor,
        ),
      );
    }

    return GestureDetector(
      onTap: _openEnhancedPlayerView,
      child: FutureBuilder<Uint8List?>(
        future: AlbumCoverCache.getAlbumCover(currentTrack.albumArtPath, size: 280),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            return Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  )
                ],
                image: DecorationImage(
                  image: MemoryImage(snapshot.data!),
                  fit: BoxFit.cover,
                ),
              ),
            );
          } else {
            return AlbumCover(
              primaryColor: _playerState.primaryColor,
              secondaryColor: _playerState.secondaryColor,
            );
          }
        },
      ),
    );
  }

  Widget _buildLightLeaks(List<Color> colors) {
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.8,
            colors: [
              colors[0].withOpacity(0.15),
              colors[1 % colors.length].withOpacity(0.1),
              colors[2 % colors.length].withOpacity(0.05),
              Colors.transparent,
            ],
            stops: const [0.0, 0.2, 0.4, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildOledElements() {
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.9),
            ],
          ),
        ),
      ),
    );
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
            _buildCurrentAlbumCover(currentTrack),
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
              onPrevious: _handlePrevious,  // Updated
              onNext: _handleNext,          // Updated
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
    return Stack(
      children: [
        RepaintBoundary(
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
                  filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                  child: Container(
                    color: Colors.black.withOpacity(0.2),
                  ),
                ),
              );
            },
          ),
        ),
        _buildLightLeaks(_currentTrackColors),
        _buildOledElements(),
      ],
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

              FloatingPlaylistButton(
            onTrackSelected: _handlePlayTrack,
            playlistItemCount: PlaylistManager.playlist.length,
            audioService: _audioService,
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