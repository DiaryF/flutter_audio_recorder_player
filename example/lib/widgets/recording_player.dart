import 'dart:async';

import 'package:flutter/material.dart';
import '../models/recording.dart';
import '../controllers/recordings_controller.dart';

/// Widget for playing recordings
class RecordingPlayer extends StatefulWidget {
  /// The recording to play
  final Recording recording;

  /// The recordings controller
  final RecordingsController controller;

  /// Called when the recording is deleted
  final VoidCallback? onDeleted;

  /// Creates a new RecordingPlayer
  const RecordingPlayer({
    super.key,
    required this.recording,
    required this.controller,
    this.onDeleted,
  });

  @override
  State<RecordingPlayer> createState() => _RecordingPlayerState();
}

class _RecordingPlayerState extends State<RecordingPlayer> {
  bool _isPlaying = false;
  bool _isPaused = false;
  int _position = 0;
  int _duration = 0;

  // Timer for updating position
  Timer? _positionTimer;

  @override
  void initState() {
    super.initState();
    // Initialize the player but don't start playback automatically
    _preparePlayer();

    // Only start the position timer if this is the currently playing recording
    final isCurrentlyPlaying =
        widget.controller.currentlyPlaying?.file.path ==
        widget.recording.file.path;
    if (isCurrentlyPlaying) {
      _isPlaying = true;
      _isPaused = widget.controller.audioService.isPaused;
      _startPositionTimer();
    }
  }

  @override
  void dispose() {
    _positionTimer?.cancel();
    // Don't stop playback when disposing, as we're using a shared player
    super.dispose();
  }

