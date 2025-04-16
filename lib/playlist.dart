import 'dart:async';
import 'audio_source.dart';

/// Represents a playlist of audio sources
class Playlist {
  /// The list of audio sources in the playlist
  List<AudioSource> _sources;

  /// The current index in the playlist
  int _currentIndex = 0;

  /// Stream controller for the current index
  final StreamController<int> _indexController =
      StreamController<int>.broadcast();

  /// Stream controller for the current source
  final StreamController<AudioSource> _sourceController =
      StreamController<AudioSource>.broadcast();

  /// Creates a new playlist
  Playlist(List<AudioSource> sources)
    : _sources = List<AudioSource>.unmodifiable(sources) {
    if (sources.isNotEmpty) {
      _sourceController.add(sources.first);
    }
  }

  /// Creates an empty playlist
  Playlist.empty() : _sources = <AudioSource>[];

  /// Gets the list of audio sources
  List<AudioSource> get sources => _sources;

  /// Gets the current index
  int get currentIndex => _currentIndex;

  /// Gets the current audio source
  AudioSource? get currentSource =>
      _sources.isNotEmpty &&
              _currentIndex >= 0 &&
              _currentIndex < _sources.length
          ? _sources[_currentIndex]
          : null;

  /// Gets the stream of current index changes
  Stream<int> get currentIndexStream => _indexController.stream;

  /// Gets the stream of current source changes
  Stream<AudioSource> get currentSourceStream => _sourceController.stream;

  /// Moves to the next track in the playlist
  ///
  /// Returns true if successful, false if at the end of the playlist
  bool next() {
    if (_sources.isEmpty || _currentIndex >= _sources.length - 1) {
      return false;
    }

    _currentIndex++;
    _notifyIndexChanged();
    return true;
  }

  /// Moves to the previous track in the playlist
  ///
  /// Returns true if successful, false if at the beginning of the playlist
  bool previous() {
    if (_sources.isEmpty || _currentIndex <= 0) {
      return false;
    }

    _currentIndex--;
    _notifyIndexChanged();
    return true;
  }

  /// Moves to a specific index in the playlist
  ///
  /// Returns true if successful, false if the index is out of bounds
  bool moveToIndex(int index) {
    if (_sources.isEmpty || index < 0 || index >= _sources.length) {
      return false;
    }

    if (_currentIndex == index) {
      return true;
    }

    _currentIndex = index;
    _notifyIndexChanged();
    return true;
  }

  /// Adds a source to the playlist
  ///
  /// Returns the index of the added source
  int add(AudioSource source) {
    final newSources = List<AudioSource>.from(_sources)..add(source);
    _updateSources(newSources);
    return newSources.length - 1;
  }

  /// Adds multiple sources to the playlist
  ///
  /// Returns the index of the first added source
  int addAll(List<AudioSource> sources) {
    if (sources.isEmpty) {
      return -1;
    }

    final startIndex = _sources.length;
    final newSources = List<AudioSource>.from(_sources)..addAll(sources);
    _updateSources(newSources);
    return startIndex;
  }

  /// Inserts a source at the specified index
  ///
  /// Returns true if successful, false if the index is out of bounds
  bool insert(int index, AudioSource source) {
    if (index < 0 || index > _sources.length) {
      return false;
    }

    final newSources = List<AudioSource>.from(_sources);
    newSources.insert(index, source);

    // Adjust current index if necessary
    if (index <= _currentIndex) {
      _currentIndex++;
    }

    _updateSources(newSources);
    return true;
  }

  /// Removes the source at the specified index
  ///
  /// Returns true if successful, false if the index is out of bounds
  bool removeAt(int index) {
    if (_sources.isEmpty || index < 0 || index >= _sources.length) {
      return false;
    }

    final newSources = List<AudioSource>.from(_sources);
    newSources.removeAt(index);

    // Adjust current index if necessary
    if (index < _currentIndex) {
      _currentIndex--;
    } else if (index == _currentIndex) {
      // If we removed the current item, stay at the same index
      // (which now points to the next item) unless we removed the last item
      if (_currentIndex >= newSources.length) {
        _currentIndex = newSources.isEmpty ? -1 : newSources.length - 1;
      }
    }

    _updateSources(newSources);
    return true;
  }

  /// Clears the playlist
  void clear() {
    _updateSources([]);
    _currentIndex = -1;
    _notifyIndexChanged();
  }

  /// Updates the list of sources
  void _updateSources(List<AudioSource> newSources) {
    _sources = List.unmodifiable(newSources);

    // Notify listeners if the current source changed
    if (_currentIndex >= 0 && _currentIndex < _sources.length) {
      _notifySourceChanged();
    }
  }

  /// Notifies listeners that the current index changed
  void _notifyIndexChanged() {
    _indexController.add(_currentIndex);
    _notifySourceChanged();
  }

  /// Notifies listeners that the current source changed
  void _notifySourceChanged() {
    final source = currentSource;
    if (source != null) {
      _sourceController.add(source);
    }
  }

  /// Disposes of resources
  void dispose() {
    _indexController.close();
    _sourceController.close();
  }
}
