import 'dart:async';

import 'audio_session_manager.dart';
import 'audio_focus.dart';

/// Configuration for an audio session
class AudioSessionConfiguration {
  /// The audio usage type
  final AudioUsage usage;

  /// The audio content type
  final AudioContentType contentType;

  /// Whether the session can duck (lower volume) when interrupted
  final bool canDuck;

  /// Whether the session can be paused when interrupted
  final bool canPause;

  /// Whether the session should handle becoming noisy events
  final bool handleBecomingNoisy;

  /// Creates a new audio session configuration
  const AudioSessionConfiguration({
    this.usage = AudioUsage.media,
    this.contentType = AudioContentType.music,
    this.canDuck = true,
    this.canPause = true,
    this.handleBecomingNoisy = true,
  });

  /// Creates a configuration for music playback
  factory AudioSessionConfiguration.music() => const AudioSessionConfiguration(
    usage: AudioUsage.media,
    contentType: AudioContentType.music,
    canDuck: true,
    canPause: true,
    handleBecomingNoisy: true,
  );

  /// Creates a configuration for speech playback
  factory AudioSessionConfiguration.speech() => const AudioSessionConfiguration(
    usage: AudioUsage.media,
    contentType: AudioContentType.speech,
    canDuck: false,
    canPause: true,
    handleBecomingNoisy: true,
  );

  /// Creates a configuration for alarm sounds
  factory AudioSessionConfiguration.alarm() => const AudioSessionConfiguration(
    usage: AudioUsage.alarm,
    contentType: AudioContentType.sonification,
    canDuck: false,
    canPause: false,
    handleBecomingNoisy: false,
  );

  /// Creates a configuration for notification sounds
  factory AudioSessionConfiguration.notification() =>
      const AudioSessionConfiguration(
        usage: AudioUsage.notification,
        contentType: AudioContentType.sonification,
        canDuck: true,
        canPause: false,
        handleBecomingNoisy: false,
      );

  /// Creates a configuration for voice calls
  factory AudioSessionConfiguration.call() => const AudioSessionConfiguration(
    usage: AudioUsage.voiceCommunication,
    contentType: AudioContentType.speech,
    canDuck: false,
    canPause: true,
    handleBecomingNoisy: true,
  );

  /// Converts this configuration to a map
  Map<String, dynamic> toMap() {
    return {
      'usage': usage.index,
      'contentType': contentType.index,
      'canDuck': canDuck,
      'canPause': canPause,
      'handleBecomingNoisy': handleBecomingNoisy,
    };
  }
}

/// Represents an audio session
class AudioSession {
  /// The audio session manager
  final AudioSessionManager _manager;

  /// The audio focus manager
  final AudioFocusManager _focusManager;

  /// The current configuration
  AudioSessionConfiguration? _configuration;

  /// Creates a new audio session
  AudioSession._(this._manager, this._focusManager);

  /// The singleton instance
  static AudioSession? _instance;

  /// Gets the singleton instance
  static Future<AudioSession> instance() async {
    if (_instance == null) {
      final manager = AudioSessionManager();
      await manager.initialize();
      final focusManager = AudioFocusManager(manager);
      _instance = AudioSession._(manager, focusManager);
    }
    return _instance!;
  }

  /// Gets the current configuration
  AudioSessionConfiguration? get configuration => _configuration;

  /// Configures the audio session
  Future<bool> configure(AudioSessionConfiguration configuration) async {
    _configuration = configuration;
    return true;
  }

  /// Sets the audio session active or inactive
  Future<bool> setActive(bool active) async {
    if (active) {
      return await _focusManager.requestFocus();
    } else {
      return await _focusManager.abandonFocus();
    }
  }

  /// Stream of interruption events
  Stream<InterruptionEvent> get interruptionEventStream =>
      _manager.interruptionEventStream;

  /// Stream of "becoming noisy" events
  Stream<void> get becomingNoisyEventStream =>
      _manager.becomingNoisyEventStream;
}

/// Audio usage types
enum AudioUsage {
  /// Media playback
  media,

  /// Voice communication
  voiceCommunication,

  /// Voice communication signaling
  voiceCommunicationSignaling,

  /// Alarm
  alarm,

  /// Notification
  notification,

  /// Ringtone
  ringtone,

  /// System sounds
  system,

  /// Game audio
  game,

  /// Assistant
  assistant,
}

/// Audio content types
enum AudioContentType {
  /// Unknown content type
  unknown,

  /// Speech
  speech,

  /// Music
  music,

  /// Movie audio
  movie,

  /// Sound effects
  sonification,
}
