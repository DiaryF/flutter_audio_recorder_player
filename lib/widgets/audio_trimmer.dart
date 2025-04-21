import 'package:flutter/material.dart';
import 'package:flutter_audio_recorder_player/flutter_audio_recorder_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// A widget for trimming WAV audio files.
class AudioTrimmer extends StatefulWidget {
  /// The path to the WAV file to trim.
  final String filePath;

  /// Callback when trimming is complete.
  final Function(String outputPath)? onTrimComplete;

  /// Callback when trimming is cancelled.
  final VoidCallback? onCancel;

  const AudioTrimmer({
    super.key,
    required this.filePath,
    this.onTrimComplete,
    this.onCancel,
  });

  @override
  State<AudioTrimmer> createState() => _AudioTrimmerState();
}

class _AudioTrimmerState extends State<AudioTrimmer> {
  final FlutterAudioRecorderPlayer _player = FlutterAudioRecorderPlayer();
  bool _isPlaying = false;
  int _currentPosition = 0;
  int _duration = 0;
  int _startMs = 0;
  int _endMs = 0;
  bool _isTrimming = false;

  @override
  void initState() {
    super.initState();
    _loadAudio();
  }

  @override
  void dispose() {
    _player.stopPlayback();
    super.dispose();
  }

  Future<void> _loadAudio() async {
    try {
      // Get the WAV header information
      final header = await _player.parseWavHeader(widget.filePath);
      setState(() {
        _duration = header.durationMs;
        _endMs = header.durationMs;
      });
    } catch (e) {
      debugPrint('Error loading audio: $e');
    }
  }

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await _player.pausePlayback();
      setState(() {
        _isPlaying = false;
      });
    } else {
      // If we're at the end, start from the beginning of the selection
      if (_currentPosition >= _endMs) {
        await _player.seekTo(_startMs);
      }

      // Start playback from the current position
      if (_currentPosition == 0) {
        await _player.startPlayback(widget.filePath);
      } else {
        await _player.resumePlayback();
      }

      setState(() {
        _isPlaying = true;
      });

      // Start position update timer
      _updatePosition();
    }
  }

  Future<void> _updatePosition() async {
    if (!mounted) return;

    try {
      final position = await _player.getPosition();
      setState(() {
        _currentPosition = position;
      });

      // Stop playback if we reach the end of the selection
      if (_currentPosition >= _endMs) {
        await _player.pausePlayback();
        setState(() {
          _isPlaying = false;
        });
      } else if (_isPlaying) {
        // Continue updating position
        Future.delayed(const Duration(milliseconds: 100), _updatePosition);
      }
    } catch (e) {
      debugPrint('Error updating position: $e');
    }
  }

  void _handleSelectionChanged(int startMs, int endMs) {
    setState(() {
      _startMs = startMs;
      _endMs = endMs;
    });
  }

  void _handlePositionTapped(int positionMs) async {
    await _player.seekTo(positionMs);
    setState(() {
      _currentPosition = positionMs;
    });
  }

  Future<void> _trimAudio() async {
    if (_startMs >= _endMs) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid selection range')));
      return;
    }

    setState(() {
      _isTrimming = true;
    });

    try {
      // Stop playback if playing
      if (_isPlaying) {
        await _player.pausePlayback();
        setState(() {
          _isPlaying = false;
        });
      }

      // Generate output file path
      final directory = await getTemporaryDirectory();
      final fileName = path.basename(widget.filePath);
      final outputPath = path.join(
        directory.path,
        'trimmed_${DateTime.now().millisecondsSinceEpoch}_$fileName',
      );

      // Trim the audio file
      final success = await _player.trimWavFile(
        widget.filePath,
        outputPath,
        _startMs,
        _endMs,
      );

      if (success) {
        if (widget.onTrimComplete != null) {
          widget.onTrimComplete!(outputPath);
        }
      } else if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to trim audio')));
      }
    } catch (e) {
      debugPrint('Error trimming audio: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error trimming audio: $e')));
      }
    } finally {
      setState(() {
        _isTrimming = false;
      });
    }
  }

  String _formatDuration(int milliseconds) {
    final seconds = (milliseconds / 1000).floor();
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Trim Audio',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: SizedBox(
            height: 120,
            child: WaveformView(
              filePath: widget.filePath,
              samplesCount: 200,
              enableSelection: true,
              onSelectionChanged: _handleSelectionChanged,
              onPositionTapped: _handlePositionTapped,
              currentPositionMs: _currentPosition,
              durationMs: _duration,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatDuration(_startMs)),
              Text(_formatDuration(_endMs)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: _togglePlayback,
              iconSize: 36,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              onPressed: widget.onCancel,
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isTrimming ? null : _trimAudio,
              child:
                  _isTrimming
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Text('Trim'),
            ),
          ],
        ),
      ],
    );
  }
}
