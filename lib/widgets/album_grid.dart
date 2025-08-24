import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../models/player_state.dart';
import '../services/cache_service.dart';

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
  final int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      widget.onLoadMore?.call();
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

    return NotificationListener<ScrollNotification>(
      onNotification: (scrollNotification) {
        if (scrollNotification is ScrollEndNotification &&
            _scrollController.position.pixels >=
                _scrollController.position.maxScrollExtent - 100) {
          widget.onLoadMore?.call();
        }
        return false;
      },
      child: GridView.builder(
        controller: _scrollController,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.8,
        ),
        itemCount: widget.albums.length + (widget.hasMore ? 1 : 0),
        addAutomaticKeepAlives: true,
        addRepaintBoundaries: true,
        cacheExtent: 500,
        itemBuilder: (context, index) {
          if (index >= widget.albums.length) {
            return _buildLoadingIndicator();
          }
          
          final album = widget.albums[index];
          final isPlayingAlbum = widget.currentlyPlayingTrack != null &&
              album.tracks.any((track) => track.path == widget.currentlyPlayingTrack?.path);
          
          return _AnimatedAlbumCard(
            album: album,
            onPlayTrack: widget.onPlayTrack,
            isPlaying: isPlayingAlbum,
          );
        },
      ),
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

class _AnimatedAlbumCard extends StatefulWidget {
  final Album album;
  final ValueChanged<Track> onPlayTrack;
  final bool isPlaying;

  const _AnimatedAlbumCard({
    required this.album,
    required this.onPlayTrack,
    required this.isPlaying,
  });

  @override
  State<_AnimatedAlbumCard> createState() => _AnimatedAlbumCardState();
}

class _AnimatedAlbumCardState extends State<_AnimatedAlbumCard> 
    with SingleTickerProviderStateMixin {
  
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    
    _elevationAnimation = Tween<double>(begin: 2.0, end: 8.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _animationController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _animationController.reverse();
    _showAlbumTracks(context, widget.album);
  }

  void _onTapCancel() {
    _animationController.reverse();
  }

  void _showAlbumTracks(BuildContext context, Album album) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.9),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
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
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: widget.isPlaying
                  ? Border.all(color: Colors.blue, width: 2)
                  : _isHovering
                      ? Border.all(color: Colors.white.withOpacity(0.3), width: 1)
                      : null,
              boxShadow: _isHovering
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              children: [
                // Album cover with playing indicator
                Stack(
                  children: [
                    _AlbumCoverWithCache(album: widget.album),
                    if (widget.isPlaying)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.music_note, 
                            size: 16, 
                            color: Colors.white
                          ),
                        ),
                      ),
                  ],
                ),
                
                // Album info
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Column(
                    children: [
                      Text(
                        widget.album.name,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: _isHovering ? 15 : 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        widget.album.artist,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: _isHovering ? 13 : 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            album.artist,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: album.tracks.length,
              addAutomaticKeepAlives: true,
              cacheExtent: 300,
              itemBuilder: (context, index) {
                final track = album.tracks[index];
                return ListTile(
                  leading: const Icon(Icons.music_note, color: Colors.white70),
                  title: Text(
                    track.displayTitle,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    track.artist,
                    style: TextStyle(color: Colors.white.withOpacity(0.6)),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.play_arrow, color: Colors.white),
                    onPressed: () => onPlayTrack(track),
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

// Separate widget for album cover with keep-alive functionality
class _AlbumCoverWithCache extends StatefulWidget {
  final Album album;

  const _AlbumCoverWithCache({required this.album});

  @override
  State<_AlbumCoverWithCache> createState() => _AlbumCoverWithCacheState();
}

class _AlbumCoverWithCacheState extends State<_AlbumCoverWithCache> 
    with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return FutureBuilder<Uint8List?>(
      future: widget.album.coverArtPath != null 
          ? AlbumCoverCache.getAlbumCover(widget.album.coverArtPath!)
          : Future.value(null),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return Container(
            width: 120,
            height: 120,
            margin: const EdgeInsets.all(12),
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
            width: 120,
            height: 120,
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.blue.withOpacity(0.3),
            ),
            child: const Icon(Icons.album, size: 48, color: Colors.white70),
          );
        }
      },
    );
  }
}