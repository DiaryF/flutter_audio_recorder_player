import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';

// For StreamSubscription
export 'dart:async' show StreamSubscription;

// Export public classes
export 'audio_player.dart';
export 'audio_source.dart';
export 'playback_state.dart';
export 'player_exception.dart';
export 'playlist.dart';
export 'audio_session.dart';
export 'audio_focus.dart';
export 'visualization_data.dart';
export 'pcm_data.dart';
export 'recording.dart';

import 'mymedia_platform_interface_fix.dart';
import 'visualization_data.dart';
import 'pcm_data.dart';
import 'recording.dart';
import 'playback_state.dart';
import 'audio_source.dart';
import 'audio_session_manager.dart';
import 'player_exception.dart';
import 'audio_focus.dart';
import 'playlist.dart';
import 'notification_service.dart';

/// A Flutter plugin for audio streaming and visualization.
class Mymedia {
  // Stream controllers
  final BehaviorSubject<PlaybackState> _playbackStateSubject =
      BehaviorSubject<PlaybackState>();
  final BehaviorSubject<VisualizationData> _visualizationDataSubject =
      BehaviorSubject<VisualizationData>();
  final BehaviorSubject<PcmData> _pcmDataSubject = BehaviorSubject<PcmData>();
  final BehaviorSubject<ProcessingState> _processingStateSubject =
      BehaviorSubject<ProcessingState>.seeded(ProcessingState.idle);
  final BehaviorSubject<bool> _playingSubject = BehaviorSubject<bool>.seeded(
    false,
  );
  final BehaviorSubject<int> _positionSubject = BehaviorSubject<int>.seeded(0);
  final BehaviorSubject<int> _durationSubject = BehaviorSubject<int>.seeded(0);
  final BehaviorSubject<double> _volumeSubject = BehaviorSubject<double>.seeded(
    1.0,
  );
  final BehaviorSubject<double> _speedSubject = BehaviorSubject<double>.seeded(
    1.0,
  );
  final BehaviorSubject<PlayerException?> _playerExceptionSubject =
      BehaviorSubject<PlayerException?>.seeded(null);

  // Current audio source
  AudioSource? _audioSource;

  // Current playlist
  Playlist? _playlist;

  // Audio session manager
  final AudioSessionManager _sessionManager = AudioSessionManager();

  // Audio focus manager
  late final AudioFocusManager _focusManager;

  // Notification service
  final NotificationService _notificationService = NotificationService();

  // Timer for position updates
  Timer? _positionTimer;

  /// Static flag to track if we've initialized the session manager
  static bool _sessionInitialized = false;

  // Stream subscriptions
  StreamSubscription? _playbackStateSubscription;
  StreamSubscription? _visualizationDataSubscription;
  StreamSubscription? _pcmDataSubscription;
  StreamSubscription? _interruptionSubscription;
  StreamSubscription? _becomingNoisySubscription;

  /// Creates a new Mymedia instance
  /// This class is kept for backward compatibility
  /// Consider using FlutterAudioRecorderPlayer instead
  Mymedia() {
    // Initialize the audio focus manager
    _focusManager = AudioFocusManager(_sessionManager);
    _focusManager.onAudioFocusChange = _handleAudioFocusChange;

    // Initialize the notification service
    _initializeNotificationService();

    // Set up notification action handling
    _notificationService.onActionReceived = _handleNotificationAction;
    _initializeAudioSession();

    // Listen for playback state updates from the platform
    _playbackStateSubscription = MymediaPlatform.instance
        .getPlaybackStateStream()
        .listen((state) {
          // Check if disposed before updating subjects
          if (!_disposed) {
            // Update our subjects
            _playbackStateSubject.add(state);
            _playingSubject.add(state.playing);
            _positionSubject.add(state.position);
            _durationSubject.add(state.duration);
            _processingStateSubject.add(state.processingState);

            // Update notification
            _updateNotification(state);
          }
        });

    // Listen for visualization data updates from the platform
    _visualizationDataSubscription = MymediaPlatform.instance
        .getVisualizationDataStream()
        .listen((data) {
          if (!_disposed) {
            _visualizationDataSubject.add(data);
          }
        });

    // Listen for PCM data updates from the platform
    _pcmDataSubscription = MymediaPlatform.instance.getPcmDataStream().listen((
      data,
    ) {
      if (!_disposed) {
        _pcmDataSubject.add(data);
      }
    });

    // Start a timer to update the position
    _startPositionTimer();
  }

