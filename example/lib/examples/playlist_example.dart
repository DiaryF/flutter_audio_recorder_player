import 'package:flutter/material.dart';
import 'package:flutter_audio_recorder_player/flutter_audio_recorder_player.dart';

/// Enum for repeat modes
enum RepeatMode {
  /// No repeat
  off,

  /// Repeat all tracks
  all,

  /// Repeat current track
  one,
}

class PlaylistExample extends StatefulWidget {
  const PlaylistExample({super.key});

  @override
  State<PlaylistExample> createState() => _PlaylistExampleState();
}

class _PlaylistExampleState extends State<PlaylistExample> {
  final _player = FlutterAudioRecorderPlayer();
  bool _isPlaying = false;
  bool _isPaused = false;
  String _currentTitle = '';
  int _position = 0;
  int _duration = 0;
  int _currentIndex = 0;

  // Additional playback controls
  bool _isShuffleEnabled = false;
  RepeatMode _repeatMode = RepeatMode.off;
  double _volume = 1.0;
  double _speed = 1.0;

  // Original playlist order for shuffle
  late List<AudioSource> _originalPlaylist;

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

    // Initialize the original playlist
    _originalPlaylist = List.from(_playlist);

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

    // Listen for volume updates
    _player.volumeStream.listen((volume) {
      setState(() {
        _volume = volume;
      });
    });

