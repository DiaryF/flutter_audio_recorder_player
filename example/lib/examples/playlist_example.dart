import 'package:flutter/material.dart';
import 'package:mymedia/mymedia.dart';

class PlaylistExample extends StatefulWidget {
  const PlaylistExample({super.key});

  @override
  State<PlaylistExample> createState() => _PlaylistExampleState();
}

class _PlaylistExampleState extends State<PlaylistExample> {
  final _player = Mymedia();
  bool _isPlaying = false;
  bool _isPaused = false;
  String _currentTitle = '';
  int _position = 0;
  int _duration = 0;
  int _currentIndex = 0;

  // List of audio sources for the playlist
  final List<AudioSource> _playlist = [
    UrlAudioSource(
      url: 'https://stream.radioparadise.com/mellow-128',
      title: 'Radio Paradise Mellow',
      artist: 'Radio Paradise',
    ),
    UrlAudioSource(
      url: 'https://stream.radioparadise.com/rock-128',
      title: 'Radio Paradise Rock',
      artist: 'Radio Paradise',
    ),
    UrlAudioSource(
      url: 'https://stream.radioparadise.com/eclectic-128',
      title: 'Radio Paradise Eclectic',
      artist: 'Radio Paradise',
    ),
    // Using URL sources for better compatibility
    UrlAudioSource(
      url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
      title: 'SoundHelix Song 1',
      artist: 'SoundHelix',
    ),
    UrlAudioSource(
      url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
      title: 'SoundHelix Song 2',
      artist: 'SoundHelix',
    ),
  ];

  @override
  void initState() {
    super.initState();

    // Set up the playlist
    _setupPlaylist();

    // Listen for playback state changes
    _player.playerStateStream.listen((state) {
      setState(() {
        _isPlaying = state.playing;
        _isPaused =
            !state.playing && state.processingState == ProcessingState.ready;
        _currentTitle = state.title;
        _position = state.position;
        _duration = state.duration;
      });
    });

    // Listen for position updates
    _player.positionStream.listen((position) {
      setState(() {
        _position = position;
      });
    });
  }

  Future<void> _setupPlaylist() async {
    // Create a concatenating audio source from the playlist
    final concatenatingSource = ConcatenatingAudioSource(children: _playlist);

    // Set the audio source
    await _player.setAudioSource(concatenatingSource);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Playlist Example')),
      body: Column(
        children: [
          // Current track info
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  _currentTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Track ${_currentIndex + 1} of ${_playlist.length}',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Progress bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                Slider(
                  value:
                      _duration > 0
                          ? _position.clamp(0, _duration).toDouble()
                          : 0.0,
                  min: 0.0,
                  max: _duration > 0 ? _duration.toDouble() : 1.0,
                  onChanged:
                      _duration > 0
                          ? (value) {
                            _player.seekTo(value.toInt());
                          }
                          : null,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDuration(_position)),
                      Text(_formatDuration(_duration)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Playback controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous),
                iconSize: 48,
                onPressed: () {
                  _player.skipToPrevious().then((_) {
                    setState(() {
                      _currentIndex = (_currentIndex - 1).clamp(
                        0,
                        _playlist.length - 1,
                      );
                    });
                  });
                },
              ),
              IconButton(
                icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                iconSize: 64,
                onPressed: () {
                  if (_isPlaying) {
                    _player.pausePlayback();
                  } else {
                    _player.resumePlayback();
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.skip_next),
                iconSize: 48,
                onPressed: () {
                  _player.skipToNext().then((_) {
                    setState(() {
                      _currentIndex = (_currentIndex + 1).clamp(
                        0,
                        _playlist.length - 1,
                      );
                    });
                  });
                },
              ),
            ],
          ),

          // Playlist
          Expanded(
            child: ListView.builder(
              itemCount: _playlist.length,
              itemBuilder: (context, index) {
                final source = _playlist[index];
                String title = 'Unknown';
                String artist = 'Unknown';

                if (source is UriAudioSource) {
                  title = source.title ?? 'Unknown';
                  artist = source.artist ?? 'Unknown';
                }

                return ListTile(
                  title: Text(title),
                  subtitle: Text(artist),
                  leading: CircleAvatar(child: Text('${index + 1}')),
                  selected: index == _currentIndex,
                  onTap: () {
                    _player.skipToIndex(index).then((_) {
                      setState(() {
                        _currentIndex = index;
                      });
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
