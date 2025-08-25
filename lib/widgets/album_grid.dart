import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/player_state.dart';
import '../services/cache_service.dart';
import 'dart:async';
import 'package:image/image.dart' as img;


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

class _AlbumCard extends StatefulWidget {  // Changed to StatefulWidget
  final Album album;
  final ValueChanged<Track> onPlayTrack;
  final bool isPlaying;
  final bool wasRecentlyPlayed;  // Add this property

  const _AlbumCard({
    required this.album,
    required this.onPlayTrack,
    required this.isPlaying,
    this.wasRecentlyPlayed = false,
  });

  @override
  State<_AlbumCard> createState() => _AlbumCardState();
}

class _AlbumCardState extends State<_AlbumCard> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _elevationAnimation;
  bool _isHovering = false;
  Color? _dominantColor;

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
    
    _elevationAnimation = Tween<double>(begin: 0, end: 2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _extractDominantColor();
  }

void _extractDominantColor() async {
  try {
    final coverData = await AlbumCoverCache.getAlbumCover(widget.album.coverArtPath);
    if (coverData != null && coverData.isNotEmpty) {
      final image = img.decodeImage(coverData);
      if (image != null) {
        // Simple dominant color extraction - get average color from center region
        final centerX = image.width ~/ 2;
        final centerY = image.height ~/ 2;
        final sampleSize = 20;
        
        num r = 0, g = 0, b = 0;
        int sampleCount = 0;
        
        for (int x = centerX - sampleSize ~/ 2; x < centerX + sampleSize ~/ 2; x++) {
          for (int y = centerY - sampleSize ~/ 2; y < centerY + sampleSize ~/ 2; y++) {
            if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
              // Get the color at the pixel
              final color = image.getPixel(x, y);
              
              // Extract RGB components using the Color class methods
              r += color.r;
              g += color.g;
              b += color.b;
              sampleCount++;
            }
          }
        }
        
        if (sampleCount > 0) {
          setState(() {
            _dominantColor = Color.fromRGBO(
              r ~/ sampleCount,
              g ~/ sampleCount,
              b ~/ sampleCount,
              1.0,
            );
          });
        }
      }
    }
  } catch (e) {
    print('Error extracting dominant color: $e');
    // Fallback to placeholder color
    setState(() {
      _dominantColor = Colors.blue.withOpacity(0.3);
    });
  }
}

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Transform(
              transform: Matrix4.identity()
                ..scale(_isHovering ? 1.02 : 1.0)
                ..translate(0.0, _isHovering ? -2.0 : 0.0),
              child: Container(
                decoration: BoxDecoration(
                  color: _getBackgroundColor(),
                  borderRadius: BorderRadius.circular(12),
                  border: widget.isPlaying
                      ? Border.all(
                          color: _dominantColor ?? Colors.blue,
                          width: 2,
                        )
                      : _isHovering
                          ? Border.all(
                              color: _dominantColor?.withOpacity(0.5) ?? Colors.white30,
                              width: 0.5,
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
                    if (_isHovering) _buildLoadingResonance(),
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
    
    // Magnetic hover shadow
    if (_isHovering) {
      shadows.add(
        BoxShadow(
          color: Colors.black.withOpacity(0.3),
          blurRadius: 10,
          spreadRadius: 1,
          offset: const Offset(0, 2),
        ),
      );
    }
    
    // Ambient breath animation for playing albums
    if (widget.isPlaying) {
      shadows.add(
        BoxShadow(
          color: (_dominantColor ?? Colors.blue).withOpacity(_opacityAnimation.value * 0.3),
          blurRadius: 15,
          spreadRadius: 2,
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
            boxShadow: [
              if (_isHovering)
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
            ],
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

class _AlbumCover extends StatefulWidget {
  final Album album;

  const _AlbumCover({required this.album});

  @override
  State<_AlbumCover> createState() => _AlbumCoverState();
}

class _AlbumCoverState extends State<_AlbumCover> {
  late Future<Uint8List?> _coverFuture;

  @override
  void initState() {
    super.initState();
    _loadCover();
  }

  void _loadCover() {
    // This should call the cache service which now uses the isolate
    _coverFuture = AlbumCoverCache.getAlbumCover(widget.album.coverArtPath);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _coverFuture,
      builder: (context, snapshot) {
        return Container(
          width: 100,
          height: 100,
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
              : const Icon(Icons.album, size: 36, color: Colors.white70),
        );
      },
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