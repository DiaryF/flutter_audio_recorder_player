import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mymedia/mymedia.dart';
import 'package:mymedia/playback_state.dart' as plugin;
import '../models/audio_file.dart';
import '../models/audio_player_state.dart';
import '../models/recording.dart' as app;
import '../utils/format_utils.dart';

/// Controller for managing audio playback
class AudioController extends ChangeNotifier {
  /// The plugin instance
  final Mymedia _mymediaPlugin = Mymedia();

  /// Timer for updating position
  Timer? _positionTimer;

  /// Stream subscription for playback state updates
  StreamSubscription<plugin.PlaybackState>? _playbackStateSubscription;

  /// Current state of the audio player
  AudioPlayerState _state = const AudioPlayerState();

  /// Example streaming URLs
  final List<String> streamUrls = [
    'https://stream.radioparadise.com/rock-128',
    'https://stream.radioparadise.com/mellow-128',
    'https://stream.radioparadise.com/eclectic-128',
  ];

  /// Recently played files
  final List<AudioFile> _recentFiles = [];

  /// Recently played recordings
  final List<app.Recording> _recentRecordings = [];

  /// Get recently played files
  List<AudioFile> get recentFiles => _recentFiles;

  /// Get recently played recordings
  List<app.Recording> get recentRecordings => _recentRecordings;

  /// Get the current state
  AudioPlayerState get state => _state;

  /// Constructor
  AudioController() {
    _startPositionTimer();
    _listenToPlaybackState();
  }

  /// Listen to playback state updates from the plugin
  void _listenToPlaybackState() {
    _playbackStateSubscription?.cancel();
    _playbackStateSubscription = _mymediaPlugin.getPlaybackStateStream().listen(
      (state) {
        debugPrint(
          'Received playback state: ${state.state}, title: ${state.title}',
        );

        // Update the state based on the playback state
        final bool isPlaying = state.state == 'playing';
        final bool isPaused = state.state == 'paused';

        debugPrint('Setting isPlaying=$isPlaying, isPaused=$isPaused');

        _state = _state.copyWith(
          isPlaying: isPlaying,
          isPaused: isPaused,
          currentTitle: state.title,
          playbackPosition: state.position.toDouble(),
          duration: state.duration.toDouble(),
          positionText: FormatUtils.formatDuration(state.position),
          durationText: FormatUtils.formatDuration(state.duration),
        );

        // Force UI update
        notifyListeners();
      },
    );
  }

