import 'package:flutter/material.dart';
import 'package:mymedia/mymedia.dart';
import 'package:provider/provider.dart';
import '../controllers/audio_controller.dart';
import '../models/audio_player_state.dart';
import '../widgets/now_playing_card.dart';
import '../widgets/now_playing_mini.dart';
import '../widgets/stream_list.dart';
import '../widgets/audio_recorder_widget.dart';

/// The main screen of the application
class HomeScreen extends StatefulWidget {
  /// The platform version
  final String platformVersion;

  /// Creates a new HomeScreen
  const HomeScreen({super.key, required this.platformVersion});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final Mymedia _mymediaPlugin = Mymedia();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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

    // Debug print the state
    debugPrint(
      'HomeScreen build: isPlaying=${state.isPlaying}, isPaused=${state.isPaused}, title=${state.currentTitle}',
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Player'),
        centerTitle: true,
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onPrimaryContainer,
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.onPrimaryContainer,
          unselectedLabelColor: theme.colorScheme.onSurface.withAlpha(
            179,
          ), // 0.7 * 255 = 179
          indicatorColor: theme.colorScheme.onPrimaryContainer,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
          tabs: [
            const Tab(text: 'Streams', icon: Icon(Icons.radio)),
            const Tab(text: 'Files', icon: Icon(Icons.folder_open)),
            const Tab(text: 'Recordings', icon: Icon(Icons.mic)),
          ],
          // Add decoration to match the NowPlayingCard style
          indicator: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.onPrimaryContainer,
                width: 3,
              ),
            ),
          ),
          // Add padding for better appearance
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Platform version in a subtle info bar
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
              color: theme.colorScheme.surface,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 14,
                    color: theme.colorScheme.onSurface.withAlpha(153),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Running on: ${widget.platformVersion}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(153),
                    ),
                  ),
                ],
              ),
            ),

            // Main content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Streams Tab
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Current playback info
                        if ((state.isPlaying || state.isPaused) &&
                            state.sourceType == AudioSourceType.stream)
                          NowPlayingCard(
                            controller: audioController,
                            state: state,
                          )
                        else
                          Card(
                            margin: const EdgeInsets.symmetric(vertical: 16.0),
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.radio,
                                    size: 64,
                                    color: theme.colorScheme.primary.withAlpha(
                                      150,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    'Select a stream to start playback',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Stream selection
                        StreamList(controller: audioController, state: state),
                      ],
                    ),
                  ),

                  // Files Tab
                  InkWell(
                    onTap: () => Navigator.pushNamed(context, '/local_files'),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.folder_open,
                            size: 64,
                            color: theme.colorScheme.primary.withAlpha(150),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Browse Local Files',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed:
                                () => Navigator.pushNamed(
                                  context,
                                  '/local_files',
                                ),
                            icon: const Icon(Icons.folder_open),
                            label: const Text('Open File Browser'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Recordings Tab
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Audio recorder widget
                        AudioRecorderWidget(
                          mymediaPlugin: _mymediaPlugin,
                          isPlaying: state.isPlaying,
                        ),

                        const SizedBox(height: 24),

                        // Recordings list button
                        Center(
                          child: ElevatedButton.icon(
                            onPressed:
                                () =>
                                    Navigator.pushNamed(context, '/recordings'),
                            icon: const Icon(Icons.list),
                            label: const Text('View All Recordings'),
                          ),
                        ),
                      ],
                    ),
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
