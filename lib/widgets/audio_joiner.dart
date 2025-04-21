import 'package:flutter/material.dart';
import 'package:flutter_audio_recorder_player/flutter_audio_recorder_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// A widget for joining multiple WAV audio files.
class AudioJoiner extends StatefulWidget {
  /// The list of audio recordings to join.
  final List<AudioRecording> recordings;

  /// Callback when joining is complete.
  final Function(String outputPath)? onJoinComplete;

  /// Callback when joining is cancelled.
  final VoidCallback? onCancel;

  const AudioJoiner({
    super.key,
    required this.recordings,
    this.onJoinComplete,
    this.onCancel,
  });

  @override
  State<AudioJoiner> createState() => _AudioJoinerState();
}

class _AudioJoinerState extends State<AudioJoiner> {
  final FlutterAudioRecorderPlayer _player = FlutterAudioRecorderPlayer();
  final List<bool> _selectedRecordings = [];
  bool _isJoining = false;
  int _currentPlayingIndex = -1;
  bool _isPlaying = false;
  int _currentPosition = 0;

  @override
  void initState() {
    super.initState();
    _selectedRecordings.addAll(List.filled(widget.recordings.length, false));
  }

  @override
  void dispose() {
    _player.stopPlayback();
    super.dispose();
  }

  Future<void> _togglePlayback(int index) async {
    // Stop current playback if any
    if (_isPlaying) {
      await _player.stopPlayback();
      setState(() {
        _isPlaying = false;
        _currentPlayingIndex = -1;
      });
      return;
    }

    // Start playback of the selected recording
    final recording = widget.recordings[index];
    await _player.startPlayback(recording.filePath);

    setState(() {
      _isPlaying = true;
      _currentPlayingIndex = index;
      _currentPosition = 0;
    });

    // Start position update timer
    _updatePosition();
  }

  Future<void> _updatePosition() async {
    if (!mounted) return;

    try {
      final position = await _player.getPosition();
      final duration = await _player.getDuration();

      setState(() {
        _currentPosition = position;
      });

      // Stop playback if we reach the end
      if (position >= duration) {
        await _player.stopPlayback();
        setState(() {
          _isPlaying = false;
          _currentPlayingIndex = -1;
        });
      } else if (_isPlaying) {
        // Continue updating position
        Future.delayed(const Duration(milliseconds: 100), _updatePosition);
      }
    } catch (e) {
      debugPrint('Error updating position: $e');
    }
  }

  void _toggleSelection(int index) {
    setState(() {
      _selectedRecordings[index] = !_selectedRecordings[index];
    });
  }

  Future<void> _joinAudio() async {
    // Check if at least two recordings are selected
    final selectedIndices = <int>[];
    for (int i = 0; i < _selectedRecordings.length; i++) {
      if (_selectedRecordings[i]) {
        selectedIndices.add(i);
      }
    }

    if (selectedIndices.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least two recordings to join')),
      );
      return;
    }

    setState(() {
      _isJoining = true;
    });

    try {
      // Stop playback if playing
      if (_isPlaying) {
        await _player.stopPlayback();
        setState(() {
          _isPlaying = false;
          _currentPlayingIndex = -1;
        });
      }

      // Get the file paths of the selected recordings
      final inputPaths = <String>[];
      for (final index in selectedIndices) {
        inputPaths.add(widget.recordings[index].filePath);
      }

      // Generate output file path
      final directory = await getTemporaryDirectory();
      final outputPath = path.join(
        directory.path,
        'joined_${DateTime.now().millisecondsSinceEpoch}.wav',
      );

      // Join the audio files
      final success = await _player.joinWavFiles(inputPaths, outputPath);

      if (success) {
        if (widget.onJoinComplete != null) {
          widget.onJoinComplete!(outputPath);
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to join audio files')),
        );
      }
    } catch (e) {
      debugPrint('Error joining audio files: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error joining audio files: $e')),
        );
      }
    } finally {
      setState(() {
        _isJoining = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Join Audio Files',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: widget.recordings.length,
            itemBuilder: (context, index) {
              final recording = widget.recordings[index];
              final isPlaying = _currentPlayingIndex == index && _isPlaying;

              return Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Column(
                  children: [
                    ListTile(
                      title: Text(recording.title),
                      subtitle: Text(recording.formattedDuration),
                      leading: Checkbox(
                        value: _selectedRecordings[index],
                        onChanged: (_) => _toggleSelection(index),
                      ),
                      trailing: IconButton(
                        icon: Icon(isPlaying ? Icons.stop : Icons.play_arrow),
                        onPressed: () => _togglePlayback(index),
                      ),
                    ),
                    if (isPlaying)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: LinearProgressIndicator(
                          value: _currentPosition / recording.durationMs,
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SizedBox(
                        height: 60,
                        child: WaveformView(
                          filePath: recording.filePath,
                          samplesCount: 100,
                          enableSelection: false,
                          currentPositionMs:
                              isPlaying ? _currentPosition : null,
                          durationMs: recording.durationMs,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: widget.onCancel,
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: _isJoining ? null : _joinAudio,
                child:
                    _isJoining
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Text('Join Selected'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
