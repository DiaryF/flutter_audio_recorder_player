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

  // Track the format groups (recordings with the same format)
  Map<String, List<int>> _formatGroups = {};

  @override
  void initState() {
    super.initState();
    _selectedRecordings.addAll(List.filled(widget.recordings.length, false));
    _groupRecordingsByFormat();
  }

  /// Groups recordings by their audio format (sample rate, channels, bit depth)
  void _groupRecordingsByFormat() {
    _formatGroups.clear();

    for (int i = 0; i < widget.recordings.length; i++) {
      final recording = widget.recordings[i];
      final formatKey =
          '${recording.sampleRate}_${recording.channels}_${recording.bitDepth}';

      if (!_formatGroups.containsKey(formatKey)) {
        _formatGroups[formatKey] = [];
      }

      _formatGroups[formatKey]!.add(i);
    }
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

  /// Checks if the selected recordings are compatible for joining
  bool _areRecordingsCompatible(List<int> selectedIndices) {
    if (selectedIndices.isEmpty) return false;

    final firstRecording = widget.recordings[selectedIndices.first];
    final sampleRate = firstRecording.sampleRate;
    final channels = firstRecording.channels;
    final bitDepth = firstRecording.bitDepth;

    for (int i = 1; i < selectedIndices.length; i++) {
      final recording = widget.recordings[selectedIndices[i]];
      if (recording.sampleRate != sampleRate ||
          recording.channels != channels ||
          recording.bitDepth != bitDepth) {
        return false;
      }
    }

    return true;
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

    // Check if the selected recordings are compatible
    if (!_areRecordingsCompatible(selectedIndices)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Selected recordings have different audio formats. All files must have the same sample rate, channels, and bit depth to be joined.',
          ),
          duration: Duration(seconds: 5),
        ),
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
          child: Column(
            children: [
              Text(
                'Join Audio Files',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Note: Only files with the same audio format can be joined.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    color: Theme.of(context).colorScheme.primaryContainer,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Selected',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 16,
                    height: 16,
                    color: Theme.of(context).colorScheme.secondaryContainer,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Compatible',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: widget.recordings.length,
            itemBuilder: (context, index) {
              final recording = widget.recordings[index];
              final isPlaying = _currentPlayingIndex == index && _isPlaying;

              // Get the format key for this recording
              final formatKey =
                  '${recording.sampleRate}_${recording.channels}_${recording.bitDepth}';
              final formatGroup = _formatGroups[formatKey] ?? [];

              // Check if any recordings in this format group are selected
              bool hasSelectedInGroup = false;
              for (final idx in formatGroup) {
                if (_selectedRecordings[idx] && idx != index) {
                  hasSelectedInGroup = true;
                  break;
                }
              }

              // Determine card color based on compatibility
              Color? cardColor;
              if (_selectedRecordings[index]) {
                // Selected recordings are highlighted
                cardColor = Theme.of(context).colorScheme.primaryContainer;
              } else if (hasSelectedInGroup) {
                // Compatible with selected recordings
                cardColor = Theme.of(context).colorScheme.secondaryContainer;
              }

              return Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                color: cardColor,
                child: Column(
                  children: [
                    ListTile(
                      title: Text(recording.title),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(recording.formattedDuration),
                          Text(
                            '${recording.sampleRate}Hz, ${recording.channels}ch, ${recording.bitDepth}bit',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                          ),
                        ],
                      ),
                      isThreeLine: true,
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
                          value:
                              recording.durationMs > 0
                                  ? (_currentPosition / recording.durationMs)
                                      .clamp(0.0, 1.0)
                                  : 0.0,
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
