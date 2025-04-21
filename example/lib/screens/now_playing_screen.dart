import 'package:flutter/material.dart';
import '../controllers/audio_controller.dart';
import '../models/audio_player_state.dart';

/// Screen for displaying the currently playing audio
class NowPlayingScreen extends StatefulWidget {
  /// The audio controller
  final AudioController controller;

  /// Creates a new NowPlayingScreen
  const NowPlayingScreen({super.key, required this.controller});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  double _sliderValue = 0.0;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = widget.controller.state;

    // Update slider value if not dragging
    if (!_isDragging) {
      _sliderValue =
          state.playbackPosition / (state.duration > 0 ? state.duration : 1);
    }

    // Get the source type icon
    IconData sourceIcon;
    switch (state.sourceType) {
      case AudioSourceType.stream:
        sourceIcon = Icons.radio;
        break;
      case AudioSourceType.file:
        sourceIcon = Icons.audio_file;
        break;
      case AudioSourceType.recording:
        sourceIcon = Icons.mic;
        break;
      case AudioSourceType.none:
        sourceIcon = Icons.music_note;
        break;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Now Playing'), centerTitle: true),
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final currentState = widget.controller.state;

          return Column(
            children: [
              // Album art / source icon
              Expanded(
                flex: 3,
                child: Center(
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Icon(
                      sourceIcon,
                      size: 80,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),

              // Title and metadata
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        currentState.currentTitle,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _getSourceTypeText(currentState.sourceType),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: .7,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Playback controls
              Expanded(
                flex: 3,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Slider
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        children: [
                          Slider(
                            value: _sliderValue.clamp(0.0, 1.0),
                            onChanged: (value) {
                              setState(() {
                                _sliderValue = value;
                                _isDragging = true;
                              });
                            },
                            onChangeEnd: (value) {
                              setState(() {
                                _isDragging = false;
                              });
                              final newPosition =
                                  (value * currentState.duration).round();
                              widget.controller.seekTo(newPosition);
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  currentState.positionText,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                Text(
                                  currentState.durationText,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Control buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Skip backward button
                        IconButton(
                          icon: const Icon(Icons.replay_10),
                          onPressed:
                              () => widget.controller.seekRelative(-10000),
                          iconSize: 36,
                        ),

                        const SizedBox(width: 16),

                        // Play/Pause button
                        Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(
                              currentState.isPaused
                                  ? Icons.play_arrow
                                  : Icons.pause,
                              color: theme.colorScheme.onPrimary,
                            ),
                            onPressed: widget.controller.togglePlayPause,
                            iconSize: 48,
                            padding: const EdgeInsets.all(12),
                          ),
                        ),

                        const SizedBox(width: 16),

                        // Skip forward button
                        IconButton(
                          icon: const Icon(Icons.forward_10),
                          onPressed:
                              () => widget.controller.seekRelative(10000),
                          iconSize: 36,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Volume control
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Row(
                        children: [
                          const Icon(Icons.volume_down, size: 20),
                          Expanded(
                            child: Slider(
                              value: currentState.volume,
                              onChanged: (value) {
                                widget.controller.setVolume(value);
                              },
                            ),
                          ),
                          const Icon(Icons.volume_up, size: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _getSourceTypeText(AudioSourceType sourceType) {
    switch (sourceType) {
      case AudioSourceType.stream:
        return 'Streaming Audio';
      case AudioSourceType.file:
        return 'Local File';
      case AudioSourceType.recording:
        return 'Recording';
      case AudioSourceType.none:
        return 'Unknown Source';
    }
  }
}
