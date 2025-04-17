import 'package:flutter/material.dart';
import 'package:mymedia/mymedia.dart';
import 'package:provider/provider.dart';
import '../controllers/audio_controller.dart';
import '../models/audio_player_state.dart';
import '../widgets/audio_visualizer.dart';
import '../widgets/pcm_visualizer.dart';
import '../widgets/now_playing_mini.dart';

/// Screen for audio visualization
class VisualizationScreen extends StatefulWidget {
  /// Creates a new VisualizationScreen
  const VisualizationScreen({super.key});

  @override
  State<VisualizationScreen> createState() => _VisualizationScreenState();
}

class _VisualizationScreenState extends State<VisualizationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Mymedia _mymediaPlugin = Mymedia();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final audioController = Provider.of<AudioController>(context);
    final state = audioController.state;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Visualization'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Waveform & Spectrum', icon: Icon(Icons.graphic_eq)),
            Tab(text: 'PCM Data', icon: Icon(Icons.audio_file)),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Info panel
            if (state.isPlaying)
              Container(
                padding: const EdgeInsets.all(16),
                color: theme.colorScheme.primaryContainer.withAlpha(76),
                child: Row(
                  children: [
                    Icon(
                      state.sourceType == AudioSourceType.stream
                          ? Icons.radio
                          : Icons.music_note,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Now Playing:',
                            style: theme.textTheme.bodySmall,
                          ),
                          Text(
                            state.currentTitle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                color: theme.colorScheme.errorContainer.withAlpha(76),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: theme.colorScheme.error),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Start playback to see audio visualization',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),

            // Main content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Waveform & Spectrum tab
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: AudioVisualizer(
                      mymediaPlugin: _mymediaPlugin,
                      showWaveform: true,
                      showSpectrum: true,
                    ),
                  ),

                  // PCM Data tab
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: PcmVisualizer(mymediaPlugin: _mymediaPlugin),
                  ),
                ],
              ),
            ),

            // Now playing mini player
            if (state.isPlaying) NowPlayingMini(controller: audioController),
          ],
        ),
      ),
    );
  }
}
