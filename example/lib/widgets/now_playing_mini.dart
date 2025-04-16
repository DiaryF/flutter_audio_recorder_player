import 'package:flutter/material.dart';
import '../controllers/audio_controller.dart';
import '../models/audio_player_state.dart';

/// A mini player widget that shows at the bottom of the screen
class NowPlayingMini extends StatelessWidget {
  /// The audio controller
  final AudioController controller;

  /// Creates a new NowPlayingMini
  const NowPlayingMini({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = controller.state;

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

    return GestureDetector(
      onTap: () {
        // TODO: Navigate to now playing screen
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Source icon
            CircleAvatar(
              backgroundColor: theme.colorScheme.primary,
              radius: 16,
              child: Icon(
                sourceIcon,
                color: theme.colorScheme.onPrimary,
                size: 16,
              ),
            ),

            const SizedBox(width: 12),

            // Title and position
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    state.currentTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        state.positionText,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer.withAlpha(
                            200,
                          ),
                          fontFamily: 'monospace',
                        ),
                      ),
                      Text(
                        ' / ',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer.withAlpha(
                            150,
                          ),
                        ),
                      ),
                      Text(
                        state.durationText,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer.withAlpha(
                            200,
                          ),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Playback controls
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    state.isPaused ? Icons.play_arrow : Icons.pause,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  onPressed: controller.togglePlayPause,
                  iconSize: 28,
                ),
                IconButton(
                  icon: Icon(Icons.stop, color: theme.colorScheme.error),
                  onPressed: controller.stopPlayback,
                  iconSize: 28,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
