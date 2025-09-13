import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/player_state.dart';
import '../services/cache_service.dart';
import 'dart:async';
import 'package:image/image.dart' as img;
import 'shimmer_loading.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../services/playlist_manager.dart';

// Top-level function for isolate color extraction
Color _isolatedColorExtraction(Uint8List imageData) {
  try {
    final image = img.decodeImage(imageData);
    if (image == null) return const Color(0xFF9E9E9E);

    // Sample colors from different regions of the image
    final List<Offset> samplePoints = [
      Offset(image.width * 0.2, image.height * 0.2), // Top-left
      Offset(image.width * 0.8, image.height * 0.2), // Top-right
      Offset(image.width * 0.5, image.height * 0.5), // Center
      Offset(image.width * 0.2, image.height * 0.8), // Bottom-left
      Offset(image.width * 0.8, image.height * 0.8), // Bottom-right
    ];
    
    int totalR = 0, totalG = 0, totalB = 0;
    int sampleCount = 0;
    
    for (final point in samplePoints) {
      final x = point.dx.toInt();
      final y = point.dy.toInt();
      if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
        final pixel = image.getPixel(x, y);
        totalR += pixel.r.toInt();
        totalG += pixel.g.toInt();
        totalB += pixel.b.toInt();
        sampleCount++;
      }
    }
    
    if (sampleCount > 0) {
      return Color.fromRGBO(
        totalR ~/ sampleCount,
        totalG ~/ sampleCount,
        totalB ~/ sampleCount,
        1.0,
      );
    }
    return const Color(0xFF9E9E9E);
  } catch (e) {
    return const Color(0xFF9E9E9E);
  }
}

class AlbumGrid extends StatefulWidget {
  final List<Album> albums;
  final ValueChanged<Track> onPlayTrack;
  final ValueChanged<Track> onAddToPlaylist; // Add this
  final Track? currentlyPlayingTrack;
  final VoidCallback? onLoadMore;
  final bool hasMore;

  const AlbumGrid({
    super.key,
    required this.albums,
    required this.onPlayTrack,
    required this.onAddToPlaylist,
    this.currentlyPlayingTrack,
    this.onLoadMore,
    this.hasMore = false,
  });

  @override
  State<AlbumGrid> createState() => _AlbumGridState();
}

class _AlbumGridState extends State<AlbumGrid> {
  final ScrollController _scrollController = ScrollController();
  Timer? _scrollDebounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    
    // Preload first 20 images only
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadInitialImages();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _scrollDebounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollDebounce?.isActive ?? false) _scrollDebounce!.cancel();
    
    _scrollDebounce = Timer(const Duration(milliseconds: 100), () {
      if (_scrollController.position.pixels >= 
          _scrollController.position.maxScrollExtent - 200) {
        widget.onLoadMore?.call();
      }
    });
  }

  void _preloadInitialImages() {
    final initialPaths = widget.albums
        .take(20)
        .map((album) => album.coverArtPath)
        .where((path) => path != null)
        .cast<String>()
        .toList();
    
    if (initialPaths.isNotEmpty) {
      AlbumCoverCache.preloadImages(initialPaths);
      // Precompute colors for initial albums
      AlbumCoverCache.precomputeColors(initialPaths);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.albums.isEmpty) {
      return Center(
        child: Text(
          'No albums found',
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 16,
          ),
        ),
      );
    }

    return GridView.builder(
      controller: _scrollController,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: widget.albums.length + (widget.hasMore ? 1 : 0),
      addAutomaticKeepAlives: true, // Changed to true for better performance
      addRepaintBoundaries: true,
      cacheExtent: 2000, // Increased cache extent
      physics: const BouncingScrollPhysics(), // Smoother scrolling
      itemBuilder: (context, index) {
        if (index >= widget.albums.length) {
          return _buildLoadingIndicator();
        }
        
        final album = widget.albums[index];
        final isPlayingAlbum = widget.currentlyPlayingTrack != null &&
            album.tracks.any((track) => track.path == widget.currentlyPlayingTrack?.path);
        
        return RepaintBoundary( // Added RepaintBoundary for performance
          child: _AlbumCard(
            album: album,
            onPlayTrack: widget.onPlayTrack,
            onAddToPlaylist: widget.onAddToPlaylist,
            isPlaying: isPlayingAlbum,
            scrollController: _scrollController,
          ),
        );
      },
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.6)),
        ),
      ),
    );
  }
}

class MouseFollowingGradient extends StatefulWidget {
  final Widget child;
  final Color baseColor;
  final double maxOpacity;
  final double radius;
  final double borderRadius;
  final ValueChanged<bool>? onHoverChanged;

  const MouseFollowingGradient({
    super.key,
    required this.child,
    required this.baseColor,
    this.maxOpacity = 0.3,
    this.radius = 100.0,
    this.borderRadius = 12.0,
    this.onHoverChanged,
  });

  @override
  State<MouseFollowingGradient> createState() => _MouseFollowingGradientState();
}

