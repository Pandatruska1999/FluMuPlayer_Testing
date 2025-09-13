// lib/services/playlist_manager.dart
import '../models/player_state.dart';
import 'package:flutter/foundation.dart';

class PlaylistManager {
  static List<Track> _playlist = [];
  static int _currentIndex = 0;
  
  static final List<VoidCallback> _listeners = [];

  static List<Track> get playlist => List.unmodifiable(_playlist);
  static int get currentIndex => _currentIndex;
  static Track? get currentTrack => 
      _playlist.isNotEmpty ? _playlist[_currentIndex] : null;

  static void addToPlaylist(Track track) {
    _playlist.add(track);
    _notifyListeners();
  }

  static void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  static void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  static void _notifyListeners() {
    // Use a copy to avoid concurrent modification
    final listeners = List<VoidCallback>.from(_listeners);
    for (final listener in listeners) {
      listener();
    }
  }

  static void addAllToPlaylist(List<Track> tracks) {
    _playlist.addAll(tracks);
    _notifyListeners();
  }

  static void removeFromPlaylist(int index) {
    if (index >= 0 && index < _playlist.length) {
      _playlist.removeAt(index);
      if (_currentIndex >= index && _currentIndex > 0) {
        _currentIndex--;
      }
      _notifyListeners();
    }
  }

  static void clearPlaylist() {
    _playlist.clear();
    _currentIndex = 0;
    _notifyListeners();
  }

  static void setCurrentIndex(int index) {
    if (index >= 0 && index < _playlist.length) {
      _currentIndex = index;
      _notifyListeners();
    }
  }

  static void nextTrack() {
    if (_playlist.isEmpty) return;
    _currentIndex = (_currentIndex + 1) % _playlist.length;
    _notifyListeners();
  }

  static void previousTrack() {
    if (_playlist.isEmpty) return;
    _currentIndex = (_currentIndex - 1) % _playlist.length;
    if (_currentIndex < 0) _currentIndex = _playlist.length - 1;
    _notifyListeners();
  }

  static void reorderPlaylist(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _playlist.length || 
        newIndex < 0 || newIndex >= _playlist.length) {
      return;
    }
    
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
    
    _notifyListeners();
  }
}