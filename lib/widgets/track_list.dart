import 'dart:typed_data';
import 'package:flutter/material.dart';
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

    return ListView.builder(
      controller: _scrollController,
      itemCount: widget.tracks.length + (widget.hasMore ? 1 : 0),
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      cacheExtent: 1000,
      itemBuilder: (context, index) {
        if (index >= widget.tracks.length) {
          return _buildLoadingIndicator();
        }
        
        final track = widget.tracks[index];
        final isCurrentlyPlaying = widget.currentlyPlayingTrack?.path == track.path;
        
        return _TrackTile(
          track: track,
          onPlayTrack: widget.onPlayTrack,
          isPlaying: isCurrentlyPlaying,
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

class _TrackTile extends StatelessWidget {
  final Track track;
  final ValueChanged<Track> onPlayTrack;
  final bool isPlaying;

  const _TrackTile({
    required this.track,
    required this.onPlayTrack,
    required this.isPlaying,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onPlayTrack(track),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              _TrackAlbumArt(
                track: track,
                isPlaying: isPlaying,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.displayTitle,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${track.artist} • ${track.album}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  isPlaying ? Icons.pause : Icons.play_arrow,
                  color: isPlaying ? Colors.blue : Colors.white70,
                  size: 20,
                ),
                onPressed: () => onPlayTrack(track),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackAlbumArt extends StatefulWidget {
  final Track track;
  final bool isPlaying;

  const _TrackAlbumArt({
    required this.track,
    required this.isPlaying,
  });

  @override
  State<_TrackAlbumArt> createState() => _TrackAlbumArtState();
}

class _TrackAlbumArtState extends State<_TrackAlbumArt> {
  late Future<Uint8List?> _coverFuture;

  @override
  void initState() {
    super.initState();
    _loadCover();
  }

  void _loadCover() {
    _coverFuture = AlbumCoverCache.getAlbumCover(widget.track.albumArtPath, size: 80);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _coverFuture,
      builder: (context, snapshot) {
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: Colors.blue.withOpacity(0.2),
            border: widget.isPlaying 
                ? Border.all(color: Colors.blue, width: 2)
                : null,
            image: snapshot.hasData && snapshot.data != null
                ? DecorationImage(
                    image: MemoryImage(snapshot.data!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: snapshot.hasData && snapshot.data != null
              ? null
              : Icon(Icons.music_note, 
                  size: 20, 
                  color: widget.isPlaying ? Colors.blue : Colors.white70
                ),
        );
      },
    );
  }
}