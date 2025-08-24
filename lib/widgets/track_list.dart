import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../models/player_state.dart';
import '../services/cache_service.dart';

class TrackList extends StatefulWidget {
  final List<Track> tracks;
  final ValueChanged<Track> onPlayTrack;
  final Track? currentlyPlayingTrack;
  final VoidCallback? onLoadMore;
  final bool hasMore;

  const TrackList({
    super.key,
    required this.tracks,
    required this.onPlayTrack,
    this.currentlyPlayingTrack,
    this.onLoadMore,
    this.hasMore = false,
  });

  @override
  State<TrackList> createState() => _TrackListState();
}

class _TrackListState extends State<TrackList> {
  final ScrollController _scrollController = ScrollController();
  final int _pageSize = 50;

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
        _scrollController.position.maxScrollExtent - 300) {
      widget.onLoadMore?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tracks.isEmpty) {
      return Center(
        child: Text(
          'No tracks found',
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
                _scrollController.position.maxScrollExtent - 200) {
          widget.onLoadMore?.call();
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        itemCount: widget.tracks.length + (widget.hasMore ? 1 : 0),
        addAutomaticKeepAlives: true,
        addRepaintBoundaries: true,
        cacheExtent: 500,
        itemBuilder: (context, index) {
          if (index >= widget.tracks.length) {
            return _buildLoadingIndicator();
          }
          
          final track = widget.tracks[index];
          final isCurrentlyPlaying = widget.currentlyPlayingTrack?.path == track.path;
          
          return _TrackTileWithFeedback(
            track: track,
            onPlayTrack: widget.onPlayTrack,
            isPlaying: isCurrentlyPlaying,
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

class _TrackTileWithFeedback extends StatefulWidget {
  final Track track;
  final ValueChanged<Track> onPlayTrack;
  final bool isPlaying;

  const _TrackTileWithFeedback({
    required this.track,
    required this.onPlayTrack,
    required this.isPlaying,
  });

  @override
  State<_TrackTileWithFeedback> createState() => _TrackTileWithFeedbackState();
}

class _TrackTileWithFeedbackState extends State<_TrackTileWithFeedback> 
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isHovering = false;
  
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
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
    widget.onPlayTrack(widget.track);
  }

  void _onTapCancel() {
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            decoration: BoxDecoration(
              color: _isHovering ? Colors.white.withOpacity(0.05) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: ListTile(
              leading: _AnimatedAlbumArt(
                track: widget.track,
                isPlaying: widget.isPlaying,
              ),
              title: Text(
                widget.track.displayTitle,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: widget.isPlaying ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              subtitle: Text(
                '${widget.track.artist} • ${widget.track.album}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
              trailing: _PlayButtonWithFeedback(
                onPlay: () => widget.onPlayTrack(widget.track),
                isPlaying: widget.isPlaying,
                isHovering: _isHovering,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedAlbumArt extends StatefulWidget {
  final Track track;
  final bool isPlaying;

  const _AnimatedAlbumArt({
    required this.track,
    required this.isPlaying,
  });

  @override
  State<_AnimatedAlbumArt> createState() => _AnimatedAlbumArtState();
}

class _AnimatedAlbumArtState extends State<_AnimatedAlbumArt> 
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  
  late AnimationController _rotationController;
  
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    );
    
    if (widget.isPlaying) {
      _rotationController.repeat();
    }
  }

  @override
  void didUpdateWidget(_AnimatedAlbumArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_rotationController.isAnimating) {
      _rotationController.repeat();
    } else if (!widget.isPlaying && _rotationController.isAnimating) {
      _rotationController.stop();
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return RotationTransition(
      turns: _rotationController,
      child: FutureBuilder<Uint8List?>(
        future: widget.track.albumArtPath != null 
            ? AlbumCoverCache.getAlbumCover(widget.track.albumArtPath!, size: 80)
            : Future.value(null),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            return Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                image: DecorationImage(
                  image: MemoryImage(snapshot.data!),
                  fit: BoxFit.cover,
                ),
                border: widget.isPlaying 
                    ? Border.all(color: Colors.blue, width: 2)
                    : null,
              ),
            );
          } else {
            return Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.3),
                borderRadius: BorderRadius.circular(4),
                border: widget.isPlaying 
                    ? Border.all(color: Colors.blue, width: 2)
                    : null,
              ),
              child: Icon(Icons.music_note, 
                size: 20, 
                color: widget.isPlaying ? Colors.blue : Colors.white70
              ),
            );
          }
        },
      ),
    );
  }
}

class _PlayButtonWithFeedback extends StatefulWidget {
  final VoidCallback onPlay;
  final bool isPlaying;
  final bool isHovering;

  const _PlayButtonWithFeedback({
    required this.onPlay,
    required this.isPlaying,
    required this.isHovering,
  });

  @override
  State<_PlayButtonWithFeedback> createState() => _PlayButtonWithFeedbackState();
}

class _PlayButtonWithFeedbackState extends State<_PlayButtonWithFeedback> 
    with SingleTickerProviderStateMixin {
  
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(_PlayButtonWithFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isHovering && !oldWidget.isHovering) {
      _scaleController.forward();
    } else if (!widget.isHovering && oldWidget.isHovering) {
      _scaleController.reverse();
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: IconButton(
        icon: widget.isPlaying
            ? const Icon(Icons.pause, color: Colors.blue)
            : const Icon(Icons.play_arrow, color: Colors.white),
        onPressed: widget.onPlay,
        style: IconButton.styleFrom(
          backgroundColor: widget.isHovering ? Colors.white.withOpacity(0.1) : Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}