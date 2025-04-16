import 'package:flutter/material.dart';
import 'package:mymedia/mymedia.dart';

/// An example of using the advanced features of the Mymedia plugin
class AdvancedPlayerExample extends StatefulWidget {
  const AdvancedPlayerExample({super.key});

  @override
  State<AdvancedPlayerExample> createState() => _AdvancedPlayerExampleState();
}

class _AdvancedPlayerExampleState extends State<AdvancedPlayerExample> {
  // Create a player instance
  final _player = Mymedia();

  // URLs for the playlist
  final _playlist = ConcatenatingAudioSource(
    children: [
      UrlAudioSource(
        url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
        title: 'Song 1',
        artist: 'SoundHelix',
      ),
      UrlAudioSource(
        url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
        title: 'Song 2',
        artist: 'SoundHelix',
      ),
      UrlAudioSource(
        url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
        title: 'Song 3',
        artist: 'SoundHelix',
      ),
    ],
  );

  // Current index in the playlist
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();

    // Initialize the player
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      // Set the audio source (playlist)
      await _player.setAudioSource(_playlist);

      // Listen for playback state changes
      _player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          // Auto-advance to the next track when the current one completes
          _playNext();
        }
      });
    } catch (e) {
      debugPrint('Error initializing player: $e');
    }
  }

  // We need to track the playing state ourselves since we can't access stream.value directly
  bool _isPlaying = false;

  void _playPause() {
    if (_isPlaying) {
      _player.pausePlayback();
    } else {
      _player.resumePlayback();
    }
    // The state will be updated via the stream
  }

  void _playNext() {
    if (_currentIndex < _playlist.children.length - 1) {
      _currentIndex++;
      // In a real implementation, we would use seekToNext() or similar
      // For now, we'll just start playback of the next track
      if (_playlist.children[_currentIndex] is UriAudioSource) {
        final source = _playlist.children[_currentIndex] as UriAudioSource;
        _player.startPlayback(source.uri.toString());
      }
    }
  }

  void _playPrevious() {
    if (_currentIndex > 0) {
      _currentIndex--;
      // In a real implementation, we would use seekToPrevious() or similar
      // For now, we'll just start playback of the previous track
      if (_playlist.children[_currentIndex] is UriAudioSource) {
        final source = _playlist.children[_currentIndex] as UriAudioSource;
        _player.startPlayback(source.uri.toString());
      }
    }
  }

  @override
  void dispose() {
    // Dispose of the player
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Advanced Player Example')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Display the current track title
            StreamBuilder<PlaybackState>(
              stream: _player.playerStateStream,
              builder: (context, snapshot) {
                final state = snapshot.data;
                return Column(
                  children: [
                    Text(
                      state?.title ?? 'No track selected',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (state?.artist != null)
                      Text(
                        state!.artist!,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'State: ${state?.processingState.toString().split('.').last ?? 'unknown'}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),

            // Position and duration
            StreamBuilder<int>(
              stream: _player.positionStream,
              builder: (context, snapshot) {
                final position = snapshot.data ?? 0;
                return StreamBuilder<int>(
                  stream: _player.durationStream,
                  builder: (context, snapshot) {
                    final duration = snapshot.data ?? 0;
                    return Column(
                      children: [
                        Slider(
                          value:
                              duration > 0
                                  ? position.clamp(0, duration).toDouble()
                                  : 0.0,
                          min: 0.0,
                          max:
                              duration > 0
                                  ? duration.toDouble()
                                  : 1.0, // Use 1.0 as a fallback when duration is 0
                          onChanged:
                              duration > 0
                                  ? (value) {
                                    _player.seekTo(value.toInt());
                                  }
                                  : null, // Disable the slider when duration is 0
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_formatDuration(position)),
                              Text(_formatDuration(duration)),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 32),

            // Playback controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous),
                  iconSize: 48,
                  onPressed: _playPrevious,
                ),
                StreamBuilder<bool>(
                  stream: _player.playingStream,
                  builder: (context, snapshot) {
                    final playing = snapshot.data ?? false;
                    // Update our local tracking variable
                    _isPlaying = playing;
                    return IconButton(
                      icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                      iconSize: 64,
                      onPressed: _playPause,
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  iconSize: 48,
                  onPressed: _playNext,
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Volume control
            StreamBuilder<double>(
              stream: _player.volumeStream,
              builder: (context, snapshot) {
                final volume = snapshot.data ?? 1.0;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.volume_down),
                    Slider(
                      value: volume.clamp(0.0, 1.0),
                      min: 0.0,
                      max: 1.0,
                      onChanged: (value) {
                        _player.setVolume(value);
                      },
                    ),
                    const Icon(Icons.volume_up),
                  ],
                );
              },
            ),

            // Speed control
            StreamBuilder<double>(
              stream: _player.speedStream,
              builder: (context, snapshot) {
                final speed = snapshot.data ?? 1.0;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Speed:'),
                    Slider(
                      value: speed.clamp(0.5, 2.0),
                      min: 0.5,
                      max: 2.0,
                      divisions: 6,
                      label: '${speed.toStringAsFixed(1)}x',
                      onChanged: (value) {
                        _player.setSpeed(value);
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
