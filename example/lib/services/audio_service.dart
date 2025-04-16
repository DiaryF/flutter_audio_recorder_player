import 'package:flutter/foundation.dart';
import 'package:mymedia/mymedia.dart';
import '../models/recording.dart' as app;

/// A singleton service for managing audio playback
class AudioService {
  /// The singleton instance
  static final AudioService _instance = AudioService._internal();

  /// Factory constructor to return the singleton instance
  factory AudioService() {
    return _instance;
  }

  /// Private constructor
  AudioService._internal();

  /// The audio player
  final Mymedia _player = Mymedia();

  /// The currently playing recording
  app.Recording? _currentRecording;

  /// Whether audio is currently playing
  bool _isPlaying = false;

  /// Whether audio is currently paused
  bool _isPaused = false;

  /// Get the audio player
  Mymedia get player => _player;

  /// Get the currently playing recording
  app.Recording? get currentRecording => _currentRecording;

  /// Whether audio is currently playing
  bool get isPlaying => _isPlaying;

  /// Whether audio is currently paused
  bool get isPaused => _isPaused;

  /// Start playback of a recording
  Future<bool> playRecording(app.Recording recording) async {
    try {
      // Check if file exists
      final file = recording.file;
      if (!await file.exists()) {
        debugPrint('Recording file does not exist: ${file.path}');
        return false;
      }

      // Stop any current playback
      await _player.stopPlayback();

      // Start playback
      final success = await _player.startPlayback(file.path);

      if (success) {
        _currentRecording = recording;
        _isPlaying = true;
        _isPaused = false;
        debugPrint('Successfully started playback for: ${file.path}');
        return true;
      } else {
        debugPrint('Failed to start playback for: ${file.path}');
        return false;
      }
    } catch (e) {
      debugPrint('Error playing recording: $e');
      return false;
    }
  }

  /// Pause playback
  Future<bool> pausePlayback() async {
    try {
      await _player.pausePlayback();
      _isPaused = true;
      return true;
    } catch (e) {
      debugPrint('Error pausing playback: $e');
      return false;
    }
  }

  /// Resume playback
  Future<bool> resumePlayback() async {
    try {
      await _player.resumePlayback();
      _isPaused = false;
      return true;
    } catch (e) {
      debugPrint('Error resuming playback: $e');
      return false;
    }
  }

  /// Stop playback
  Future<bool> stopPlayback() async {
    try {
      await _player.stopPlayback();
      _isPlaying = false;
      _isPaused = false;
      _currentRecording = null;
      return true;
    } catch (e) {
      debugPrint('Error stopping playback: $e');
      return false;
    }
  }

  /// Seek to position
  Future<bool> seekTo(int position) async {
    try {
      await _player.seekTo(position);
      return true;
    } catch (e) {
      debugPrint('Error seeking: $e');
      return false;
    }
  }

  /// Get current position
  Future<int> getPosition() async {
    try {
      return await _player.getPosition();
    } catch (e) {
      debugPrint('Error getting position: $e');
      return 0;
    }
  }

  /// Get duration
  Future<int> getDuration() async {
    try {
      return await _player.getDuration();
    } catch (e) {
      debugPrint('Error getting duration: $e');
      return 0;
    }
  }
}
