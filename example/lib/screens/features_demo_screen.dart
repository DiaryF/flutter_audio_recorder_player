import 'package:flutter/material.dart';
import 'package:mymedia/mymedia.dart';
import 'package:provider/provider.dart';
import '../controllers/audio_controller.dart';
import '../widgets/audio_visualizer.dart';
import '../widgets/pcm_visualizer.dart';
import '../widgets/now_playing_mini.dart';
import '../widgets/audio_recorder_widget.dart';

/// Screen for demonstrating all plugin features
class FeaturesDemoScreen extends StatefulWidget {
  /// Creates a new FeaturesDemoScreen
  const FeaturesDemoScreen({super.key});

  @override
  State<FeaturesDemoScreen> createState() => _FeaturesDemoScreenState();
}

class _FeaturesDemoScreenState extends State<FeaturesDemoScreen> {
  final Mymedia _mymediaPlugin = Mymedia();

  // Feature toggles
  bool _showVisualizer = true;
  bool _showPcmData = true;
  bool _showRecorder = true;
  bool _showPlaybackControls = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final audioController = Provider.of<AudioController>(context);
    final state = audioController.state;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Features Demo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showFeatureToggles,
            tooltip: 'Configure Features',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Info panel
            Container(
              padding: const EdgeInsets.all(16),
              color: theme.colorScheme.primaryContainer.withAlpha(76),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'All Features Demo',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This screen demonstrates all the features of the mymedia plugin in one place. '
                    'Use the settings button to toggle which features are displayed.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),

            // Main content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Playback Status
                    Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Playback Status',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 16),

                            // Status info
                            ListTile(
                              leading: Icon(
                                state.isPlaying ? Icons.play_arrow : Icons.stop,
                                color:
                                    state.isPlaying
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.error,
                                size: 32,
                              ),
                              title: Text(
                                state.isPlaying ? 'Playing' : 'Stopped',
                                style: theme.textTheme.titleMedium,
                              ),
                              subtitle: Text(
                                state.isPlaying
                                    ? state.currentTitle
                                    : 'No audio playing',
                              ),
                            ),

                            if (state.isPlaying) ...[
                              // Position and duration
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(state.positionText),
                                    Text(state.durationText),
                                  ],
                                ),
                              ),

                              // Progress bar
                              Slider(
                                value: state.playbackPosition,
                                max: state.duration > 0 ? state.duration : 1,
                                onChanged: (value) {
                                  audioController.seekTo(value.toInt());
                                },
                              ),
                            ],

                            // Playback controls
                            if (_showPlaybackControls && state.isPlaying)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.replay_10),
                                      onPressed:
                                          () => audioController.seekRelative(
                                            -10000,
                                          ),
                                      tooltip: 'Rewind 10s',
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        state.isPaused
                                            ? Icons.play_arrow
                                            : Icons.pause,
                                        size: 36,
                                      ),
                                      onPressed:
                                          () =>
                                              audioController.togglePlayPause(),
                                      tooltip:
                                          state.isPaused ? 'Play' : 'Pause',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.stop),
                                      onPressed:
                                          () => audioController.stopPlayback(),
                                      tooltip: 'Stop',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.forward_10),
                                      onPressed:
                                          () => audioController.seekRelative(
                                            10000,
                                          ),
                                      tooltip: 'Forward 10s',
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    // Audio Visualizer
                    if (_showVisualizer)
                      Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Audio Visualization',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pushNamed(
                                        context,
                                        '/visualization',
                                      );
                                    },
                                    child: const Text('Full Screen'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 150,
                                child: AudioVisualizer(
                                  mymediaPlugin: _mymediaPlugin,
                                  showWaveform: true,
                                  showSpectrum: false,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // PCM Data
                    if (_showPcmData)
                      Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'PCM Data',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pushNamed(
                                        context,
                                        '/visualization',
                                      );
                                    },
                                    child: const Text('Full Screen'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 100,
                                child: PcmVisualizer(
                                  mymediaPlugin: _mymediaPlugin,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Audio Recorder
                    if (_showRecorder)
                      Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Audio Recorder',
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 16),
                              AudioRecorderWidget(
                                mymediaPlugin: _mymediaPlugin,
                                isPlaying: state.isPlaying,
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Feature Navigation
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'More Features',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 16),

                            // Background Playback
                            ListTile(
                              leading: const Icon(Icons.notifications_active),
                              title: const Text('Background Playback'),
                              subtitle: const Text(
                                'Control playback from notifications',
                              ),
                              trailing: const Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                              ),
                              onTap: () {
                                Navigator.pushNamed(context, '/background');
                              },
                            ),

                            // Advanced Player
                            ListTile(
                              leading: const Icon(Icons.queue_music),
                              title: const Text('Advanced Player'),
                              subtitle: const Text(
                                'Playlist, speed control, and more',
                              ),
                              trailing: const Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                              ),
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  '/advanced_player',
                                );
                              },
                            ),

                            // Playlist
                            ListTile(
                              leading: const Icon(Icons.playlist_play),
                              title: const Text('Playlist'),
                              subtitle: const Text(
                                'Manage and play multiple tracks',
                              ),
                              trailing: const Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                              ),
                              onTap: () {
                                Navigator.pushNamed(context, '/playlist');
                              },
                            ),

                            // Recordings
                            ListTile(
                              leading: const Icon(Icons.mic),
                              title: const Text('Recordings'),
                              subtitle: const Text(
                                'Browse and play your recordings',
                              ),
                              trailing: const Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                              ),
                              onTap: () {
                                Navigator.pushNamed(context, '/recordings');
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Now playing mini player
            if (state.isPlaying) NowPlayingMini(controller: audioController),
          ],
        ),
      ),
    );
  }

  void _showFeatureToggles() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Configure Features'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: const Text('Audio Visualizer'),
                    value: _showVisualizer,
                    onChanged: (value) {
                      setState(() {
                        _showVisualizer = value;
                      });
                      this.setState(() {});
                    },
                  ),
                  SwitchListTile(
                    title: const Text('PCM Data'),
                    value: _showPcmData,
                    onChanged: (value) {
                      setState(() {
                        _showPcmData = value;
                      });
                      this.setState(() {});
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Audio Recorder'),
                    value: _showRecorder,
                    onChanged: (value) {
                      setState(() {
                        _showRecorder = value;
                      });
                      this.setState(() {});
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Playback Controls'),
                    value: _showPlaybackControls,
                    onChanged: (value) {
                      setState(() {
                        _showPlaybackControls = value;
                      });
                      this.setState(() {});
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
