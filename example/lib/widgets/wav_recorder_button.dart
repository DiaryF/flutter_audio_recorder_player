import 'package:flutter/material.dart';
import 'package:mymedia/mymedia.dart';
import 'package:path_provider/path_provider.dart';

/// A button that records the current PCM buffer to a WAV file
class WavRecorderButton extends StatefulWidget {
  /// The Mymedia plugin instance
  final Mymedia mymediaPlugin;

  /// Whether audio is currently playing
  final bool isPlaying;

  /// Creates a new WavRecorderButton
  const WavRecorderButton({
    super.key,
    required this.mymediaPlugin,
    required this.isPlaying,
  });

  @override
  State<WavRecorderButton> createState() => _WavRecorderButtonState();
}

class _WavRecorderButtonState extends State<WavRecorderButton> {
  bool _isRecording = false;
  String? _lastRecordedFile;

  Future<void> _recordWav() async {
    if (!widget.isPlaying) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Start playback before recording'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isRecording = true;
    });

    try {
      // Get the documents directory
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${directory.path}/recording_$timestamp.wav';

      // Save the PCM data as a WAV file
      final success = await widget.mymediaPlugin.savePcmAsWav(filePath);

      if (success) {
        setState(() {
          _lastRecordedFile = filePath;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Recording saved to: $filePath'),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'SHARE',
                onPressed: () => _shareFile(filePath),
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save recording'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() {
        _isRecording = false;
      });
    }
  }

  Future<void> _shareFile(String filePath) async {
    // Implement file sharing functionality here
    // This would typically use a package like share_plus
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sharing functionality not implemented'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton.icon(
          onPressed: _isRecording ? null : _recordWav,
          icon: Icon(
            _isRecording ? Icons.hourglass_empty : Icons.save_alt,
            color:
                widget.isPlaying
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface.withAlpha(100),
          ),
          label: Text(_isRecording ? 'Recording...' : 'Save as WAV'),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                widget.isPlaying
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surface,
            foregroundColor:
                widget.isPlaying
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface.withAlpha(100),
            disabledBackgroundColor: theme.colorScheme.primary.withAlpha(150),
            disabledForegroundColor: theme.colorScheme.onPrimary.withAlpha(150),
          ),
        ),

        if (_lastRecordedFile != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Last recording: ${_lastRecordedFile!.split('/').last}',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}