  /// Initialize the audio session
  Future<void> _initializeAudioSession() async {
    // Only initialize once across all instances
    if (!_sessionInitialized) {
      await _sessionManager.initialize();
      await _sessionManager.configure(AudioSessionConfiguration.music());

      // Listen for interruptions
      _interruptionSubscription = _sessionManager.interruptionEventStream
          .listen(_handleInterruption);

      // Listen for becoming noisy events
      _becomingNoisySubscription = _sessionManager.becomingNoisyEventStream
          .listen(_handleBecomingNoisy);

      _sessionInitialized = true;
    }
  }

  /// Flag to track if the player has been disposed
  bool _disposed = false;

  /// Initializes the notification service
  Future<void> _initializeNotificationService() async {
    await _notificationService.initialize(
      channelId: 'com.it7.flutter_audio_recorder_player.channel.audio',
      channelName: 'Audio Playback',
      channelDescription: 'Controls for audio playback',
    );
  }

  /// Handles notification actions
  void _handleNotificationAction(String action) {
    if (_disposed) return;

    debugPrint('Notification action received: $action');

    switch (action) {
      case 'play':
        resumePlayback();
        break;
      case 'pause':
        pausePlayback();
        break;
      case 'stop':
        stopPlayback();
        break;
      case 'next':
        skipToNext();
        break;
      case 'previous':
        skipToPrevious();
        break;
    }
  }

  /// Updates the notification with the current playback state
  Future<void> _updateNotification(PlaybackState state) async {
    if (_disposed) return;

    await _notificationService.updatePlaybackState(state);
  }

  /// Disposes of resources
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    // Cancel all stream subscriptions
    _playbackStateSubscription?.cancel();
    _visualizationDataSubscription?.cancel();
    _pcmDataSubscription?.cancel();
    _interruptionSubscription?.cancel();
    _becomingNoisySubscription?.cancel();

    // Dispose of the playlist
    _playlist?.dispose();

    // Hide notification
    _notificationService.hideNotification();

    // Dispose notification service
    _notificationService.dispose();