    // Listen for speed updates
    _player.speedStream.listen((speed) {
      setState(() {
        _speed = speed;
      });
    });
  }

  Future<void> _setupPlaylist() async {
    // Create a concatenating audio source from the playlist
    final concatenatingSource = ConcatenatingAudioSource(children: _playlist);

    // Set the audio source
    await _player.setAudioSource(concatenatingSource);
  }

  /// Toggles shuffle mode
  void _toggleShuffle() {
    setState(() {
      _isShuffleEnabled = !_isShuffleEnabled;

      if (_isShuffleEnabled) {
        // Save current index and item
        final currentSource = _playlist[_currentIndex];

        // Shuffle the playlist (except the current item)
        final List<AudioSource> tempList = List.from(_playlist);
        tempList.removeAt(_currentIndex);
        tempList.shuffle();

        // Put the current item back at the current index
        _playlist.clear();
        _playlist.add(currentSource);
        _playlist.addAll(tempList);

        // Reset current index to 0 (current item)
        _currentIndex = 0;
      } else {
        // Restore original order
        final currentSource = _playlist[_currentIndex];
        _playlist.clear();
        _playlist.addAll(_originalPlaylist);

        // Find the index of the current source in the original playlist
        int newIndex = 0;
        for (int i = 0; i < _playlist.length; i++) {
          if (_playlist[i] == currentSource) {
            newIndex = i;
            break;
          }
        }
        _currentIndex = newIndex;
      }
    });
  }

  /// Cycles through repeat modes
  void _cycleRepeatMode() {
    setState(() {
      switch (_repeatMode) {
        case RepeatMode.off:
          _repeatMode = RepeatMode.all;
          break;
        case RepeatMode.all:
          _repeatMode = RepeatMode.one;
          break;
        case RepeatMode.one:
          _repeatMode = RepeatMode.off;
          break;
      }
    });
  }

  /// Handles end of track based on repeat mode
  void _handleTrackEnd() {
    switch (_repeatMode) {
      case RepeatMode.off:
        if (_currentIndex < _playlist.length - 1) {
          _skipToNext();
        }
        break;
      case RepeatMode.all:
        if (_currentIndex < _playlist.length - 1) {
          _skipToNext();
        } else {
          _skipToIndex(0);
        }
        break;
      case RepeatMode.one:
        // Replay the current track
        _skipToIndex(_currentIndex);
        break;
    }
  }

  /// Skip to next track
  Future<void> _skipToNext() async {
    if (_currentIndex < _playlist.length - 1) {
      await _player.skipToNext();
      setState(() {
        _currentIndex++;
      });
    } else if (_repeatMode == RepeatMode.all) {
      await _skipToIndex(0);
    }
  }

  /// Skip to previous track
  Future<void> _skipToPrevious() async {
    if (_currentIndex > 0) {
      await _player.skipToPrevious();
      setState(() {
        _currentIndex--;
      });
    } else if (_repeatMode == RepeatMode.all) {
      await _skipToIndex(_playlist.length - 1);
    }
  }

  /// Skip to specific index
  Future<void> _skipToIndex(int index) async {
    if (index >= 0 && index < _playlist.length) {
      await _player.skipToIndex(index);
      setState(() {
        _currentIndex = index;
      });
    }
  }

  /// Set volume
  Future<void> _setVolume(double volume) async {
    await _player.setVolume(volume);
    setState(() {
      _volume = volume;
    });
  }

  /// Set playback speed
  Future<void> _setSpeed(double speed) async {
    await _player.setSpeed(speed);
    setState(() {
      _speed = speed;
    });
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
                onPressed: () => _skipToPrevious(),
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
                onPressed: () => _skipToNext(),
              ),
            ],
          ),

          // Additional controls (shuffle, repeat, etc.)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Shuffle button
              IconButton(
                icon: Icon(
                  Icons.shuffle,
                  color:
                      _isShuffleEnabled
                          ? Theme.of(context).colorScheme.primary
                          : null,
                ),
                onPressed: _toggleShuffle,
                tooltip: 'Shuffle',
              ),

              // Repeat button
              IconButton(
                icon: Icon(
                  _repeatMode == RepeatMode.one
                      ? Icons.repeat_one
                      : Icons.repeat,
                  color:
                      _repeatMode != RepeatMode.off
                          ? Theme.of(context).colorScheme.primary
                          : null,
                ),
                onPressed: _cycleRepeatMode,
                tooltip:
                    'Repeat mode: ${_repeatMode.toString().split('.').last}',
              ),

              // Speed button - shows a dialog with speed options
              IconButton(
                icon: const Icon(Icons.speed),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder:
                        (context) => AlertDialog(
                          title: const Text('Playback Speed'),
                          content: StatefulBuilder(
                            builder:
                                (context, setDialogState) => Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('${_speed.toStringAsFixed(1)}x'),
                                    Slider(
                                      value: _speed,
                                      min: 0.5,
                                      max: 2.0,
                                      divisions: 15,
                                      onChanged: (value) {
                                        _setSpeed(value);
                                        setDialogState(() {});
                                      },
                                    ),
                                    OverflowBar(
                                      alignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        TextButton(
                                          onPressed: () {
                                            _setSpeed(0.5);
                                            setDialogState(() {});
                                          },
                                          child: Text(
                                            '0.5x',
                                            style: TextStyle(
                                              color:
                                                  _speed < 0.75
                                                      ? Theme.of(
                                                        context,
                                                      ).colorScheme.primary
                                                      : null,
                                              fontWeight:
                                                  _speed < 0.75
                                                      ? FontWeight.bold
                                                      : null,
                                            ),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            _setSpeed(1.0);
                                            setDialogState(() {});
                                          },
                                          child: Text(
                                            '1.0x',
                                            style: TextStyle(
                                              color:
                                                  _speed >= 0.75 &&
                                                          _speed < 1.25
                                                      ? Theme.of(
                                                        context,
                                                      ).colorScheme.primary
                                                      : null,
                                              fontWeight:
                                                  _speed >= 0.75 &&
                                                          _speed < 1.25
                                                      ? FontWeight.bold
                                                      : null,
                                            ),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            _setSpeed(1.5);
                                            setDialogState(() {});
                                          },
                                          child: Text(
                                            '1.5x',
                                            style: TextStyle(
                                              color:
                                                  _speed >= 1.25 &&
                                                          _speed < 1.75
                                                      ? Theme.of(
                                                        context,
                                                      ).colorScheme.primary
                                                      : null,
                                              fontWeight:
                                                  _speed >= 1.25 &&
                                                          _speed < 1.75
                                                      ? FontWeight.bold
                                                      : null,
                                            ),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            _setSpeed(2.0);
                                            setDialogState(() {});
                                          },
                                          child: Text(
                                            '2.0x',
                                            style: TextStyle(
                                              color:
                                                  _speed >= 1.75
                                                      ? Theme.of(
                                                        context,
                                                      ).colorScheme.primary
                                                      : null,
                                              fontWeight:
                                                  _speed >= 1.75
                                                      ? FontWeight.bold
                                                      : null,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                  );
                },
                tooltip: 'Playback speed',
              ),

              // Volume button - shows a dialog with volume control
              IconButton(
                icon: Icon(_volume > 0 ? Icons.volume_up : Icons.volume_off),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder:
                        (context) => AlertDialog(
                          title: const Text('Volume'),
                          content: StatefulBuilder(
                            builder:
                                (context, setDialogState) => Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('${(_volume * 100).round()}%'),
                                    Slider(
                                      value: _volume,
                                      min: 0.0,
                                      max: 1.0,
                                      divisions: 20,
                                      onChanged: (value) {
                                        _setVolume(value);
                                        setDialogState(() {});
                                      },
                                    ),
                                    OverflowBar(
                                      alignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        IconButton(
                                          onPressed: () {
                                            _setVolume(0.0);
                                            setDialogState(() {});
                                          },
                                          icon: Icon(
                                            Icons.volume_off,
                                            color:
                                                _volume < 0.01
                                                    ? Theme.of(
                                                      context,
                                                    ).colorScheme.primary
                                                    : null,
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () {
                                            _setVolume(0.3);
                                            setDialogState(() {});
                                          },
                                          icon: Icon(
                                            Icons.volume_down,
                                            color:
                                                _volume >= 0.01 && _volume < 0.5
                                                    ? Theme.of(
                                                      context,
                                                    ).colorScheme.primary
                                                    : null,
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () {
                                            _setVolume(0.7);
                                            setDialogState(() {});
                                          },
                                          icon: Icon(
                                            Icons.volume_up,
                                            color:
                                                _volume >= 0.5 && _volume < 0.9
                                                    ? Theme.of(
                                                      context,
                                                    ).colorScheme.primary
                                                    : null,
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () {
                                            _setVolume(1.0);
                                            setDialogState(() {});
                                          },
                                          icon: Icon(
                                            Icons.volume_up,
                                            color:
                                                _volume >= 0.9
                                                    ? Theme.of(
                                                      context,
                                                    ).colorScheme.primary
                                                    : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                  );
                },
                tooltip: 'Volume',
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