  /// Start a timer to update the playback position
  void _startPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_state.isPlaying && !_state.isPaused) {
        _updatePlaybackPosition();
      }
    });
  }

  /// Update the playback position
  Future<void> _updatePlaybackPosition() async {
    try {
      // Get the current position and duration
      final position = await _mymediaPlugin.getPosition();
      final duration = await _mymediaPlugin.getDuration();

      // Update the state
      _state = _state.copyWith(
        playbackPosition: position.toDouble(),
        duration: duration.toDouble(),
        positionText: FormatUtils.formatDuration(position),
        durationText: FormatUtils.formatDuration(duration),
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating position: $e');
    }
  }

  /// Toggle play/pause for the current stream
  Future<void> togglePlayPause() async {
    try {
      debugPrint(
        'togglePlayPause: isPlaying=${_state.isPlaying}, isPaused=${_state.isPaused}',
      );

      if (_state.isPlaying || _state.isPaused) {
        if (_state.isPaused) {
          // Resume playback
          debugPrint('Resuming playback');
          await _mymediaPlugin.resumePlayback();

          // Immediately update UI state (will be confirmed by stream update)
          _state = _state.copyWith(isPlaying: true, isPaused: false);
          notifyListeners();
        } else {
          // Pause playback
          debugPrint('Pausing playback');
          await _mymediaPlugin.pausePlayback();

          // Immediately update UI state (will be confirmed by stream update)
          _state = _state.copyWith(isPlaying: true, isPaused: true);
          notifyListeners();
        }
      }
    } on PlatformException catch (e) {
      debugPrint('Error toggling play/pause: ${e.message}');
    }
  }

  /// Toggle playback for a specific stream URL
  Future<void> toggleStreamPlayback(String url) async {
    try {
      if (_state.isPlaying &&
          _state.sourceType == AudioSourceType.stream &&
          _state.currentSource == url) {
        // Toggle pause/resume for current stream
        await togglePlayPause();
      } else {
        // Stop any current playback
        if (_state.isPlaying) {
          await _mymediaPlugin.stopPlayback();
        }

        // Start new playback
        final result = await _mymediaPlugin.startPlayback(url);

        // Update stream title based on URL
        final streamName = url.split('/').last;

        _state = _state.copyWith(
          isPlaying: result,
          isPaused: false,
          currentSource: result ? url : '',
          currentTitle: result ? streamName : '',
          sourceType: AudioSourceType.stream,

          // Reset position and duration
          playbackPosition: 0.0,
          duration: 0.0,
          positionText: '0:00',
          durationText: '0:00',
        );
        notifyListeners();

        // Update position immediately
        if (result) {
          _updatePlaybackPosition();
        }
      }
    } on PlatformException catch (e) {
      debugPrint('Error playing stream: ${e.message}');
    }
  }

  /// Play a local audio file
  Future<void> playAudioFile(AudioFile file) async {
    try {
      // Stop any current playback
      if (_state.isPlaying) {
        await _mymediaPlugin.stopPlayback();
      }

      // Convert file path to file:// URI for local files
      final fileUri = 'file://${file.path}';
      debugPrint('Playing local file with URI: $fileUri');

      // Start playback of the file
      final result = await _mymediaPlugin.startPlayback(fileUri);

      if (result) {
        // Add to recent files if not already there
        if (!_recentFiles.any((f) => f.path == file.path)) {
          _recentFiles.insert(0, file);
          // Keep only the 10 most recent files
          if (_recentFiles.length > 10) {
            _recentFiles.removeLast();
          }
        }
      }

      _state = _state.copyWith(
        isPlaying: result,
        isPaused: false,
        currentSource: result ? file.path : '',
        currentTitle: result ? file.name : '',
        sourceType: AudioSourceType.file,

        // Reset position and duration
        playbackPosition: 0.0,
        duration: 0.0,
        positionText: '0:00',
        durationText: '0:00',
      );
      notifyListeners();

      // Update position immediately
      if (result) {
        _updatePlaybackPosition();
      }
    } on PlatformException catch (e) {
      debugPrint('Error playing file: ${e.message}');
    }
  }

  /// Play a recording
  Future<void> playRecording(app.Recording recording) async {
    try {
      // Stop any current playback
      if (_state.isPlaying) {
        await _mymediaPlugin.stopPlayback();
      }

      // Convert file path to file:// URI for local files
      final fileUri = 'file://${recording.file.path}';
      debugPrint('Playing recording with URI: $fileUri');

      // Start playback of the recording
      final result = await _mymediaPlugin.startPlayback(fileUri);

      if (result) {
        // Add to recent recordings if not already there
        if (!_recentRecordings.any((r) => r.file.path == recording.file.path)) {
          _recentRecordings.insert(0, recording);
          // Keep only the 10 most recent recordings
          if (_recentRecordings.length > 10) {
            _recentRecordings.removeLast();
          }
        }
      }

      _state = _state.copyWith(
        isPlaying: result,
        isPaused: false,
        currentSource: result ? recording.file.path : '',
        currentTitle: result ? recording.name : '',
        sourceType: AudioSourceType.recording,

        // Reset position and duration
        playbackPosition: 0.0,
        duration: 0.0,
        positionText: '0:00',
        durationText: '0:00',
      );
      notifyListeners();

      // Update position immediately
      if (result) {
        _updatePlaybackPosition();
      }
    } on PlatformException catch (e) {
      debugPrint('Error playing recording: ${e.message}');
    }
  }

  /// Stop playback
  Future<void> stopPlayback() async {
    await _mymediaPlugin.stopPlayback();
    _state = _state.copyWith(
      isPlaying: false,
      isPaused: false,
      currentSource: '',
      currentTitle: '',
      sourceType: AudioSourceType.none,
      playbackPosition: 0.0,
      duration: 0.0,
      positionText: '0:00',
      durationText: '0:00',
    );
    notifyListeners();
  }

  /// Set the volume
  Future<void> setVolume(double volume) async {
    await _mymediaPlugin.setVolume(volume);
    _state = _state.copyWith(volume: volume);
    notifyListeners();
  }

  /// Seek to a specific position
  Future<void> seekTo(int position) async {
    await _mymediaPlugin.seekTo(position);
    // Position will be updated by the timer
  }

  /// Seek relative to the current position
  Future<void> seekRelative(int offsetMs) async {
    try {
      // Get current position
      final currentPosition = await _mymediaPlugin.getPosition();

      // Calculate new position (ensure it's not negative)
      final newPosition = math.max(0, currentPosition + offsetMs);

      // Seek to the new position
      await seekTo(newPosition);
    } catch (e) {
      debugPrint('Error seeking relative: $e');
    }
  }

  @override
  void dispose() {
    _positionTimer?.cancel();
    _playbackStateSubscription?.cancel();
    _mymediaPlugin.stopPlayback();
    super.dispose();
  }
}
