import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../controllers/audio_controller.dart';
import '../widgets/now_playing_mini.dart';

/// Screen for demonstrating background playback
class BackgroundPlaybackScreen extends StatefulWidget {
  /// Creates a new BackgroundPlaybackScreen
  const BackgroundPlaybackScreen({super.key});

  @override
  State<BackgroundPlaybackScreen> createState() =>
      _BackgroundPlaybackScreenState();
}

class _BackgroundPlaybackScreenState extends State<BackgroundPlaybackScreen> {
  bool _isSessionActive = false;
  int _focusStrategy =
      0; // 0 = gain and pause others, 1 = gain and duck others, 2 = no focus
  bool _pauseWhenDucked = false;
  int _contentType =
      0; // 0 = music, 1 = speech, 2 = movie, 3 = sonification, 4 = game, 5 = voice call

  @override
  void initState() {
    super.initState();
    _initAudioSession();
  }

  Future<void> _initAudioSession() async {
    try {
      // Initialize the audio session
      // This is just a placeholder since we don't have a direct method
      // The actual initialization happens when configuring
      setState(() {
        _isSessionActive = true;
      });
    } catch (e) {
      debugPrint('Error initializing audio session: $e');
    }
  }

  Future<void> _configureAudioSession() async {
    try {
      // Configure the audio session using the platform channel directly
      const methodChannel = MethodChannel('com.example.mymedia/methods');
      await methodChannel.invokeMethod('configure', {
        'contentType': _contentType,
        'focusStrategy': _focusStrategy,
        'pauseWhenDucked': _pauseWhenDucked,
      });

      setState(() {
        _isSessionActive = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Audio session configured'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error configuring audio session: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final audioController = Provider.of<AudioController>(context);
    final state = audioController.state;

    return Scaffold(
      appBar: AppBar(title: const Text('Background Playback')),
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
                    'Background Playback Demo',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This screen demonstrates background playback with notification controls. '
                    'Start playback, then press the home button or switch to another app. '
                    'The audio will continue playing, and you can control it from the notification.',
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
                    // Audio Session Configuration
                    Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Audio Session Configuration',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 16),

                            // Content Type
                            DropdownButtonFormField<int>(
                              decoration: const InputDecoration(
                                labelText: 'Content Type',
                                border: OutlineInputBorder(),
                              ),
                              value: _contentType,
                              items: const [
                                DropdownMenuItem<int>(
                                  value: 0,
                                  child: Text('Music'),
                                ),
                                DropdownMenuItem<int>(
                                  value: 1,
                                  child: Text('Speech'),
                                ),
                                DropdownMenuItem<int>(
                                  value: 2,
                                  child: Text('Movie'),
                                ),
                                DropdownMenuItem<int>(
                                  value: 3,
                                  child: Text('Sonification'),
                                ),
                                DropdownMenuItem<int>(
                                  value: 4,
                                  child: Text('Game'),
                                ),
                                DropdownMenuItem<int>(
                                  value: 5,
                                  child: Text('Voice Call'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _contentType = value;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 16),

                            // Focus Strategy
                            DropdownButtonFormField<int>(
                              decoration: const InputDecoration(
                                labelText: 'Focus Strategy',
                                border: OutlineInputBorder(),
                              ),
                              value: _focusStrategy,
                              items: const [
                                DropdownMenuItem<int>(
                                  value: 0,
                                  child: Text('Gain and Pause Others'),
                                ),
                                DropdownMenuItem<int>(
                                  value: 1,
                                  child: Text('Gain and Duck Others'),
                                ),
                                DropdownMenuItem<int>(
                                  value: 2,
                                  child: Text('No Focus'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _focusStrategy = value;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 16),

                            // Pause When Ducked
                            SwitchListTile(
                              title: const Text('Pause When Ducked'),
                              subtitle: const Text(
                                'Pause playback when audio is ducked instead of lowering volume',
                              ),
                              value: _pauseWhenDucked,
                              onChanged: (value) {
                                setState(() {
                                  _pauseWhenDucked = value;
                                });
                              },
                            ),
                            const SizedBox(height: 16),

                            // Apply Button
                            Center(
                              child: ElevatedButton.icon(
                                onPressed: _configureAudioSession,
                                icon: const Icon(Icons.settings),
                                label: const Text('Apply Configuration'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Playback Status
                    Card(
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

                            // Session status
                            ListTile(
                              leading: Icon(
                                _isSessionActive
                                    ? Icons.check_circle
                                    : Icons.error,
                                color:
                                    _isSessionActive
                                        ? Colors.green
                                        : Colors.red,
                              ),
                              title: Text(
                                'Audio Session: ${_isSessionActive ? 'Active' : 'Inactive'}',
                              ),
                              subtitle: const Text(
                                'Required for background playback',
                              ),
                            ),

                            // Instructions
                            if (state.isPlaying)
                              Container(
                                padding: const EdgeInsets.all(16),
                                color: theme.colorScheme.primaryContainer
                                    .withAlpha(76),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Background Playback Active',
                                      style: theme.textTheme.titleSmall,
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      '1. Press the home button or switch apps\n'
                                      '2. Check the notification area\n'
                                      '3. Use the notification controls to control playback',
                                    ),
                                  ],
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.all(16),
                                color: theme.colorScheme.errorContainer
                                    .withAlpha(76),
                                child: const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Start playback first',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Go back to the home screen and start playing a stream or file',
                                    ),
                                  ],
                                ),
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
}
