import 'dart:async';
import 'package:flutter/services.dart';

/// Defines the type of audio content being played
enum AudioContentType {
  /// Music or other media where ducking is appropriate
  music,

  /// Speech or podcast content where pausing is more appropriate than ducking
  speech,

  /// Game audio
  game,

  /// Movie or video audio
  movie,

  /// Sonification sounds
  sonification,

  /// Voice or video call
  voiceCall,
}

/// Defines how the app should handle audio focus
enum AudioFocusStrategy {
  /// Request audio focus and pause when interrupted
  gainAndPauseOthers,

  /// Request audio focus and duck when interrupted
  gainAndDuckOthers,

  /// Don't request audio focus, just play alongside others
  noFocus,
}

/// Defines the type of interruption
enum InterruptionType {
  /// Audio should pause
  pause,

  /// Audio should duck (lower volume)
  duck,

  /// Unknown interruption type
  unknown,
}

/// Event representing an audio interruption
class InterruptionEvent {
  /// Whether the interruption is beginning or ending
  final bool begin;

  /// The type of interruption
  final InterruptionType type;

  /// Creates an interruption event
  InterruptionEvent({required this.begin, required this.type});
}

/// Configuration for the audio session
class AudioSessionConfiguration {
  /// The type of audio content
  final AudioContentType contentType;

  /// The focus strategy
  final AudioFocusStrategy focusStrategy;

  /// Whether to pause when ducked (for speech content)
  final bool pauseWhenDucked;

  /// Creates a configuration for the audio session
  AudioSessionConfiguration({
    this.contentType = AudioContentType.music,
    this.focusStrategy = AudioFocusStrategy.gainAndPauseOthers,
    this.pauseWhenDucked = false,
  });

  /// Creates a configuration suitable for music playback
  factory AudioSessionConfiguration.music() {
    return AudioSessionConfiguration(
      contentType: AudioContentType.music,
      focusStrategy: AudioFocusStrategy.gainAndDuckOthers,
      pauseWhenDucked: false,
    );
  }

  /// Creates a configuration suitable for speech playback
  factory AudioSessionConfiguration.speech() {
    return AudioSessionConfiguration(
      contentType: AudioContentType.speech,
      focusStrategy: AudioFocusStrategy.gainAndPauseOthers,
      pauseWhenDucked: true,
    );
  }

  /// Converts the configuration to a map for platform channel
  Map<String, dynamic> toMap() {
    return {
      'contentType': contentType.index,
      'focusStrategy': focusStrategy.index,
      'pauseWhenDucked': pauseWhenDucked,
    };
  }
}

/// Manages the audio session for the app
class AudioSessionManager {
  static const MethodChannel _channel = MethodChannel(
    'com.it7.flutter_audio_recorder_player/audio_session',
  );
  static const EventChannel _interruptionChannel = EventChannel(
    'com.it7.flutter_audio_recorder_player/audio_interruptions',
  );
  static const EventChannel _becomingNoisyChannel = EventChannel(
    'com.it7.flutter_audio_recorder_player/becoming_noisy',
  );

  /// Singleton instance
  static final AudioSessionManager _instance = AudioSessionManager._internal();

  /// Factory constructor to return the singleton instance
  factory AudioSessionManager() {
    return _instance;
  }

  /// Private constructor
  AudioSessionManager._internal();

  /// The current configuration
  AudioSessionConfiguration? _configuration;

  /// Stream of interruption events
  Stream<InterruptionEvent>? _interruptionEventStream;

  /// Stream of "becoming noisy" events (e.g. headphones unplugged)
  Stream<void>? _becomingNoisyEventStream;

  /// Whether the session is active
  bool _isActive = false;

  /// Whether the manager has been initialized
  bool _initialized = false;

  /// Initialize the audio session manager
  Future<void> initialize() async {
    // Only initialize once
    if (_initialized) return;

    try {
      // Set up the interruption event stream
      _interruptionEventStream = _interruptionChannel
          .receiveBroadcastStream()
          .map<InterruptionEvent>((dynamic event) {
            final Map<dynamic, dynamic> map = event as Map<dynamic, dynamic>;
            return InterruptionEvent(
              begin: map['begin'] as bool,
              type: InterruptionType.values[map['type'] as int],
            );
          });
    } catch (e) {
      // Create a dummy stream if the platform implementation is missing
      _interruptionEventStream = Stream<InterruptionEvent>.empty();
    }

    try {
      // Set up the becoming noisy event stream
      _becomingNoisyEventStream = _becomingNoisyChannel
          .receiveBroadcastStream()
          .map((_) {});
    } catch (e) {
      // Create a dummy stream if the platform implementation is missing
      _becomingNoisyEventStream = Stream<void>.empty();
    }

    // Initialize the platform side
    try {
      await _channel.invokeMethod('initialize');
    } catch (e) {
      // Silently handle the error - the platform side might not be implemented yet
    }

    // Mark as initialized to prevent further attempts
    _initialized = true;
  }

  /// Configure the audio session
  Future<void> configure(AudioSessionConfiguration configuration) async {
    _configuration = configuration;
    try {
      await _channel.invokeMethod('configure', configuration.toMap());
    } catch (e) {
      // Silently handle the error if the platform implementation is missing
      // This allows the app to continue functioning without the audio session features
    }
  }

  /// Activate the audio session
  Future<bool> setActive(bool active) async {
    try {
      final bool success = await _channel.invokeMethod('setActive', {
        'active': active,
      });
      if (success) {
        _isActive = active;
      }
      return success;
    } catch (e) {
      // If the platform implementation is missing, just pretend it succeeded
      _isActive = active;
      return true;
    }
  }

  /// Get whether the session is active
  bool get isActive => _isActive;

  /// Get the current configuration
  AudioSessionConfiguration? get configuration => _configuration;

  /// Stream of interruption events
  Stream<InterruptionEvent> get interruptionEventStream {
    if (_interruptionEventStream == null) {
      // Return an empty stream if not initialized
      return Stream<InterruptionEvent>.empty();
    }
    return _interruptionEventStream!;
  }

  /// Stream of "becoming noisy" events
  Stream<void> get becomingNoisyEventStream {
    if (_becomingNoisyEventStream == null) {
      // Return an empty stream if not initialized
      return Stream<void>.empty();
    }
    return _becomingNoisyEventStream!;
  }

  /// Whether the manager has been initialized
  bool get initialized => _initialized;
}
