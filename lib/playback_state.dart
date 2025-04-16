/// Represents the current processing state of the player
enum ProcessingState {
  /// The player has not loaded an audio source
  idle,

  /// The player is loading an audio source
  loading,

  /// The player is buffering audio
  buffering,

  /// The player is ready to play
  ready,

  /// The player has reached the end of the audio
  completed,

  /// The player encountered an error
  error,
}

/// Represents the current state of audio playback
class PlaybackState {
  /// The current processing state
  final ProcessingState processingState;

  /// Whether the player is playing
  final bool playing;

  /// The title of the current audio
  final String title;

  /// The current position in milliseconds
  final int position;

  /// The duration in milliseconds
  final int duration;

  /// The timestamp when this state was created
  final int timestamp;

  /// The current playback speed
  final double speed;

  /// The current volume
  final double volume;

  /// The artist of the current audio
  final String? artist;

  /// The album of the current audio
  final String? album;

  /// The URL of the current audio
  final String? url;

  /// The URI of the album art
  final String? artUri;

  /// The genre of the current audio
  final String? genre;

  /// The track number of the current audio
  final int? trackNumber;

  /// The total number of tracks in the album
  final int? trackCount;

  /// The year of the current audio
  final int? year;

  /// Creates a new PlaybackState
  PlaybackState({
    required this.processingState,
    required this.playing,
    required this.title,
    required this.position,
    required this.duration,
    required this.timestamp,
    this.speed = 1.0,
    this.volume = 1.0,
    this.artist,
    this.album,
    this.url,
    this.artUri,
    this.genre,
    this.trackNumber,
    this.trackCount,
    this.year,
  });

  /// Creates a PlaybackState from a map
  factory PlaybackState.fromMap(Map<dynamic, dynamic> map) {
    return PlaybackState(
      processingState: _mapToProcessingState(
        map['state'] as String? ?? 'stopped',
      ),
      playing: map['state'] == 'playing',
      title: map['title'] as String? ?? 'Unknown',
      position: map['position'] as int? ?? 0,
      duration: map['duration'] as int? ?? 0,
      timestamp: map['timestamp'] as int? ?? 0,
      speed: map['speed'] as double? ?? 1.0,
      volume: map['volume'] as double? ?? 1.0,
      artist: map['artist'] as String?,
      album: map['album'] as String?,
      url: map['url'] as String?,
      artUri: map['artUri'] as String?,
      genre: map['genre'] as String?,
      trackNumber: map['trackNumber'] as int?,
      trackCount: map['trackCount'] as int?,
      year: map['year'] as int?,
    );
  }

  /// Maps a string state to a ProcessingState
  static ProcessingState _mapToProcessingState(String state) {
    switch (state) {
      case 'idle':
        return ProcessingState.idle;
      case 'loading':
        return ProcessingState.loading;
      case 'buffering':
        return ProcessingState.buffering;
      case 'playing':
      case 'paused':
        return ProcessingState.ready;
      case 'completed':
        return ProcessingState.completed;
      case 'error':
        return ProcessingState.error;
      default:
        return ProcessingState.idle;
    }
  }

  /// Creates a copy of this PlaybackState with the given fields replaced
  PlaybackState copyWith({
    ProcessingState? processingState,
    bool? playing,
    String? title,
    int? position,
    int? duration,
    int? timestamp,
    double? speed,
    double? volume,
    String? artist,
    String? album,
    String? url,
    String? artUri,
    String? genre,
    int? trackNumber,
    int? trackCount,
    int? year,
  }) {
    return PlaybackState(
      processingState: processingState ?? this.processingState,
      playing: playing ?? this.playing,
      title: title ?? this.title,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      timestamp: timestamp ?? this.timestamp,
      speed: speed ?? this.speed,
      volume: volume ?? this.volume,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      url: url ?? this.url,
      artUri: artUri ?? this.artUri,
      genre: genre ?? this.genre,
      trackNumber: trackNumber ?? this.trackNumber,
      trackCount: trackCount ?? this.trackCount,
      year: year ?? this.year,
    );
  }

  @override
  String toString() {
    return 'PlaybackState{processingState: $processingState, playing: $playing, title: $title, position: $position, duration: $duration}';
  }

  /// Converts the processing state to a string state for backward compatibility
  String get state {
    switch (processingState) {
      case ProcessingState.idle:
        return 'idle';
      case ProcessingState.loading:
        return 'loading';
      case ProcessingState.buffering:
        return 'buffering';
      case ProcessingState.ready:
        return playing ? 'playing' : 'paused';
      case ProcessingState.completed:
        return 'completed';
      case ProcessingState.error:
        return 'error';
    }
  }
}
