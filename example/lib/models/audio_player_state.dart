/// Enum representing the type of audio source
enum AudioSourceType {
  /// A streaming URL
  stream,

  /// A local file
  file,

  /// A recording
  recording,

  /// No source
  none,
}

/// Represents the current state of the audio player
class AudioPlayerState {
  /// Whether audio is currently playing
  final bool isPlaying;

  /// Whether audio is currently paused
  final bool isPaused;

  /// The URL or path of the current audio source
  final String currentSource;

  /// The title of the current audio
  final String currentTitle;

  /// The artist of the current audio (if available)
  final String? artist;

  /// The album of the current audio (if available)
  final String? album;

  /// The type of audio source
  final AudioSourceType sourceType;

  /// The current volume (0.0 to 1.0)
  final double volume;

  /// The current playback position in milliseconds
  final double playbackPosition;

  /// The duration of the current audio in milliseconds
  final double duration;

  /// The formatted playback position (mm:ss)
  final String positionText;

  /// The formatted duration (mm:ss)
  final String durationText;

  /// Additional metadata for the current audio
  final Map<String, dynamic>? metadata;

  /// Creates a new AudioPlayerState
  const AudioPlayerState({
    this.isPlaying = false,
    this.isPaused = false,
    this.currentSource = '',
    this.currentTitle = '',
    this.artist,
    this.album,
    this.sourceType = AudioSourceType.none,
    this.volume = 1.0,
    this.playbackPosition = 0.0,
    this.duration = 0.0,
    this.positionText = '0:00',
    this.durationText = '0:00',
    this.metadata,
  });

  /// Creates a copy of this state with the given fields replaced
  AudioPlayerState copyWith({
    bool? isPlaying,
    bool? isPaused,
    String? currentSource,
    String? currentTitle,
    String? artist,
    String? album,
    AudioSourceType? sourceType,
    double? volume,
    double? playbackPosition,
    double? duration,
    String? positionText,
    String? durationText,
    Map<String, dynamic>? metadata,
  }) {
    return AudioPlayerState(
      isPlaying: isPlaying ?? this.isPlaying,
      isPaused: isPaused ?? this.isPaused,
      currentSource: currentSource ?? this.currentSource,
      currentTitle: currentTitle ?? this.currentTitle,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      sourceType: sourceType ?? this.sourceType,
      volume: volume ?? this.volume,
      playbackPosition: playbackPosition ?? this.playbackPosition,
      duration: duration ?? this.duration,
      positionText: positionText ?? this.positionText,
      durationText: durationText ?? this.durationText,
      metadata: metadata ?? this.metadata,
    );
  }
}