    // Stop playback and timer
    stopPlayback().then((_) {
      _stopPositionTimer();

      // Close all stream controllers
      _playbackStateSubject.close();
      _visualizationDataSubject.close();
      _pcmDataSubject.close();
      _processingStateSubject.close();
      _playingSubject.close();
      _positionSubject.close();
      _durationSubject.close();
      _volumeSubject.close();
      _speedSubject.close();
      _playerExceptionSubject.close();
    });
  }

  /// Handles audio focus changes
  void _handleAudioFocusChange(AudioFocusState state) {
    if (_disposed) return;

    debugPrint('Audio focus changed: $state');

    switch (state) {
      case AudioFocusState.gain:
        // Restore volume if it was ducked
        setVolume(1.0);
        // Resume playback if it was playing before
        if (_playingSubject.value) {
          resumePlayback();
        }
        break;
      case AudioFocusState.gainTransient:
      case AudioFocusState.gainTransientMayDuck:
        // These states are handled by the platform
        break;
      case AudioFocusState.loss:
        // Stop playback
        pausePlayback();
        break;
      case AudioFocusState.lossTransient:
        // Pause playback temporarily
        pausePlayback();
        break;
      case AudioFocusState.lossTransientDuck:
        // Lower the volume
        setVolume(0.5);
        break;
      case AudioFocusState.none:
        // No audio focus, do nothing
        break;
    }
  }

  /// Handles an interruption event
  void _handleInterruption(InterruptionEvent event) {
    // This is now handled by the AudioFocusManager
    // The AudioFocusManager will call _handleAudioFocusChange
  }

  /// Handles a becoming noisy event (e.g. headphones unplugged)
  void _handleBecomingNoisy(_) {
    if (_disposed) return;

    // Pause playback
    pausePlayback();
  }

  /// Starts the position timer
  void _startPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (_disposed) return;
      if (_playingSubject.value) {
        getPosition().then((position) {
          if (!_disposed) {
            _positionSubject.add(position);
          }
        });
      }
    });
  }

  /// Stops the position timer
  void _stopPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = null;
  }

  /// Returns the current platform version.
  Future<String?> getPlatformVersion() {
    return MymediaPlatform.instance.getPlatformVersion();
  }

  /// Sets the audio source to play
  Future<int> setAudioSource(AudioSource source) async {
    // If we're setting a concatenating source, create a playlist
    if (source is ConcatenatingAudioSource) {
      _playlist?.dispose();
      _playlist = Playlist(source.children);
    } else {
      // For single sources, create a playlist with just one item
      _playlist?.dispose();
      _playlist = Playlist([source]);
    }
    try {
      _audioSource = source;

      // Update processing state
      if (!_disposed) {
        _processingStateSubject.add(ProcessingState.loading);
        // Clear any previous errors
        _playerExceptionSubject.add(null);
      }

      // If it's a URI audio source, start playback
      if (source is UriAudioSource) {
        final success = await startPlayback(source.uri.toString());
        if (!success) {
          final exception = SourceException(
            'load_failed',
            'Failed to load audio source',
            source.uri.toString(),
          );
          _handleError(exception);
          return 0;
        }

        // Get the duration
        final duration = await getDuration();
        if (!_disposed) {
          _durationSubject.add(duration);
        }

        return duration;
      } else if (source is ConcatenatingAudioSource &&
          source.children.isNotEmpty) {
        // For concatenating sources, start with the first child
        final firstChild = source.children.first;
        if (firstChild is UriAudioSource) {
          final success = await startPlayback(firstChild.uri.toString());
          if (!success) {
            final exception = SourceException(
              'load_failed',
              'Failed to load audio source',
              firstChild.uri.toString(),
            );
            _handleError(exception);
            return 0;
          }

          // Get the duration
          final duration = await getDuration();
          if (!_disposed) {
            _durationSubject.add(duration);
          }

          return duration;
        }
      }

      final exception = PlayerException(
        'unsupported_source',
        'Unsupported audio source type',
        source,
      );
      _handleError(exception);
      return 0;
    } catch (e) {
      final exception = PlayerException(
        'set_source_error',
        'Error setting audio source',
        e,
      );
      _handleError(exception);
      return 0;
    }
  }

  /// Extracts a title from a URL
  String _extractTitleFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      if (pathSegments.isEmpty) {
        return uri.host;
      }
      final fileName = pathSegments.last;
      final fileNameWithoutExtension = fileName.split('.').first;
      return fileNameWithoutExtension;
    } catch (e) {
      return 'Unknown';
    }
  }

  /// Handles an error by updating the state and reporting the exception
  void _handleError(PlayerException exception) {
    if (_disposed) return;

    // Update the processing state
    _processingStateSubject.add(ProcessingState.error);

    // Report the exception
    _playerExceptionSubject.add(exception);

    // Log the error
    debugPrint('Player error: $exception');
  }

  /// Starts playback of the audio stream from the given URL.
  ///
  /// Returns true if playback started successfully, false otherwise.
  Future<bool> startPlayback(String url) async {
    try {
      // Make sure the audio session is initialized
      await _initializeAudioSession();

      // Request audio focus
      final sessionActive = await _focusManager.requestFocus();
      if (!sessionActive) {
        _handleError(
          PlayerException(
            'session_activation_failed',
            'Failed to activate audio session',
          ),
        );
        return false;
      }

      // Update processing state
      if (!_disposed) {
        _processingStateSubject.add(ProcessingState.loading);
      }

      // Start playback
      final success = await MymediaPlatform.instance.startPlayback(url);

      if (!_disposed) {
        if (success) {
          _playingSubject.add(true);
          _processingStateSubject.add(ProcessingState.ready);

          // Show notification
          final state = PlaybackState(
            processingState: ProcessingState.ready,
            playing: true,
            title: _extractTitleFromUrl(url),
            position: 0,
            duration: 0,
            timestamp: DateTime.now().millisecondsSinceEpoch,
            url: url,
          );
          _updateNotification(state);
        } else {
          final exception = SourceException(
            'playback_failed',
            'Failed to start playback',
            url,
          );
          _handleError(exception);
        }
      }

      return success;
    } catch (e) {
      final exception = PlayerException(
        'playback_error',
        'Error starting playback',
        e,
      );
      _handleError(exception);
      return false;
    }
  }

  /// Stops the current playback.
  Future<void> stopPlayback() async {
    await MymediaPlatform.instance.stopPlayback();
    if (!_disposed) {
      _playingSubject.add(false);
      _processingStateSubject.add(ProcessingState.idle);
      _positionSubject.add(0);

      // Hide notification
      _notificationService.hideNotification();
    }

    // Abandon audio focus
    await _focusManager.abandonFocus();
  }

  /// Returns whether audio is currently playing.
  Future<bool> isPlaying() async {
    final playing = await MymediaPlatform.instance.isPlaying();
    if (!_disposed) {
      _playingSubject.add(playing);
    }
    return playing;
  }

  /// Pauses the current playback.
  Future<void> pausePlayback() async {
    await MymediaPlatform.instance.pausePlayback();
    if (!_disposed) {
      _playingSubject.add(false);

      // Update notification to show paused state
      final currentState = _playbackStateSubject.valueOrNull;
      if (currentState != null) {
        final updatedState = currentState.copyWith(playing: false);
        _updateNotification(updatedState);
      }
    }
  }

  /// Resumes the current playback.
  Future<void> resumePlayback() async {
    // Make sure the audio session is initialized
    await _initializeAudioSession();

    // Request audio focus
    final sessionActive = await _focusManager.requestFocus();
    if (!sessionActive) {
      return;
    }

    await MymediaPlatform.instance.resumePlayback();
    if (!_disposed) {
      _playingSubject.add(true);

      // Update notification to show playing state
      final currentState = _playbackStateSubject.valueOrNull;
      if (currentState != null) {
        final updatedState = currentState.copyWith(playing: true);
        _updateNotification(updatedState);
      }
    }
  }

  /// Gets the current playback position in milliseconds.
  Future<int> getPosition() async {
    final position = await MymediaPlatform.instance.getPosition();
    if (!_disposed) {
      _positionSubject.add(position);
    }
    return position;
  }

  /// Gets the duration of the current audio in milliseconds.
  Future<int> getDuration() async {
    final duration = await MymediaPlatform.instance.getDuration();
    if (!_disposed) {
      _durationSubject.add(duration);
    }
    return duration;
  }

  /// Seeks to the specified position in milliseconds.
  Future<void> seekTo(int position) async {
    try {
      if (!_disposed) {
        _positionSubject.add(position);
      }
      await MymediaPlatform.instance.seekTo(position);
    } catch (e) {
      _handleError(
        PlayerException('seek_error', 'Error seeking to position', {
          'position': position,
          'error': e,
        }),
      );
    }
  }

  /// Sets the volume (0.0 to 1.0).
  Future<void> setVolume(double volume) async {
    try {
      // Clamp volume to valid range
      final clampedVolume = volume.clamp(0.0, 1.0);

      if (!_disposed) {
        _volumeSubject.add(clampedVolume);
      }
      await MymediaPlatform.instance.setVolume(clampedVolume);
    } catch (e) {
      _handleError(
        PlayerException('volume_error', 'Error setting volume', {
          'volume': volume,
          'error': e,
        }),
      );
    }
  }

  /// Sets the playback speed (0.5 to 2.0).
  Future<void> setSpeed(double speed) async {
    try {
      // Clamp speed to valid range
      final clampedSpeed = speed.clamp(0.5, 2.0);

      // Update the subject
      if (!_disposed) {
        _speedSubject.add(clampedSpeed);
      }

      // Call the platform implementation
      await MymediaPlatform.instance.setSpeed(clampedSpeed);
    } catch (e) {
      _handleError(
        PlayerException('speed_error', 'Error setting playback speed', {
          'speed': speed,
          'error': e,
        }),
      );
    }
  }

  /// Saves the current PCM buffer as a WAV file.
  ///
  /// Returns true if successful, false otherwise.
  Future<bool> savePcmAsWav(String filePath) {
    return MymediaPlatform.instance.savePcmAsWav(filePath);
  }

  /// Starts recording the audio that's currently playing.
  ///
  /// Optional parameters:
  /// - [sampleRate]: Sample rate in Hz (default: 44100)
  /// - [channels]: Number of audio channels (default: 2)
  /// - [bitDepth]: Bit depth (default: 16)
  /// - [title]: Optional title for the recording
  ///
  /// Returns true if recording started successfully, false otherwise.
  Future<bool> startRecording({
    int? sampleRate,
    int? channels,
    int? bitDepth,
    String? title,
  }) {
    return MymediaPlatform.instance.startRecording(
      sampleRate: sampleRate,
      channels: channels,
      bitDepth: bitDepth,
      title: title,
    );
  }

  /// Stops recording and saves the recorded audio as a WAV file.
  ///
  /// Returns true if the recording was saved successfully, false otherwise.
  Future<bool> stopRecording(String filePath) {
    return MymediaPlatform.instance.stopRecording(filePath);
  }

  /// Cancels the current recording without saving.
  ///
  /// Returns true if recording was successfully canceled, false if no recording was in progress.
  Future<bool> cancelRecording() {
    return MymediaPlatform.instance.cancelRecording();
  }

  /// Returns a stream of visualization data.
  ///
  /// This stream emits [VisualizationData] objects containing waveform and
  /// frequency data that can be used to create audio visualizations.
  Stream<VisualizationData> getVisualizationDataStream() {
    return _visualizationDataSubject.stream;
  }

  /// Returns a stream of PCM audio data.
  ///
  /// This stream emits [PcmData] objects containing raw PCM audio samples
  /// that can be used for advanced audio processing or visualization.
  Stream<PcmData> getPcmDataStream() {
    return _pcmDataSubject.stream;
  }

  /// Returns a stream of playback state updates.
  ///
  /// This stream emits [PlaybackState] objects containing information about
  /// the current playback state, including state (playing, paused, stopped),
  /// title, position, and duration.
  Stream<PlaybackState> getPlaybackStateStream() {
    return _playbackStateSubject.stream;
  }

  /// Returns a stream of processing state updates.
  Stream<ProcessingState> get processingStateStream =>
      _processingStateSubject.stream;

  /// Returns a stream of playing state updates.
  Stream<bool> get playingStream => _playingSubject.stream;

  /// Returns a stream of position updates.
  Stream<int> get positionStream => _positionSubject.stream;

  /// Returns a stream of duration updates.
  Stream<int> get durationStream => _durationSubject.stream;

  /// Returns a stream of volume updates.
  Stream<double> get volumeStream => _volumeSubject.stream;

  /// Returns a stream of speed updates.
  Stream<double> get speedStream => _speedSubject.stream;

  /// Returns a stream of player exceptions.
  Stream<PlayerException?> get playerExceptionStream =>
      _playerExceptionSubject.stream;

  /// Gets the last player exception.
  PlayerException? get lastPlayerException =>
      _playerExceptionSubject.valueOrNull;

  /// Gets the current playlist.
  Playlist? get playlist => _playlist;

  /// Skips to the next track in the playlist.
  ///
  /// Returns true if successful, false if at the end of the playlist.
  Future<bool> skipToNext() async {
    final playlist = _playlist;
    if (playlist == null) return false;

    if (!playlist.next()) {
      return false;
    }

    final source = playlist.currentSource;
    if (source == null) return false;

    if (source is UriAudioSource) {
      return await startPlayback(source.uri.toString());
    }

    return false;
  }

  /// Skips to the previous track in the playlist.
  ///
  /// Returns true if successful, false if at the beginning of the playlist.
  Future<bool> skipToPrevious() async {
    final playlist = _playlist;
    if (playlist == null) return false;

    if (!playlist.previous()) {
      return false;
    }

    final source = playlist.currentSource;
    if (source == null) return false;

    if (source is UriAudioSource) {
      return await startPlayback(source.uri.toString());
    }

    return false;
  }

  /// Skips to a specific index in the playlist.
  ///
  /// Returns true if successful, false if the index is out of bounds.
  Future<bool> skipToIndex(int index) async {
    final playlist = _playlist;
    if (playlist == null) return false;

    if (!playlist.moveToIndex(index)) {
      return false;
    }

    final source = playlist.currentSource;
    if (source == null) return false;

    if (source is UriAudioSource) {
      return await startPlayback(source.uri.toString());
    }

    return false;
  }

  /// Returns a stream of combined player state updates.
  Stream<PlaybackState> get playerStateStream => Rx.combineLatest7<
    ProcessingState,
    bool,
    int,
    int,
    double,
    double,
    String?,
    PlaybackState
  >(
    _processingStateSubject.stream,
    _playingSubject.stream,
    _positionSubject.stream,
    _durationSubject.stream,
    _volumeSubject.stream,
    _speedSubject.stream,
    Stream.value(
      _audioSource is UriAudioSource
          ? (_audioSource as UriAudioSource).title
          : null,
    ),
    (processingState, playing, position, duration, volume, speed, title) =>
        PlaybackState(
          processingState: processingState,
          playing: playing,
          position: position,
          duration: duration,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          speed: speed,
          volume: volume,
          title: title ?? 'Unknown',
          artist:
              _audioSource is UriAudioSource
                  ? (_audioSource as UriAudioSource).artist
                  : null,
          album:
              _audioSource is UriAudioSource
                  ? (_audioSource as UriAudioSource).album
                  : null,
          url:
              _audioSource is UriAudioSource
                  ? (_audioSource as UriAudioSource).uri.toString()
                  : null,
        ),
  );

  /// Gets all recordings as a list of AudioRecording objects.
  Future<List<AudioRecording>> getRecordings() {
    return MymediaPlatform.instance.getRecordings();
  }

  /// Updates the title of a recording.
  ///
  /// Returns true if successful, false otherwise.
  Future<bool> updateRecordingTitle(String id, String title) {
    return MymediaPlatform.instance.updateRecordingTitle(id, title);
  }

  /// Deletes a recording.
  ///
  /// Returns true if successful, false otherwise.
  Future<bool> deleteRecording(String id) {
    return MymediaPlatform.instance.deleteRecording(id);
  }
}
