import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/player_state.dart';
import '../services/cache_service.dart';
import 'dart:async';


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

class _AlbumCard extends StatelessWidget {
  final Album album;
  final ValueChanged<Track> onPlayTrack;
  final bool isPlaying;

  const _AlbumCard({
    required this.album,
    required this.onPlayTrack,
    required this.isPlaying,
  });

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
          onPlayTrack: onPlayTrack,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showAlbumTracks(context, album),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: isPlaying
                ? Border.all(color: Colors.blue, width: 2)
                : null,
          ),
          child: Column(
            children: [
              _AlbumCover(album: album),
              if (isPlaying)
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
                child: Column(
                  children: [
                    Text(
                      album.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      album.artist,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${album.tracks.length} tracks',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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