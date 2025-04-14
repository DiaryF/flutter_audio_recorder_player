import 'package:flutter/material.dart';
import '../controllers/audio_controller.dart';
import '../models/audio_player_state.dart';
import '../utils/format_utils.dart';

/// Widget that displays a list of available streams
class StreamList extends StatelessWidget {
  /// The audio controller
  final AudioController controller;

  /// The current state of the audio player
  final AudioPlayerState state;

  /// Creates a new StreamList
  const StreamList({super.key, required this.controller, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stream selection title
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Text('Available Streams', style: theme.textTheme.titleMedium),
        ),

        // Stream selection list
        ...List.generate(controller.streamUrls.length, (index) {
          final url = controller.streamUrls[index];
          final isCurrentlyPlaying =
              state.isPlaying &&
              state.sourceType == AudioSourceType.stream &&
              state.currentSource == url;
          final displayName = FormatUtils.createDisplayName(url);

          return Card(
            margin: const EdgeInsets.only(bottom: 12.0),
            color:
                isCurrentlyPlaying
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surface,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              leading: CircleAvatar(
                backgroundColor:
                    isCurrentlyPlaying
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest,
                child: Icon(
                  isCurrentlyPlaying ? Icons.music_note : Icons.radio,
                  color:
                      isCurrentlyPlaying
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.primary,
                ),
              ),
              title: Text(
                displayName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight:
                      isCurrentlyPlaying ? FontWeight.bold : FontWeight.normal,
                  color:
                      isCurrentlyPlaying
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurface,
                ),
              ),
              subtitle: Text(
                'Radio Paradise',
                style: theme.textTheme.bodySmall?.copyWith(
                  color:
                      isCurrentlyPlaying
                          ? theme.colorScheme.onPrimaryContainer.withAlpha(200)
                          : theme.colorScheme.onSurface.withAlpha(150),
                ),
              ),
              trailing: IconButton(
                icon: Icon(
                  isCurrentlyPlaying ? Icons.stop : Icons.play_arrow,
                  color:
                      isCurrentlyPlaying
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                ),
                onPressed: () => controller.toggleStreamPlayback(url),
              ),
              onTap: () => controller.toggleStreamPlayback(url),
            ),
          );
        }),

        // Stop button (only show when playing)
        if (state.isPlaying)
          Padding(
            padding: const EdgeInsets.only(top: 24.0),
            child: OutlinedButton.icon(
              onPressed: controller.stopPlayback,
              icon: Icon(Icons.stop_circle, color: theme.colorScheme.error),
              label: Text(
                'Stop All Playback',
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: theme.colorScheme.error),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
