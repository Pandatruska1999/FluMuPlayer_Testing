// lib/services/playlist_manager.dart
import '../models/player_state.dart';

class PlaylistManager {
  static List<Track> _playlist = [];
  static int _currentIndex = 0;

  static List<Track> get playlist => _playlist;
  static int get currentIndex => _currentIndex;
  static Track? get currentTrack => 
      _playlist.isNotEmpty ? _playlist[_currentIndex] : null;

  static void addToPlaylist(Track track) {
    _playlist.add(track);
  }

  static void addAllToPlaylist(List<Track> tracks) {
    _playlist.addAll(tracks);
  }

  static void removeFromPlaylist(int index) {
    if (index >= 0 && index < _playlist.length) {
      _playlist.removeAt(index);
      if (_currentIndex >= index && _currentIndex > 0) {
        _currentIndex--;
      }
    }
  }

  static void clearPlaylist() {
    _playlist.clear();
    _currentIndex = 0;
  }

  static void setCurrentIndex(int index) {
    if (index >= 0 && index < _playlist.length) {
      _currentIndex = index;
    }
  }

  static void nextTrack() {
    if (_playlist.isEmpty) return;
    _currentIndex = (_currentIndex + 1) % _playlist.length;
  }

  static void previousTrack() {
    if (_playlist.isEmpty) return;
    _currentIndex = (_currentIndex - 1) % _playlist.length;
    if (_currentIndex < 0) _currentIndex = _playlist.length - 1;
  }

  static void reorderPlaylist(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final Track item = _playlist.removeAt(oldIndex);
    _playlist.insert(newIndex, item);
    
    // Update current index if needed
    if (_currentIndex == oldIndex) {
      _currentIndex = newIndex;
    } else if (_currentIndex > oldIndex && _currentIndex <= newIndex) {
      _currentIndex--;
    } else if (_currentIndex < oldIndex && _currentIndex >= newIndex) {
      _currentIndex++;
    }
  }
}