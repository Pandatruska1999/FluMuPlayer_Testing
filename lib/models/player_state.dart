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
  final int trackIndex;
  final int trackCount;
  final int year;
  final String genre;
  final int bitrate;
  final int sampleRate;

  const Track({
    required this.path,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    this.albumArtPath,
    this.trackIndex = 0,
    this.trackCount = 0,
    this.year = 0,
    this.genre = '',
    this.bitrate = 0,
    this.sampleRate = 0,
  });

  // Helper methods
  String get displayTitle => title.isNotEmpty ? title : path.split('/').last;
  String get displayArtist => artist.isNotEmpty ? artist : 'Unknown Artist';
  String get displayAlbum => album.isNotEmpty ? album : 'Unknown Album';
  
  String get qualityInfo {
    if (bitrate > 0 && sampleRate > 0) {
      return '${bitrate}kbps • ${sampleRate ~/ 1000}kHz';
    }
    return '';
  }

  String get trackInfo {
    if (trackCount > 0) {
      return 'Track $trackIndex of $trackCount';
    } else if (trackIndex > 0) {
      return 'Track $trackIndex';
    }
    return '';
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