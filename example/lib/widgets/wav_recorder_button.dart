import 'package:flutter/material.dart';
import 'package:mymedia/mymedia.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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

      // Use the savePcmAsWav method to save the current PCM buffer as a WAV file
      final success = await widget.mymediaPlugin.savePcmAsWav(filePath);

      if (success) {
        setState(() {
          _lastRecordedFile = filePath;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PCM data saved to: ${filePath.split('/').last}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'Share',
                onPressed: () => _shareFile(filePath),
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save PCM data'),
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

  /// Share the recording file using the share_plus package
  Future<void> _shareFile(String filePath) async {
    try {
      await Share.shareXFiles([
        XFile(filePath),
      ], text: 'Check out my audio recording!');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and description
            Text(
              'Save PCM Data as WAV',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Capture the current audio buffer and save it as a WAV file.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),

            // Button
            Center(
              child: ElevatedButton.icon(
                onPressed:
                    _isRecording || !widget.isPlaying ? null : _recordWav,
                icon: Icon(
                  _isRecording ? Icons.hourglass_empty : Icons.save_alt,
                ),
                label: Text(_isRecording ? 'Saving...' : 'Save Current Buffer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  disabledBackgroundColor: theme.colorScheme.primary.withAlpha(
                    150,
                  ),
                  disabledForegroundColor: theme.colorScheme.onPrimary
                      .withAlpha(150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ),

            // Status text
            if (!widget.isPlaying)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Center(
                  child: Text(
                    'Start playback to enable WAV saving',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

            // Last recording info
            if (_lastRecordedFile != null)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: theme.colorScheme.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Last saved: ${_lastRecordedFile!.split('/').last}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
