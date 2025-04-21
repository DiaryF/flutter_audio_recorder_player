import 'package:flutter/material.dart';
import 'package:flutter_audio_recorder_player/flutter_audio_recorder_player.dart';
import 'package:provider/provider.dart';
import '../controllers/recordings_controller.dart';
import '../models/recording.dart';

class AudioEditingScreen extends StatefulWidget {
  const AudioEditingScreen({super.key});

  @override
  State<AudioEditingScreen> createState() => _AudioEditingScreenState();
}

class _AudioEditingScreenState extends State<AudioEditingScreen>
    with SingleTickerProviderStateMixin {
  final player = FlutterAudioRecorderPlayer();
  List<AudioRecording> recordings = [];
  bool isLoading = true;
  String? selectedFilePath;
  bool isPlaying = false;
  int currentPosition = 0;
  int duration = 0;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadRecordings();
  }

  @override
  void dispose() {
    player.stopPlayback();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRecordings() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Get recordings from the RecordingsController
      final recordingsController = Provider.of<RecordingsController>(
        context,
        listen: false,
      );

      // Refresh recordings first
      await recordingsController.refreshRecordings();

      // Convert Recording objects to AudioRecording objects
      final appRecordings = recordingsController.recordings;
      final convertedRecordings =
          appRecordings
              .map(
                (recording) => AudioRecording(
                  id: recording.file.path,
                  filePath: recording.file.path,
                  title: recording.name,
                  sampleRate:
                      44100, // Default values since we don't have this info
                  channels: 2,
                  bitDepth: 16,
                  durationMs:
                      recording.duration > 0
                          ? recording.duration
                          : 0, // Ensure duration is valid
                  timestamp: recording.dateTime.millisecondsSinceEpoch,
                ),
              )
              .toList();

      setState(() {
        recordings = convertedRecordings;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Error loading recordings: $e')),
        );
      }
    }
  }

  Future<void> _playRecording(String filePath) async {
    if (isPlaying) {
      await player.stopPlayback();
      setState(() {
        isPlaying = false;
        selectedFilePath = null;
      });
      return;
    }

    try {
      final success = await player.startPlayback(filePath);
      if (success) {
        setState(() {
          isPlaying = true;
          selectedFilePath = filePath;
        });

        // Start position update timer
        _updatePosition();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error playing recording: $e')));
      }
    }
  }

  Future<void> _updatePosition() async {
    if (!mounted || !isPlaying) return;

    try {
      final position = await player.getPosition();
      final totalDuration = await player.getDuration();

      setState(() {
        currentPosition = position;
        duration = totalDuration;
      });

      if (position >= totalDuration) {
        setState(() {
          isPlaying = false;
          selectedFilePath = null;
        });
      } else {
        Future.delayed(const Duration(milliseconds: 100), _updatePosition);
      }
    } catch (e) {
      // Ignore errors during position update
    }
  }

  void _showTrimmer(AudioRecording recording) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: AudioTrimmer(
              filePath: recording.filePath,
              onTrimComplete: (outputPath) async {
                Navigator.pop(context);

                // Add the trimmed file to recordings
                final title = 'Trimmed ${recording.title}';

                // Get scaffold messenger before async gap
                final scaffoldMessenger = ScaffoldMessenger.of(context);

                // Get the recordings controller
                final recordingsController = Provider.of<RecordingsController>(
                  context,
                  listen: false,
                );

                // Refresh recordings to include the new file
                await recordingsController.refreshRecordings();

                // Now refresh our local list
                await _loadRecordings();

                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('Trimmed file saved: $title')),
                  );
                }
              },
              onCancel: () {
                Navigator.pop(context);
              },
            ),
          ),
    );
  }

  void _showJoiner() {
    if (recordings.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You need at least 2 recordings to join files'),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: AudioJoiner(
              recordings: recordings,
              onJoinComplete: (outputPath) async {
                Navigator.pop(context);

                // Add the joined file to recordings
                final title =
                    'Joined Recording ${DateTime.now().millisecondsSinceEpoch}';

                // Get scaffold messenger before async gap
                final scaffoldMessenger = ScaffoldMessenger.of(context);

                // Get the recordings controller
                final recordingsController = Provider.of<RecordingsController>(
                  context,
                  listen: false,
                );

                // Refresh recordings to include the new file
                await recordingsController.refreshRecordings();

                // Now refresh our local list
                await _loadRecordings();

                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('Joined file saved: $title')),
                  );
                }
              },
              onCancel: () {
                Navigator.pop(context);
              },
            ),
          ),
    );
  }

  void _showWaveformViewer(AudioRecording recording) {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Waveform: ${recording.title}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              SizedBox(
                height: 200,
                child: WaveformView(
                  filePath: recording.filePath,
                  samplesCount: 200,
                  currentPositionMs:
                      selectedFilePath == recording.filePath
                          ? currentPosition
                          : null,
                  durationMs:
                      recording.durationMs > 0 ? recording.durationMs : 0,
                  onPositionTapped: (positionMs) async {
                    if (selectedFilePath == recording.filePath && isPlaying) {
                      await player.seekTo(positionMs);
                      setState(() {
                        currentPosition = positionMs;
                      });
                    }
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () => _playRecording(recording.filePath),
                      child: Icon(
                        selectedFilePath == recording.filePath && isPlaying
                            ? Icons.stop
                            : Icons.play_arrow,
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Editing'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Recordings'),
            Tab(text: 'Trim'),
            Tab(text: 'Join'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Recordings Tab
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : recordings.isEmpty
              ? const Center(child: Text('No recordings found'))
              : ListView.builder(
                itemCount: recordings.length,
                itemBuilder: (context, index) {
                  final recording = recordings[index];
                  final isSelected = selectedFilePath == recording.filePath;

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(recording.title),
                          subtitle: Text(recording.formattedDuration),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  isSelected && isPlaying
                                      ? Icons.stop
                                      : Icons.play_arrow,
                                ),
                                onPressed:
                                    () => _playRecording(recording.filePath),
                              ),
                              IconButton(
                                icon: const Icon(Icons.waves),
                                onPressed: () => _showWaveformViewer(recording),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
                            child: LinearProgressIndicator(
                              value:
                                  duration > 0
                                      ? (currentPosition / duration).clamp(
                                        0.0,
                                        1.0,
                                      )
                                      : 0,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),

          // Trim Tab
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : recordings.isEmpty
              ? const Center(child: Text('No recordings found'))
              : ListView.builder(
                itemCount: recordings.length,
                itemBuilder: (context, index) {
                  final recording = recordings[index];

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: ListTile(
                      title: Text(recording.title),
                      subtitle: Text(recording.formattedDuration),
                      trailing: ElevatedButton(
                        onPressed: () => _showTrimmer(recording),
                        child: const Text('Trim'),
                      ),
                    ),
                  );
                },
              ),

          // Join Tab
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : recordings.length < 2
              ? const Center(
                child: Text('You need at least 2 recordings to join files'),
              )
              : Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: recordings.length,
                      itemBuilder: (context, index) {
                        final recording = recordings[index];

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
                          child: ListTile(
                            title: Text(recording.title),
                            subtitle: Text(recording.formattedDuration),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton(
                      onPressed: _showJoiner,
                      child: const Text('Join Files'),
                    ),
                  ),
                ],
              ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadRecordings,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