  void _startPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _updatePosition();
    });
  }

  Future<void> _updatePosition() async {
    if (!mounted) return;

    // Only update position if this is the currently playing recording
    final isCurrentlyPlaying =
        widget.controller.currentlyPlaying?.file.path ==
        widget.recording.file.path;

    if (isCurrentlyPlaying) {
      try {
        final position = await widget.controller.audioService.getPosition();
        final duration = await widget.controller.audioService.getDuration();

        setState(() {
          _position = position;
          _duration = duration;
          _isPlaying = widget.controller.isPlaying;
          _isPaused = widget.controller.audioService.isPaused;
        });

        // Update the recording duration if needed
        if (duration > 0) {
          widget.controller.updateRecordingDuration(widget.recording, duration);
        }
      } catch (e) {
        debugPrint('Error updating position: $e');
      }
    }
  }

  // Prepare the player without starting playback
  Future<void> _preparePlayer() async {
    try {
      // Check if file exists
      final file = widget.recording.file;
      if (!file.existsSync()) {
        debugPrint('Recording file does not exist: ${file.path}');
        return;
      }

      // If this is the currently playing recording, get its duration
      final isCurrentlyPlaying =
          widget.controller.currentlyPlaying?.file.path ==
          widget.recording.file.path;

      if (isCurrentlyPlaying) {
        final duration = await widget.controller.audioService.getDuration();
        if (duration > 0) {
          setState(() {
            _duration = duration;
          });
        }
      }

      debugPrint('Player prepared for: ${file.path}');
    } catch (e) {
      debugPrint('Error preparing player: $e');
    }
  }

  // Start playback of the recording
  Future<void> _initPlayer() async {
    try {
      // Play the recording using the controller
      final success = await widget.controller.playRecording(widget.recording);

      if (success) {
        setState(() {
          _isPlaying = true;
          _isPaused = false;
          _position = 0; // Reset position
        });

        debugPrint(
          'Successfully started playback for: ${widget.recording.file.path}',
        );
      } else {
        debugPrint(
          'Failed to start playback for: ${widget.recording.file.path}',
        );
      }
    } catch (e) {
      debugPrint('Error initializing player: $e');
      // Show a snackbar if there's an error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing recording: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _togglePlayPause() async {
    try {
      if (_isPlaying) {
        if (_isPaused) {
          // Resume playback
          final success = await widget.controller.resumePlayback();
          if (success) {
            setState(() {
              _isPaused = false;
            });
            // Start position timer if not already running
            if (_positionTimer == null || !_positionTimer!.isActive) {
              _startPositionTimer();
            }
            // Force update position to ensure UI is in sync
            await _updatePosition();
          }
        } else {
          // Pause playback
          final success = await widget.controller.pausePlayback();
          if (success) {
            setState(() {
              _isPaused = true;
            });
            // Force update position to ensure UI is in sync
            await _updatePosition();
          }
        }
      } else {
        // Start playback
        await _initPlayer();
        // Start position timer
        _startPositionTimer();
      }
    } catch (e) {
      debugPrint('Error toggling play/pause: $e');
    }
  }

  Future<void> _seekTo(int position) async {
    try {
      await widget.controller.audioService.seekTo(position);
    } catch (e) {
      debugPrint('Error seeking: $e');
    }
  }

  Future<void> _shareRecording() async {
    await widget.controller.shareRecording(widget.recording);
  }

  Future<void> _deleteRecording() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Recording'),
            content: Text(
              'Are you sure you want to delete "${widget.recording.name}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('DELETE'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      final success = await widget.controller.deleteRecording(widget.recording);
      if (success && mounted) {
        widget.onDeleted?.call();
      }
    }
  }

  Future<void> _renameRecording() async {
    final controller = TextEditingController(text: widget.recording.name);

    final newName = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Rename Recording'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(controller.text),
                child: const Text('RENAME'),
              ),
            ],
          ),
    );

    if (newName != null &&
        newName.isNotEmpty &&
        newName != widget.recording.name) {
      widget.controller.renameRecording(widget.recording, newName);
    }
  }

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Recording info
            Row(
              children: [
                // Play/Pause button
                IconButton(
                  icon: Icon(
                    _isPlaying && !_isPaused ? Icons.pause : Icons.play_arrow,
                  ),
                  onPressed: _togglePlayPause,
                  iconSize: 32,
                  color: theme.colorScheme.primary,
                ),

                const SizedBox(width: 8),

                // Recording info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.recording.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${widget.recording.formattedDate} • ${widget.recording.formattedFileSize}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),

                // Menu button
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'rename':
                        _renameRecording();
                        break;
                      case 'share':
                        _shareRecording();
                        break;
                      case 'delete':
                        _deleteRecording();
                        break;
                    }
                  },
                  itemBuilder:
                      (context) => [
                        const PopupMenuItem(
                          value: 'rename',
                          child: Row(
                            children: [
                              Icon(Icons.edit),
                              SizedBox(width: 8),
                              Text('Rename'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'share',
                          child: Row(
                            children: [
                              Icon(Icons.share),
                              SizedBox(width: 8),
                              Text('Share'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete),
                              SizedBox(width: 8),
                              Text('Delete'),
                            ],
                          ),
                        ),
                      ],
                ),
              ],
            ),

            // Only show player controls if playing or paused
            if (_isPlaying || _isPaused)
              Column(
                children: [
                  const SizedBox(height: 8),

                  // Position and duration
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatDuration(_position)),
                        Text(_formatDuration(_duration)),
                      ],
                    ),
                  ),

                  // Progress bar
                  Slider(
                    value: _position.toDouble().clamp(0, _duration.toDouble()),
                    max: _duration.toDouble(),
                    min: 0,
                    onChanged: (value) {
                      _seekTo(value.toInt());
                    },
                  ),

                  // Playback controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.replay_10),
                        onPressed: () {
                          _seekTo((_position - 10000).clamp(0, _duration));
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          _isPlaying && !_isPaused
                              ? Icons.pause
                              : Icons.play_arrow,
                        ),
                        onPressed: _togglePlayPause,
                        iconSize: 48,
                        color: theme.colorScheme.primary,
                      ),
                      IconButton(
                        icon: const Icon(Icons.forward_10),
                        onPressed: () {
                          _seekTo((_position + 10000).clamp(0, _duration));
                        },
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
