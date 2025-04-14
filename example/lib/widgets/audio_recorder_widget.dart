import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mymedia/mymedia.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../controllers/recordings_controller.dart';
import '../utils/permission_handler.dart';

/// A widget that provides controls for recording audio
class AudioRecorderWidget extends StatefulWidget {
  /// The Mymedia plugin instance
  final Mymedia mymediaPlugin;

  /// Whether audio is currently playing
  final bool isPlaying;

  /// Creates a new AudioRecorderWidget
  const AudioRecorderWidget({
    super.key,
    required this.mymediaPlugin,
    required this.isPlaying,
  });

  @override
  State<AudioRecorderWidget> createState() => _AudioRecorderWidgetState();
}

class _AudioRecorderWidgetState extends State<AudioRecorderWidget> {
  bool _isRecording = false;
  String? _lastRecordedFile;
  DateTime? _recordingStartTime;

  // Timer for updating recording duration
  Timer? _recordingTimer;
  String _recordingDuration = '00:00';

  // Blinking indicator state
  bool _indicatorVisible = true;
  Timer? _blinkTimer;

  // Recording quality settings
  int _sampleRate = 44100;
  int _channels = 2;
  int _bitDepth = 16;

  // Available quality options
  final List<int> _sampleRateOptions = [8000, 16000, 22050, 44100, 48000];
  final List<int> _channelsOptions = [1, 2];
  final List<int> _bitDepthOptions = [8, 16]; // Removed 24-bit option

  // Quality presets
  final Map<String, Map<String, int>> _qualityPresets = {
    'Low': {'sampleRate': 8000, 'channels': 1, 'bitDepth': 8},
    'Medium': {'sampleRate': 22050, 'channels': 1, 'bitDepth': 16},
    'High': {'sampleRate': 44100, 'channels': 2, 'bitDepth': 16},
    'Ultra': {
      'sampleRate': 48000,
      'channels': 2,
      'bitDepth': 16,
    }, // Changed from 24-bit to 16-bit
  };

  @override
  void initState() {
    super.initState();
    // Don't check permissions in initState to avoid crashes
    // We'll check permissions when needed
  }

  @override
  void dispose() {
    // Clean up resources
    _recordingTimer?.cancel();
    _blinkTimer?.cancel();
    super.dispose();
  }

  /// Check and request necessary permissions
  Future<bool> _checkPermissions() async {
    debugPrint('Checking permissions...');
    return await PermissionUtil.requestStoragePermissions(context);
  }

  /// Start recording the current audio
  Future<void> _startRecording() async {
    if (!widget.isPlaying) {
      _showMessage('Start playback before recording', isError: true);
      return;
    }

    // Check permissions first
    final hasPermissions = await _checkPermissions();
    if (!hasPermissions) {
      return;
    }

    // Prevent multiple recording attempts
    if (_isRecording) {
      debugPrint('Already recording, ignoring request');
      return;
    }

    try {
      // Set recording state to true immediately to prevent multiple starts
      setState(() {
        _isRecording = true;
        _recordingDuration = '00:00';
        _indicatorVisible = true;
      });

      // Start blinking indicator
      _blinkTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
        if (mounted) {
          setState(() {
            _indicatorVisible = !_indicatorVisible;
          });
        }
      });

      final success = await widget.mymediaPlugin
          .startRecording(
            sampleRate: _sampleRate,
            channels: _channels,
            bitDepth: _bitDepth,
          )
          .timeout(
            Duration(seconds: 5),
            onTimeout: () {
              // If it takes too long, assume it failed
              debugPrint('Recording start timed out');
              return false;
            },
          );

