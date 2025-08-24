import 'dart:ui';

// Add this class at the top
class AudioSourcePosition {
  final String trackId;
  double x; // -1.0 (left) to 1.0 (right)
  double y; // -1.0 (back) to 1.0 (front)
  double z; // 0.0 (floor) to 1.0 (ceiling)
  double volume; // 0.0 to 1.0

  AudioSourcePosition({
    required this.trackId,
    this.x = 0.0,
    this.y = 0.0,
    this.z = 0.5,
    this.volume = 1.0,
  });

  AudioSourcePosition copyWith({
    double? x,
    double? y,
    double? z,
    double? volume,
  }) {
    return AudioSourcePosition(
      trackId: trackId,
      x: x ?? this.x,
      y: y ?? this.y,
      z: z ?? this.z,
      volume: volume ?? this.volume,
    );
  }
}

class Track {
  final String path;
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final String? albumArtPath;

  const Track({
    required this.path,
    this.title = '',
    this.artist = '',
    this.album = '',
    this.duration = Duration.zero,
    this.albumArtPath,
  });

  // Helper to get display name from path if metadata is missing
  String get displayTitle {
    if (title.isNotEmpty) return title;
    final fileName = path.split('/').last;
    return fileName.replaceAll('.mp3', '')
                   .replaceAll('.wav', '')
                   .replaceAll('.flac', '');
  }
  
  String get displayArtist {
    if (artist.isNotEmpty) return artist;
    return 'Unknown Artist';
  }
  
  String get displayAlbum {
    if (album.isNotEmpty) return album;
    return 'Unknown Album';
  }
}

class Album {
  final String name;
  final String artist;
  final List<Track> tracks;
  final String? coverArtPath;

  const Album({
    required this.name,
    required this.artist,
    required this.tracks,
    this.coverArtPath,
  });
}

class PlayerState {
  final bool isPlaying;
  final double volume;
  final bool isMuted;
  final Duration position;
  final Duration duration;
  final List<Track> playlist;
  final int currentIndex;
  final bool isDarkMode;
  final Color primaryColor;
  final Color secondaryColor;
  final int selectedTabIndex;
  final List<String> mediaFolders;
  final List<Album> albums;
  final List<Track> allTracks;
  final bool isLoading;
  final Map<String, AudioSourcePosition> spatialPositions; // Add this line

  const PlayerState({
    this.isPlaying = false,
    this.volume = 0.7,
    this.isMuted = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.playlist = const [],
    this.currentIndex = 0,
    this.isDarkMode = true,
    this.primaryColor = const Color(0xFF1E1E1E),
    this.secondaryColor = const Color(0xFF111111),
    this.selectedTabIndex = 0,
    this.mediaFolders = const [],
    this.albums = const [],
    this.allTracks = const [],
    this.isLoading = false,
    this.spatialPositions = const {}, // Add this line
  });

  PlayerState copyWith({
    bool? isPlaying,
    double? volume,
    bool? isMuted,
    Duration? position,
    Duration? duration,
    List<Track>? playlist,
    int? currentIndex,
    bool? isDarkMode,
    Color? primaryColor,
    Color? secondaryColor,
    int? selectedTabIndex,
    List<String>? mediaFolders,
    List<Album>? albums,
    List<Track>? allTracks,
    bool? isLoading,
    Map<String, AudioSourcePosition>? spatialPositions, // Add this line
  }) {
    return PlayerState(
      isPlaying: isPlaying ?? this.isPlaying,
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      playlist: playlist ?? this.playlist,
      currentIndex: currentIndex ?? this.currentIndex,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      selectedTabIndex: selectedTabIndex ?? this.selectedTabIndex,
      mediaFolders: mediaFolders ?? this.mediaFolders,
      albums: albums ?? this.albums,
      allTracks: allTracks ?? this.allTracks,
      isLoading: isLoading ?? this.isLoading,
      spatialPositions: spatialPositions ?? this.spatialPositions, // Add this line
    );
  }
}