class _MouseFollowingGradientState extends State<MouseFollowingGradient> {
  Offset _mousePosition = Offset.zero;
  bool _isHovering = false;
  Timer? _hoverTimer;

  @override
  void dispose() {
    _hoverTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (event) {
        setState(() {
          _isHovering = true;
          _mousePosition = event.localPosition;
        });
        widget.onHoverChanged?.call(true);
      },
      onHover: (event) => setState(() => _mousePosition = event.localPosition), // Immediate update
      onExit: (event) {
        setState(() => _isHovering = false);
        widget.onHoverChanged?.call(false);
      },
      child: Stack(
        children: [
          widget.child,
          if (_isHovering)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _MouseGradientPainter(
                    center: _mousePosition,
                    color: widget.baseColor,
                    maxOpacity: widget.maxOpacity,
                    radius: widget.radius,
                    borderRadius: widget.borderRadius,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MouseGradientPainter extends CustomPainter {
  final Offset center;
  final Color color;
  final double maxOpacity;
  final double radius;
  final double borderRadius;

  _MouseGradientPainter({
    required this.center,
    required this.color,
    required this.maxOpacity,
    required this.radius,
    required this.borderRadius,
  });

   @override
  void paint(Canvas canvas, Size size) {
    // Only repaint if mouse moved significantly (5px threshold)
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(borderRadius),
      ));
    
    canvas.clipPath(path);
    
    final gradient = RadialGradient(
      center: Alignment(
        (center.dx - size.width / 2) / (size.width / 2),
        (center.dy - size.height / 2) / (size.height / 2),
      ),
      colors: [
        color.withOpacity(maxOpacity),
        color.withOpacity(0.0),
      ],
      stops: const [0.0, 1.0],
      radius: radius / 100,
    );

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()..shader = gradient.createShader(rect);

    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _MouseGradientPainter oldDelegate) {
    // Only repaint if mouse moved more than 5 pixels
    final distanceMoved = (center - oldDelegate.center).distance;
    return distanceMoved > 5.0 || // Reduced repaint frequency
        color != oldDelegate.color ||
        maxOpacity != oldDelegate.maxOpacity ||
        radius != oldDelegate.radius ||
        borderRadius != oldDelegate.borderRadius;
  }
}

class _AlbumCard extends StatefulWidget {
  final Album album;
  final ValueChanged<Track> onPlayTrack;
  final bool isPlaying;
  final ValueChanged<Track> onAddToPlaylist;
  final bool wasRecentlyPlayed;
  final ScrollController scrollController;

  const _AlbumCard({
    required this.album,
    required this.onPlayTrack,
    required this.isPlaying,
    required this.onAddToPlaylist,
    this.wasRecentlyPlayed = false,
    required this.scrollController,
  });

  @override
  State<_AlbumCard> createState() => _AlbumCardState();
}

class _AlbumCardState extends State<_AlbumCard> with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  bool _isHovering = false;
  Color? _dominantColor;
  bool _colorExtractionStarted = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    _opacityAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _loadDominantColor();
  }

  void _loadDominantColor() async {
    if (_colorExtractionStarted) return;
    _colorExtractionStarted = true;
    
    // Check if color is already cached
    final cachedColor = await AlbumCoverCache.getAlbumColor(widget.album.coverArtPath);
    if (cachedColor != null && mounted) {
      setState(() {
        _dominantColor = cachedColor;
      });
      return;
    }
    
    // If not cached, extract it (in isolate for performance)
    _extractDominantColor();
  }

  void _extractDominantColor() async {
    try {
      final coverData = await AlbumCoverCache.getAlbumCover(widget.album.coverArtPath);
      if (coverData != null && coverData.isNotEmpty) {
        // Use compute to run color extraction in isolate
        final dominantColor = await compute(_isolatedColorExtraction, coverData);
        
        if (mounted) {
          setState(() {
            _dominantColor = dominantColor;
          });
          // Cache the color for future use
          if (widget.album.coverArtPath != null) {
          AlbumCoverCache.cacheAlbumColor(widget.album.coverArtPath!, dominantColor);
          }
        }
      }
    } catch (e) {
      print('Error extracting dominant color: $e');
      if (mounted) {
        setState(() {
          _dominantColor = const Color(0xFF9E9E9E);
        });
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  double _calculateLuminance(Color color) {
    return (0.299 * color.red + 0.587 * color.green + 0.114 * color.blue) / 255;
  }

  Color _getHoverColor(Color baseColor) {
    final luminance = _calculateLuminance(baseColor);
    final hsl = HSLColor.fromColor(baseColor);
    
    // Check if color is grayscale (saturation near zero)
    final isGrayscale = hsl.saturation < 0.1;
    
    if (isGrayscale) {
      // For grayscale images, use simple matte gray based on luminance
      if (luminance < 0.4) {
        // Dark grayscale -> light matte gray
        return const Color(0xFF9E9E9E);
      } else {
        // Light grayscale -> slightly darker matte gray  
        return const Color(0xFF757575);
      }
    }
    
    // Original algorithm for colored images
    if (luminance < 0.4) {
      return hsl
          .withLightness(hsl.lightness.clamp(0.6, 0.8))
          .withSaturation(hsl.saturation.clamp(0.7, 1.0))
          .toColor();
    } else if (luminance > 0.7) {
      // For very light colors, slightly darken for better visibility
      final hsl = HSLColor.fromColor(baseColor);
      return hsl.withLightness(hsl.lightness * 0.9).toColor();
    } else {
      // For mid-tone colors, use as-is
      return baseColor;
    }
  }

  void _showAlbumTracks(BuildContext context, Album album) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.95),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return _AlbumTracksModal(
          album: album,
          onPlayTrack: widget.onPlayTrack,
          onAddToPlaylist: (track) {
            // Add track to playlist
            PlaylistManager.addToPlaylist(track);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Added "${track.displayTitle}" to playlist')),
            );
          },
        );
      },
    );
  }

  Color _getBackgroundColor() {
    if (widget.wasRecentlyPlayed && _dominantColor != null) {
      return _dominantColor!.withOpacity(0.1);
    }
    return Colors.white.withOpacity(0.08);
  }

  List<BoxShadow> _getShadows() {
    final shadows = <BoxShadow>[];
    
    // Base shadow
    shadows.add(
      BoxShadow(
        color: Colors.black.withOpacity(0.2),
        blurRadius: 8,
        spreadRadius: 1,
        offset: const Offset(0, 2),
      ),
    );
    
    // Universal border glow on hover
    if (_isHovering) {
      shadows.add(
        BoxShadow(
          color: Colors.white.withOpacity(0.15),
          blurRadius: 10,
          spreadRadius: 1,
        ),
      );
    }
    
    // Ambient breath animation for playing albums
    if (widget.isPlaying) {
      shadows.add(
        BoxShadow(
          color: (_dominantColor ?? Colors.blue).withOpacity(_opacityAnimation.value * 0.3),
          blurRadius: 20,
          spreadRadius: 3,
        ),
      );
    }
    
    return shadows;
  }

  Widget _buildAlbumCover() {
    return FutureBuilder<Uint8List?>(
      future: AlbumCoverCache.getAlbumCover(widget.album.coverArtPath),
      builder: (context, snapshot) {
        return Container(
          width: 120,
          height: 120,
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.blue.withOpacity(0.2),
            image: snapshot.hasData && snapshot.data != null
                ? DecorationImage(
                    image: MemoryImage(snapshot.data!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: snapshot.hasData && snapshot.data != null
              ? null
              : const Icon(Icons.album, size: 42, color: Colors.white70),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    // Use matte gray as fallback during loading/errors
    final hoverColor = _dominantColor != null 
        ? _getHoverColor(_dominantColor!)
        : const Color(0xFF9E9E9E);
    
    return GestureDetector(
      onTap: () => _showAlbumTracks(context, widget.album),
      child: MouseFollowingGradient(
        baseColor: hoverColor,
        maxOpacity: 0.35,
        radius: 120,
        borderRadius: 12,
        onHoverChanged: (isHovering) {
          setState(() {
            _isHovering = isHovering;
          });
        },
        child: AnimatedBuilder(
          animation: Listenable.merge([_animationController, widget.scrollController]),
          builder: (context, child) {
            // Calculate parallax offset based on scroll position
            final scrollOffset = widget.scrollController.hasClients 
                ? widget.scrollController.offset 
                : 0;
            final parallaxFactor = 0.1;
            final parallaxOffset = (scrollOffset * parallaxFactor / 1000).clamp(-0.1, 0.1);
            
            return Transform(
              transform: Matrix4.identity()
                ..translate(0.0, parallaxOffset * 50)
                ..scale(_isHovering ? 1.02 : 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: _getBackgroundColor(),
                  borderRadius: BorderRadius.circular(12),
                  border: widget.isPlaying
                      ? Border.all(
                          color: _dominantColor ?? Colors.blue,
                          width: 2,
                        )
                      : null,
                  boxShadow: _getShadows(),
                ),
                child: Stack(
                  children: [
                    Column(
                      children: [
                        _buildAlbumCover(),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6),
                          child: Column(
                            children: [
                              Text(
                                widget.album.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                widget.album.artist,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${widget.album.tracks.length} tracks',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (widget.isPlaying)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: _dominantColor ?? Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.music_note,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AlbumTracksModal extends StatelessWidget {
  final Album album;
  final ValueChanged<Track> onPlayTrack;
  final ValueChanged<Track> onAddToPlaylist;

  const _AlbumTracksModal({
    required this.album,
    required this.onPlayTrack,
    required this.onAddToPlaylist,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 60,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            album.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            album.artist,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: album.tracks.length,
              itemBuilder: (context, index) {
                final track = album.tracks[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  leading: const Icon(Icons.music_note, color: Colors.white70, size: 20),
                  title: Text(
                    track.displayTitle,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    track.artist,
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.play_arrow, color: Colors.white, size: 20),
                    onPressed: () => onPlayTrack(track),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  onTap: () => onPlayTrack(track),
                  onLongPress: () => onAddToPlaylist(track),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}