import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/recordings_controller.dart';
import '../widgets/recording_player.dart';

/// Screen for displaying and managing recordings
class RecordingsScreen extends StatefulWidget {
  /// Creates a new RecordingsScreen
  const RecordingsScreen({super.key});

  @override
  State<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends State<RecordingsScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh recordings when the screen is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RecordingsController>().refreshRecordings();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recordings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<RecordingsController>().refreshRecordings();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Consumer<RecordingsController>(
        builder: (context, controller, child) {
          if (controller.recordings.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.music_note, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No recordings yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Record audio from the home screen',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }
          
          return RefreshIndicator(
            onRefresh: controller.refreshRecordings,
            child: ListView.builder(
              itemCount: controller.recordings.length,
              itemBuilder: (context, index) {
                final recording = controller.recordings[index];
                return RecordingPlayer(
                  recording: recording,
                  controller: controller,
                  onDeleted: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Recording deleted'),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
