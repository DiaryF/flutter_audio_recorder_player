import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/audio_controller.dart';
import '../controllers/local_audio_controller.dart';
import '../models/audio_file.dart';
import '../models/audio_player_state.dart';
import '../widgets/now_playing_mini.dart';

/// Screen for browsing and playing local audio files
class LocalFilesScreen extends StatefulWidget {
  /// Creates a new LocalFilesScreen
  const LocalFilesScreen({super.key});

  @override
  State<LocalFilesScreen> createState() => _LocalFilesScreenState();
}

class _LocalFilesScreenState extends State<LocalFilesScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _showSearchBar = false;
  late LocalAudioController _localAudioController;

  @override
  void initState() {
    super.initState();
    // Get the controller but don't load files immediately
    _localAudioController = Provider.of<LocalAudioController>(
      context,
      listen: false,
    );

    // Use Future.microtask to avoid calling setState during build
    Future.microtask(() => _initializeController());

    // Add listener to search controller
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _localAudioController.searchAudioFiles(_searchController.text);
  }

  Future<void> _initializeController() async {
    await _localAudioController.initialize();
  }

  Future<void> _loadFiles() async {
    await _localAudioController.loadAudioFiles();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final audioController = Provider.of<AudioController>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Audio Files'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFiles,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: Icon(_showSearchBar ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _showSearchBar = !_showSearchBar;
                if (!_showSearchBar) {
                  _searchController.clear();
                  _localAudioController.clearSearch();
                }
              });
            },
            tooltip: _showSearchBar ? 'Close Search' : 'Search',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          if (_showSearchBar)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search audio files...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon:
                      _searchController.text.isNotEmpty
                          ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _localAudioController.clearSearch();
                            },
                          )
                          : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                autofocus: true,
              ),
            ),

          // Main content
          Expanded(
            child: Consumer<LocalAudioController>(
              builder: (context, controller, child) {
                if (controller.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (controller.errorMessage != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading files',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          controller.errorMessage!,
                          style: theme.textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _loadFiles,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try Again'),
                        ),
                      ],
                    ),
                  );
                }

                if (controller.audioFiles.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.audio_file,
                          size: 64,
                          color: theme.colorScheme.primary.withAlpha(150),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No audio files found',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try navigating to a different folder or scanning for audio files',
                          style: theme.textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => controller.scanForAudioFiles(),
                          icon: const Icon(Icons.search),
                          label: const Text('Scan for Audio Files'),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    // Current directory
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      color: theme.colorScheme.surfaceContainerLow,
                      child: Row(
                        children: [
                          Icon(
                            Icons.folder,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              controller.currentDirectory,
                              style: theme.textTheme.bodyMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_upward),
                            onPressed: controller.navigateUp,
                            tooltip: 'Up',
                            iconSize: 20,
                          ),
                        ],
                      ),
                    ),

                    // File list
                    Expanded(
                      child: ListView.builder(
                        itemCount: controller.audioFiles.length,
                        itemBuilder: (context, index) {
                          final file = controller.audioFiles[index];
                          final isCurrentlyPlaying =
                              audioController.state.isPlaying &&
                              audioController.state.sourceType ==
                                  AudioSourceType.file &&
                              audioController.state.currentSource == file.path;

                          return _buildAudioFileItem(
                            context,
                            file,
                            isCurrentlyPlaying,
                            audioController,
                          );
                        },
                      ),
                    ),

                    // Now playing mini player
                    if (audioController.state.isPlaying)
                      NowPlayingMini(controller: audioController),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _localAudioController.scanForAudioFiles(),
        tooltip: 'Scan for Audio Files',
        child: const Icon(Icons.search),
      ),
    );
  }

  Widget _buildAudioFileItem(
    BuildContext context,
    AudioFile file,
    bool isCurrentlyPlaying,
    AudioController audioController,
  ) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color:
          isCurrentlyPlaying
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surface,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor:
              isCurrentlyPlaying
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surfaceContainerHighest,
          child: Icon(
            isCurrentlyPlaying ? Icons.music_note : Icons.audio_file,
            color:
                isCurrentlyPlaying
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.primary,
          ),
        ),
        title: Text(
          file.name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight:
                isCurrentlyPlaying ? FontWeight.bold : FontWeight.normal,
            color:
                isCurrentlyPlaying
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${file.formattedSize} • ${file.formattedDate}',
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
          onPressed: () {
            if (isCurrentlyPlaying) {
              audioController.stopPlayback();
            } else {
              audioController.playAudioFile(file);
            }
          },
        ),
        onTap: () {
          if (isCurrentlyPlaying) {
            audioController.togglePlayPause();
          } else {
            audioController.playAudioFile(file);
          }
        },
      ),
    );
  }
}
