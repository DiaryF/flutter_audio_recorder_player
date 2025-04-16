import 'dart:async';
import 'package:rxdart/rxdart.dart';

import 'mymedia.dart';

/// A more user-friendly API for the audio player, inspired by just_audio
class AudioPlayer {
  /// The underlying Mymedia instance
  final Mymedia _player;

  /// Whether this player was created internally
  final bool _createdPlayer;

  /// Creates a new audio player
  ///
  /// If [player] is provided, it will be used instead of creating a new instance.
  AudioPlayer({Mymedia? player})
    : _player = player ?? Mymedia(),
      _createdPlayer = player == null;

  /// The current playlist
  Playlist? get playlist => _player.playlist;

  /// The current processing state
  ProcessingState get processingState => ProcessingState.ready;

  /// Whether the player is playing
  bool get playing => false;

  /// The current playback position in milliseconds
  int get position => 0;

  /// The duration of the current audio in milliseconds
  int get duration => 0;

  /// The current volume (0.0 to 1.0)
  double get volume => 1.0;

  /// The current playback speed (0.5 to 2.0)
  double get speed => 1.0;

  /// The last player exception
  PlayerException? get lastException => _player.lastPlayerException;

  /// Stream of processing state updates
  Stream<ProcessingState> get processingStateStream =>
      _player.processingStateStream;

  /// Stream of playing state updates
  Stream<bool> get playingStream => _player.playingStream;

  /// Stream of position updates
  Stream<int> get positionStream => _player.positionStream;

  /// Stream of duration updates
  Stream<int> get durationStream => _player.durationStream;

  /// Stream of volume updates
  Stream<double> get volumeStream => _player.volumeStream;

  /// Stream of speed updates
  Stream<double> get speedStream => _player.speedStream;

  /// Stream of player exceptions
  Stream<PlayerException?> get playerExceptionStream =>
      _player.playerExceptionStream;

  /// Stream of combined player state updates
  Stream<PlaybackState> get playerStateStream => _player.playerStateStream;

  /// Sets the audio source to play
  ///
  /// Returns the duration of the audio in milliseconds
  Future<Duration> setAudioSource(AudioSource source) async {
    final durationMs = await _player.setAudioSource(source);
    return Duration(milliseconds: durationMs);
  }

  /// Starts playback
  Future<void> play() async {
    if (playing) {
      await _player.resumePlayback();
    }
  }

  /// Pauses playback
  Future<void> pause() => _player.pausePlayback();

  /// Stops playback
  Future<void> stop() => _player.stopPlayback();

  /// Seeks to the specified position
  Future<void> seek(Duration position) =>
      _player.seekTo(position.inMilliseconds);

  /// Sets the volume (0.0 to 1.0)
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  /// Sets the playback speed (0.5 to 2.0)
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  /// Skips to the next item in the playlist
  Future<void> seekToNext() => _player.skipToNext();

  /// Skips to the previous item in the playlist
  Future<void> seekToPrevious() => _player.skipToPrevious();

  /// Skips to a specific index in the playlist
  Future<void> seekToIndex(int index) => _player.skipToIndex(index);

  /// Disposes of resources
  Future<void> dispose() async {
    if (_createdPlayer) {
      _player.dispose();
    }
  }

  /// Creates a convenience stream that combines the most important state information
  Stream<PlayerState> createPlayerStateStream() {
    return Rx.combineLatest2<ProcessingState, bool, PlayerState>(
      processingStateStream,
      playingStream,
      (processingState, playing) => PlayerState(processingState, playing),
    );
  }
}

/// Represents the combined state of the player
class PlayerState {
  /// The current processing state
  final ProcessingState processingState;

  /// Whether the player is playing
  final bool playing;

  /// Creates a new player state
  const PlayerState(this.processingState, this.playing);

  @override
  String toString() =>
      'PlayerState(processingState: $processingState, playing: $playing)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayerState &&
          runtimeType == other.runtimeType &&
          processingState == other.processingState &&
          playing == other.playing;

  @override
  int get hashCode => processingState.hashCode ^ playing.hashCode;
}
