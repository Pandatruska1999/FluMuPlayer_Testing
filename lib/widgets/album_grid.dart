import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/player_state.dart';
import '../services/cache_service.dart';
import 'dart:async';
import 'package:image/image.dart' as img;
import 'shimmer_loading.dart';
import 'dart:math';

class AlbumGrid extends StatefulWidget {
  final List<Album> albums;
  final ValueChanged<Track> onPlayTrack;
  final Track? currentlyPlayingTrack;
  final VoidCallback? onLoadMore;
  final bool hasMore;

  const AlbumGrid({
    super.key,
    required this.albums,
    required this.onPlayTrack,
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
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      widget.onLoadMore?.call();
    }
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
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      cacheExtent: 1000,
      itemBuilder: (context, index) {
        if (index >= widget.albums.length) {
          return _buildLoadingIndicator();
        }
        
        final album = widget.albums[index];
        final isPlayingAlbum = widget.currentlyPlayingTrack != null &&
            album.tracks.any((track) => track.path == widget.currentlyPlayingTrack?.path);
        
        return _AlbumCard(
          album: album,
          onPlayTrack: widget.onPlayTrack,
          isPlaying: isPlayingAlbum,
          scrollController: _scrollController, // Fixed: Added required parameter
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


// Add this class to your album_grid.dart file
class MouseFollowingGradient extends StatefulWidget {
  final Widget child;
  final Color baseColor;
  final double maxOpacity;
  final double radius;

  const MouseFollowingGradient({
    super.key,
    required this.child,
    required this.baseColor,
    this.maxOpacity = 0.3,
    this.radius = 100.0,
  });

  @override
  State<MouseFollowingGradient> createState() => _MouseFollowingGradientState();
}

class _MouseFollowingGradientState extends State<MouseFollowingGradient> {
  Offset _mousePosition = Offset.zero;
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (event) => setState(() {
        _isHovering = true;
        _mousePosition = event.localPosition;
      }),
      onHover: (event) => setState(() => _mousePosition = event.localPosition),
      onExit: (event) => setState(() => _isHovering = false),
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

  _MouseGradientPainter({
    required this.center,
    required this.color,
    required this.maxOpacity,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
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
    return center != oldDelegate.center ||
        color != oldDelegate.color ||
        maxOpacity != oldDelegate.maxOpacity ||
        radius != oldDelegate.radius;
  }
}

class _AlbumCard extends StatefulWidget {
  final Album album;
  final ValueChanged<Track> onPlayTrack;
  final bool isPlaying;
  final bool wasRecentlyPlayed;
  final ScrollController scrollController;

  const _AlbumCard({
    required this.album,
    required this.onPlayTrack,
    required this.isPlaying,
    this.wasRecentlyPlayed = false,
    required this.scrollController,
  });

  @override
  State<_AlbumCard> createState() => _AlbumCardState();
}

class _AlbumCardState extends State<_AlbumCard> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _colorFadeController; // Add this
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _elevationAnimation;
  late Animation<double> _colorFadeAnimation; // Add this
  bool _isHovering = false;
  Color? _dominantColor;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    // Add color fade controller
    _colorFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    _opacityAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    _elevationAnimation = Tween<double>(begin: 0, end: 2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    // Color fade animation (0.1 to 0.03 opacity)
    _colorFadeAnimation = Tween<double>(begin: 0.1, end: 0.03).animate(
      CurvedAnimation(parent: _colorFadeController, curve: Curves.easeInOut),
    );

    _extractDominantColor();
  }

  void _extractDominantColor() async {
  try {
    final coverData = await AlbumCoverCache.getAlbumCover(widget.album.coverArtPath);
    if (coverData != null && coverData.isNotEmpty) {
      final dominantColor = await AlbumCoverCache.extractDominantColorIsolate(coverData);
      if (mounted && dominantColor != null) { // Add null check here
        setState(() {
          _dominantColor = dominantColor;
        });
      }
    }
  } catch (e) {
    print('Error extracting dominant color: $e');
    if (mounted) {
      setState(() {
        _dominantColor = Colors.blue.withOpacity(0.3);
      });
    }
  }
}

  @override
  void dispose() {
    _animationController.dispose();
    _colorFadeController.dispose(); // Dispose the new controller
    super.dispose();
  }

  // Update hover methods to control color fade
  void _handleHoverEnter() {
    setState(() => _isHovering = true);
    _colorFadeController.forward(); // Fade to lighter color
  }

  void _handleHoverExit() {
    setState(() => _isHovering = false);
    _colorFadeController.reverse(); // Return to original color
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
        );
      },
    );
  }

  @override
Widget build(BuildContext context) {
  return GestureDetector(
    onTap: () => _showAlbumTracks(context, widget.album),
    child: MouseFollowingGradient(
      baseColor: _dominantColor ?? Colors.blue,
      maxOpacity: 0.2, // Reduced opacity for subtle effect
      radius: 120, // Adjust based on your preference
      child: AnimatedBuilder(
        animation: widget.scrollController,
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

  Widget _buildLoadingResonance() {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: (_dominantColor ?? Colors.white).withOpacity(0.15),
              width: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _AlbumTracksModal extends StatelessWidget {
  final Album album;
  final ValueChanged<Track> onPlayTrack;

  const _AlbumTracksModal({
    required this.album,
    required this.onPlayTrack,
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}