      if (success) {
        final startTime = DateTime.now();
        setState(() {
          _recordingStartTime = startTime;
        });

        // Start a timer to update the recording duration
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            final duration = DateTime.now().difference(startTime);
            setState(() {
              _recordingDuration = _formatDuration(duration);
            });
          }
        });

        _showMessage(
          'Recording started with quality: $_sampleRate Hz, $_channels ch, $_bitDepth-bit',
        );
      } else {
        setState(() {
          _isRecording = false;
        });
        _showMessage('Failed to start recording', isError: true);
      }
    } catch (e) {
      setState(() {
        _isRecording = false;
      });
      _showMessage('Error starting recording: $e', isError: true);
    }
  }

  /// Stop recording and save the audio as a WAV file
  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    // Set recording state to false immediately to prevent multiple stops
    setState(() {
      _isRecording = false;
    });

    // Cancel the timers
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _blinkTimer?.cancel();
    _blinkTimer = null;

    try {
      // Check permissions first
      final hasPermissions = await _checkPermissions();
      if (!hasPermissions) {
        _showMessage(
          'Storage permission required to save recording',
          isError: true,
        );
        setState(() {
          _isRecording = false;
        });
        return;
      }

      // Get a writable directory for saving recordings
      String? dirPath = await PermissionUtil.getWritableDirectory();

      // If external storage is not available, fall back to app-specific directory
      if (dirPath == null) {
        debugPrint('External storage not available, using app directory');
        final directory = await getApplicationDocumentsDirectory();
        dirPath = directory.path;
      }

      debugPrint('Using directory: $dirPath');

      // Create a recordings subdirectory
      final recordingsDir = Directory('$dirPath/recordings');
      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
      }

      // Verify directory is writable
      try {
        final testFile = File('${recordingsDir.path}/test_write.tmp');
        await testFile.writeAsString('test');
        await testFile.delete();
        debugPrint('Directory is writable');
      } catch (e) {
        debugPrint('Directory is not writable: $e');
        _showMessage(
          'Cannot write to storage. Please check app permissions.',
          isError: true,
        );
        return;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'recording_$timestamp.wav';
      final filePath = '${recordingsDir.path}/$fileName';

      debugPrint('Saving recording to: $filePath');

      // Stop recording and save the file
      final success = await widget.mymediaPlugin.stopRecording(filePath);
      debugPrint('Recording save result: $success');

      if (success) {
        setState(() {
          _lastRecordedFile = filePath;
        });

        final duration =
            _recordingStartTime != null
                ? DateTime.now().difference(_recordingStartTime!)
                : Duration.zero;

        _showMessage(
          'Recording saved: $fileName\n'
          'Duration: ${_formatDuration(duration)}',
          action: SnackBarAction(
            label: 'SHARE',
            onPressed: () => _shareFile(filePath),
          ),
        );

        // Verify the file exists
        final file = File(filePath);
        final exists = await file.exists();
        final size = exists ? await file.length() : 0;
        debugPrint('File exists: $exists, size: $size bytes');

        if (!exists || size == 0) {
          _showMessage(
            'File was created but appears to be empty or missing',
            isError: true,
          );
        } else {
          // Refresh the recordings list
          if (mounted) {
            final recordingsController = Provider.of<RecordingsController>(
              context,
              listen: false,
            );
            recordingsController.refreshRecordings();
          }
        }
      } else {
        _showMessage('Failed to save recording', isError: true);
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      // No need to set _isRecording to false again, we already did it at the beginning
      _showMessage('Error: $e', isError: true);
    }
  }

  /// Cancel the current recording without saving
  Future<void> _cancelRecording() async {
    if (!_isRecording) return;

    final success = await widget.mymediaPlugin.cancelRecording();

    setState(() {
      _isRecording = false;
    });

    // Cancel the timers
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _blinkTimer?.cancel();
    _blinkTimer = null;

    if (success) {
      _showMessage('Recording canceled');
    } else {
      _showMessage('Failed to cancel recording', isError: true);
    }
  }

  /// Format a duration as mm:ss
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Show a message to the user
  void _showMessage(
    String message, {
    bool isError = false,
    SnackBarAction? action,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        action: action,
      ),
    );
  }

  /// Share a file using the share_plus package
  Future<void> _shareFile(String filePath) async {
    try {
      await Share.shareXFiles([
        XFile(filePath),
      ], text: 'Sharing audio recording');
    } catch (e) {
      _showMessage('Error sharing file: $e', isError: true);
    }
  }

  /// Show a dialog to configure recording quality
  Future<void> _showQualitySettingsDialog() async {
    // Create a copy of the current settings
    int sampleRate = _sampleRate;
    int channels = _channels;
    int bitDepth = _bitDepth;
    String preset = 'Custom';

    // Find if current settings match a preset
    for (final entry in _qualityPresets.entries) {
      final presetSettings = entry.value;
      if (presetSettings['sampleRate'] == _sampleRate &&
          presetSettings['channels'] == _channels &&
          presetSettings['bitDepth'] == _bitDepth) {
        preset = entry.key;
        break;
      }
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setState) {
              // Apply preset settings
              void applyPreset(String presetName) {
                if (_qualityPresets.containsKey(presetName)) {
                  final presetSettings = _qualityPresets[presetName]!;
                  setState(() {
                    preset = presetName;
                    sampleRate = presetSettings['sampleRate']!;
                    channels = presetSettings['channels']!;
                    bitDepth = presetSettings['bitDepth']!;
                  });
                }
              }

              return AlertDialog(
                title: const Text('Recording Quality'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Presets
                      const Text(
                        'Preset:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children:
                            _qualityPresets.keys.map((presetName) {
                              return ChoiceChip(
                                label: Text(presetName),
                                selected: preset == presetName,
                                onSelected: (selected) {
                                  if (selected) {
                                    applyPreset(presetName);
                                  }
                                },
                              );
                            }).toList(),
                      ),

                      const Divider(),

                      // Sample rate
                      const Text(
                        'Sample Rate:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children:
                            _sampleRateOptions.map((rate) {
                              return ChoiceChip(
                                label: Text('$rate Hz'),
                                selected: sampleRate == rate,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      sampleRate = rate;
                                      preset = 'Custom';
                                    });
                                  }
                                },
                              );
                            }).toList(),
                      ),

                      const SizedBox(height: 16),

                      // Channels
                      const Text(
                        'Channels:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children:
                            _channelsOptions.map((ch) {
                              return ChoiceChip(
                                label: Text(ch == 1 ? 'Mono' : 'Stereo'),
                                selected: channels == ch,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      channels = ch;
                                      preset = 'Custom';
                                    });
                                  }
                                },
                              );
                            }).toList(),
                      ),

                      const SizedBox(height: 16),

                      // Bit depth
                      const Text(
                        'Bit Depth:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children:
                            _bitDepthOptions.map((depth) {
                              return ChoiceChip(
                                label: Text('$depth-bit'),
                                selected: bitDepth == depth,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      bitDepth = depth;
                                      preset = 'Custom';
                                    });
                                  }
                                },
                              );
                            }).toList(),
                      ),

                      const SizedBox(height: 16),

                      // File size estimate
                      Text(
                        'Estimated file size: ${_estimateFileSize(sampleRate, channels, bitDepth)} per minute',
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('CANCEL'),
                  ),
                  TextButton(
                    onPressed:
                        () => Navigator.of(context).pop({
                          'sampleRate': sampleRate,
                          'channels': channels,
                          'bitDepth': bitDepth,
                        }),
                    child: const Text('APPLY'),
                  ),
                ],
              );
            },
          ),
    );

    if (result != null) {
      setState(() {
        _sampleRate = result['sampleRate'];
        _channels = result['channels'];
        _bitDepth = result['bitDepth'];
      });

      _showMessage(
        'Recording quality set to: $_sampleRate Hz, $_channels ch, $_bitDepth-bit',
      );
    }
  }

  /// Estimate the file size based on recording parameters
  String _estimateFileSize(int sampleRate, int channels, int bitDepth) {
    // Calculate bytes per second
    final bytesPerSecond = sampleRate * channels * (bitDepth / 8);
    final bytesPerMinute = bytesPerSecond * 60;

    // Convert to KB or MB
    if (bytesPerMinute < 1024 * 1024) {
      final kb = bytesPerMinute / 1024;
      return '${kb.toStringAsFixed(1)} KB';
    } else {
      final mb = bytesPerMinute / (1024 * 1024);
      return '${mb.toStringAsFixed(1)} MB';
    }
  }

  /// Build a quality info item widget
  Widget _buildQualityInfoItem(ThemeData theme, String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withAlpha(
              204,
            ), // 0.8 * 255 = 204
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontFamily: label == 'Sample Rate' ? 'monospace' : null,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Audio Recorder',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            if (_isRecording)
              Column(
                children: [
                  // Recording indicator with animation
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Blinking recording indicator
                      Opacity(
                        opacity: _indicatorVisible ? 1.0 : 0.3,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Recording...',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Recording duration
                      Text(
                        _recordingDuration,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Recording quality info
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Recording Quality',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildQualityInfoItem(
                              theme,
                              'Sample Rate',
                              '$_sampleRate Hz',
                            ),
                            _buildQualityInfoItem(
                              theme,
                              'Channels',
                              '$_channels',
                            ),
                            _buildQualityInfoItem(
                              theme,
                              'Bit Depth',
                              '$_bitDepth-bit',
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Est. size: ${_estimateFileSize(_sampleRate, _channels, _bitDepth)}/min',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Recording controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _stopRecording,
                        icon: const Icon(Icons.stop),
                        label: const Text('Stop & Save'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                        ),
                      ),

                      OutlinedButton.icon(
                        onPressed: _cancelRecording,
                        icon: const Icon(Icons.delete),
                        label: const Text('Cancel'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ],
              )
            else
              Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: widget.isPlaying ? _startRecording : null,
                    icon: const Icon(Icons.fiber_manual_record),
                    label: const Text('Start Recording'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Quality settings button
                  OutlinedButton.icon(
                    onPressed: _showQualitySettingsDialog,
                    icon: const Icon(Icons.settings),
                    label: const Text('Quality Settings'),
                  ),

                  const SizedBox(height: 8),

                  // Current quality indicator
                  Text(
                    'Quality: $_sampleRate Hz, $_channels ch, $_bitDepth-bit',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),

            if (_lastRecordedFile != null && !_isRecording)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.outline.withAlpha(100),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Last Recording',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _lastRecordedFile!.split('/').last,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFamily: 'monospace',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton.icon(
                            onPressed: () => _shareFile(_lastRecordedFile!),
                            icon: const Icon(Icons.share, size: 16),
                            label: const Text('Share'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          const SizedBox(width: 16),
                          TextButton.icon(
                            onPressed: () {
                              if (mounted) {
                                final recordingsController =
                                    Provider.of<RecordingsController>(
                                      context,
                                      listen: false,
                                    );
                                recordingsController.refreshRecordings();
                                Navigator.pushNamed(context, '/recordings');
                              }
                            },
                            icon: const Icon(Icons.list, size: 16),
                            label: const Text('View All'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
