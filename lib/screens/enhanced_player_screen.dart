import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/player_state.dart';
import '../services/audio_service.dart';
import '../services/cache_service.dart';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'morph_transition.dart';

class EnhancedPlayerScreen extends StatefulWidget {
  final Track? currentTrack;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final VoidCallback onPlayPause;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onClose;
  final AudioService audioService;

  const EnhancedPlayerScreen({
    super.key,
    required this.currentTrack,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.onPlayPause,
    required this.onSeek,
    required this.onClose,
    required this.audioService,
  });

  @override
  State<EnhancedPlayerScreen> createState() => _EnhancedPlayerScreenState();
}

class _EnhancedPlayerScreenState extends State<EnhancedPlayerScreen> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  List<Color> _currentTrackColors = [
    Colors.blue.withOpacity(0.7),
    Colors.purple.withOpacity(0.7),
    Colors.pink.withOpacity(0.7),
  ];

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    _opacityAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.currentTrack != null) {
      _updateTrackColors(widget.currentTrack!);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<List<Color>> _sampleAlbumColors(String? imagePath) async {
    if (imagePath == null) return _currentTrackColors;
    
    try {
      final coverData = await AlbumCoverCache.getAlbumCover(imagePath);
      if (coverData != null && coverData.isNotEmpty) {
        final image = img.decodeImage(coverData);
        if (image != null) {
          final List<Offset> samplePoints = [
            Offset(image.width * 0.2, image.height * 0.2),
            Offset(image.width * 0.8, image.height * 0.2),
            Offset(image.width * 0.5, image.height * 0.5),
            Offset(image.width * 0.2, image.height * 0.8),
            Offset(image.width * 0.8, image.height * 0.8),
          ];
          
          final List<Color> colors = [];
          
          for (final point in samplePoints) {
            final x = point.dx.toInt();
            final y = point.dy.toInt();
            if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
              final pixel = image.getPixel(x, y);
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
    
    return _currentTrackColors;
  }

  void _updateTrackColors(Track track) async {
    final sampledColors = await _sampleAlbumColors(track.albumArtPath);
    setState(() {
      _currentTrackColors = sampledColors;
    });
  }

  Widget _buildEnhancedAlbumCover() {
    final currentTrack = widget.currentTrack;
    
    if (currentTrack == null || currentTrack.albumArtPath == null) {
      return Container(
        width: 320,
        height: 320,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _currentTrackColors,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 30,
              spreadRadius: 5,
            )
          ],
        ),
        child: const Icon(
          Icons.music_note,
          size: 80,
          color: Colors.white70,
        ),
      );
    }

    return FutureBuilder<Uint8List?>(
      future: AlbumCoverCache.getAlbumCover(currentTrack.albumArtPath, size: 320),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 30,
                        spreadRadius: 5,
                      )
                    ],
                    image: DecorationImage(
                      image: MemoryImage(snapshot.data!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              );
            },
          );
        } else {
          return Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _currentTrackColors,
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildDynamicBackground() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.5,
              colors: [
                _currentTrackColors[0].withOpacity(_opacityAnimation.value * 0.3),
                _currentTrackColors[1 % _currentTrackColors.length].withOpacity(_opacityAnimation.value * 0.2),
                _currentTrackColors[2 % _currentTrackColors.length].withOpacity(_opacityAnimation.value * 0.1),
                Colors.transparent,
              ],
              stops: const [0.0, 0.3, 0.6, 1.0],
            ),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
            child: Container(
              color: Colors.black.withOpacity(0.4),
            ),
          ),
        );
      },
    );
  }

  Widget _buildParticleEffects() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return CustomPaint(
            painter: _ParticlePainter(
              animationValue: _animationController.value,
              colors: _currentTrackColors,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }

  Widget _buildLightLeaks() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(
                  -0.5 + _animationController.value * 0.2,
                  -0.3 + _animationController.value * 0.1,
                ),
                radius: 1.8,
                colors: [
                  _currentTrackColors[0].withOpacity(0.2),
                  _currentTrackColors[1 % _currentTrackColors.length].withOpacity(0.15),
                  _currentTrackColors[2 % _currentTrackColors.length].withOpacity(0.1),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.2, 0.4, 1.0],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgressBar() {
  return Container(
    width: 300,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: RoundSliderOverlayShape(overlayRadius: 12),
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white30,
            thumbColor: Colors.white,
            overlayColor: Colors.white.withOpacity(0.2),
          ),
          child: Slider(
            value: widget.position.inMilliseconds.toDouble(),
            min: 0,
            max: widget.duration.inMilliseconds > 0 
                ? widget.duration.inMilliseconds.toDouble() 
                : 1.0,
            onChanged: (value) {
              final newPosition = Duration(milliseconds: value.toInt());
              widget.onSeek(newPosition);
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatDuration(widget.position),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            Text(
              _formatDuration(widget.duration),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ],
    ),
  );
}

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
Widget build(BuildContext context) {
  final currentTrack = widget.currentTrack;
  
  return MorphTransition(
    isOpen: true,
    child: Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Dynamic background effects
          _buildDynamicBackground(),
          _buildParticleEffects(),
          _buildLightLeaks(),
          
          // Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Album cover with enhanced effects
                _buildEnhancedAlbumCover(),
                
                const SizedBox(height: 30),
                
                // Track info
                Text(
                  currentTrack?.displayTitle ?? 'No track selected',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 8),
                
                Text(
                  currentTrack != null 
                    ? '${currentTrack.displayArtist} • ${currentTrack.displayAlbum}'
                    : '',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 30),
                
                // Progress bar
                _buildProgressBar(),
                
                const SizedBox(height: 30),
                
                // Play/pause button
                IconButton(
                  icon: Icon(
                    widget.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                    size: 60,
                    color: Colors.white,
                  ),
                  onPressed: widget.onPlayPause,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
    }

class _ParticlePainter extends CustomPainter {
  final double animationValue;
  final List<Color> colors;

  _ParticlePainter({required this.animationValue, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final particleCount = 20;
    final paint = Paint();
    
    for (int i = 0; i < particleCount; i++) {
      final progress = (animationValue + i / particleCount) % 1.0;
      final x = size.width * (0.2 + 0.6 * (i / particleCount));
      final y = size.height * (0.3 + 0.4 * progress);
      final radius = 2.0 + 3.0 * (1.0 - progress).abs();
      
      paint.color = colors[i % colors.length].withOpacity(0.3 * (1.0 - progress));
      
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) {
    return animationValue != oldDelegate.animationValue || colors != oldDelegate.colors;
  }
}