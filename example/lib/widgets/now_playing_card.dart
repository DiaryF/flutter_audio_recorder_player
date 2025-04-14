import 'package:flutter/material.dart';
import '../controllers/audio_controller.dart';
import '../models/audio_player_state.dart';

/// Widget that displays the currently playing audio
class NowPlayingCard extends StatelessWidget {
  /// Get the appropriate icon for the audio source type
  IconData _getSourceIcon(AudioSourceType sourceType) {
    switch (sourceType) {
      case AudioSourceType.stream:
        return Icons.radio;
      case AudioSourceType.file:
        return Icons.audio_file;
      case AudioSourceType.recording:
        return Icons.mic;
      case AudioSourceType.none:
        return Icons.music_note;
    }
  }

  /// Get a descriptive text for the audio source type
  String _getSourceTypeText(AudioSourceType sourceType) {
    switch (sourceType) {
      case AudioSourceType.stream:
        return 'Live Stream';
      case AudioSourceType.file:
        return 'Local File';
      case AudioSourceType.recording:
        return 'Recording';
      case AudioSourceType.none:
        return 'Unknown Source';
    }
  }

  /// The audio controller
  final AudioController controller;

  /// The current state of the audio player
  final AudioPlayerState state;

  /// Creates a new NowPlayingCard
  const NowPlayingCard({
    super.key,
    required this.controller,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Debug print the state
    debugPrint(
      'NowPlayingCard build: isPlaying=${state.isPlaying}, isPaused=${state.isPaused}, title=${state.currentTitle}',
    );

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Album art placeholder with source-specific icon
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(
                  _getSourceIcon(state.sourceType),
                  size: 80,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Stream title with pause indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (state.isPaused)
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Icon(
                      Icons.pause_circle,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                  ),
                Flexible(
                  child: Text(
                    state.currentTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 4),

            Text(
              _getSourceTypeText(state.sourceType),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.secondary,
              ),
            ),

            // Artist/album info if available
            if (state.artist != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(state.artist!, style: theme.textTheme.bodyMedium),
              ),

            if (state.album != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  state.album!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(180),
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Playback position and duration
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(state.positionText, style: theme.textTheme.bodyMedium),
                Text(state.durationText, style: theme.textTheme.bodyMedium),
              ],
            ),

            const SizedBox(height: 8),

            // Progress bar
            Slider(
              value:
                  state.duration > 0
                      ? state.playbackPosition / state.duration
                      : 0.0,
              onChanged: (value) {
                // Calculate position based on percentage
                final newPosition = (state.duration * value).toInt();
                controller.seekTo(newPosition);
              },
            ),

            const SizedBox(height: 24),

            // Playback controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Rewind button (disabled for streams)
                IconButton(
                  icon: Icon(
                    Icons.replay_10,
                    color: theme.colorScheme.onSurface.withAlpha(100),
                  ),
                  iconSize: 36,
                  onPressed: null, // Disabled for streaming
                ),

                // Play/Pause button
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary,
                  ),
                  child: IconButton(
                    icon: Icon(
                      state.isPlaying && !state.isPaused
                          ? Icons.pause
                          : Icons.play_arrow,
                      color: theme.colorScheme.onPrimary,
                    ),
                    tooltip:
                        state.isPlaying && !state.isPaused ? 'Pause' : 'Play',
                    iconSize: 36,
                    onPressed: controller.togglePlayPause,
                  ),
                ),

                // Stop button
                IconButton(
                  icon: Icon(Icons.stop, color: theme.colorScheme.error),
                  iconSize: 36,
                  onPressed: controller.stopPlayback,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Volume control
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  Icon(
                    Icons.volume_down,
                    color: theme.colorScheme.onSurface,
                    size: 24,
                  ),
                  Expanded(
                    child: Slider(
                      value: state.volume,
                      onChanged: controller.setVolume,
                    ),
                  ),
                  Icon(
                    Icons.volume_up,
                    color: theme.colorScheme.onSurface,
                    size: 24,
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
