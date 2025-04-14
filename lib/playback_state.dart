/// Represents the current state of audio playback
class PlaybackState {
  /// The current state of playback (playing, paused, stopped, etc.)
  final String state;

  /// The title of the current audio
  final String title;

  /// The current position in milliseconds
  final int position;

  /// The duration in milliseconds
  final int duration;

  /// The timestamp when this state was created
  final int timestamp;

  /// Creates a new PlaybackState
  PlaybackState({
    required this.state,
    required this.title,
    required this.position,
    required this.duration,
    required this.timestamp,
  });

  /// Creates a PlaybackState from a map
  factory PlaybackState.fromMap(Map<dynamic, dynamic> map) {
    return PlaybackState(
      state: map['state'] as String? ?? 'stopped',
      title: map['title'] as String? ?? 'Unknown',
      position: map['position'] as int? ?? 0,
      duration: map['duration'] as int? ?? 0,
      timestamp: map['timestamp'] as int? ?? 0,
    );
  }

  /// Creates a copy of this PlaybackState with the given fields replaced
  PlaybackState copyWith({
    String? state,
    String? title,
    int? position,
    int? duration,
    int? timestamp,
  }) {
    return PlaybackState(
      state: state ?? this.state,
      title: title ?? this.title,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  String toString() {
    return 'PlaybackState{state: $state, title: $title, position: $position, duration: $duration}';
  }
}
