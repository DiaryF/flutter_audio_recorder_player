# Flutter Audio Recorder Player

A Flutter plugin for audio streaming and playback with advanced features like PCM data access, visualization, and background playback.

## Features

- Stream audio from URLs
- Play local audio files
- Background playback with notification controls
- Audio focus handling
- Playlist support
- PCM data access for custom audio processing
- Audio visualization data
- Record audio to WAV files
- Manage audio sessions

## Getting Started

### Installation

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_audio_recorder_player: ^0.1.0
```

### Basic Usage

```dart
import 'package:flutter_audio_recorder_player/flutter_audio_recorder_player.dart';

// Create an audio player
final player = AudioPlayer();

// Play a stream
await player.setAudioSource(UrlAudioSource(
  url: 'https://example.com/stream.mp3',
  title: 'My Stream',
  artist: 'Artist Name',
));
await player.play();

// Control playback
await player.pause();
await player.play();
await player.stop();

// Set volume
await player.setVolume(0.5);

// Seek to position
await player.seek(Duration(seconds: 30));

// Dispose when done
player.dispose();
```

### Audio Sources

The plugin supports different types of audio sources:

```dart
// URL source
final urlSource = UrlAudioSource(
  url: 'https://example.com/audio.mp3',
  title: 'Audio Title',
  artist: 'Artist Name',
  album: 'Album Name',
);

// File source
final fileSource = FileAudioSource(
  file: File('/path/to/audio.mp3'),
  title: 'Audio Title',
  artist: 'Artist Name',
);

// Asset source
final assetSource = AssetAudioSource(
  assetPath: 'assets/audio.mp3',
  title: 'Audio Title',
);

// Playlist (concatenating source)
final playlist = ConcatenatingAudioSource(
  children: [urlSource, fileSource, assetSource],
);
```

### Playlist Navigation

```dart
// Set a playlist
await player.setAudioSource(playlist);

// Navigate the playlist
await player.seekToNext();
await player.seekToPrevious();
await player.seekToIndex(2);
```

### Audio Session Configuration

```dart
// Configure the audio session
final session = await AudioSession.instance();
await session.configure(AudioSessionConfiguration.music());
await session.setActive(true);
```

### Background Playback

The plugin supports background playback with notification controls. The notification will show the current audio title, artist, and album, and provide controls for play, pause, stop, next, and previous.

### PCM Data Access

```dart
// Get PCM data for custom audio processing
player.getPcmDataStream().listen((pcmData) {
  // Process PCM data
  final samples = pcmData.samples;
  final sampleRate = pcmData.sampleRate;
  final channels = pcmData.channels;

  // Do something with the PCM data
});
```

### Audio Visualization

```dart
// Get visualization data for creating audio visualizations
player.getVisualizationDataStream().listen((visualizationData) {
  // Use the visualization data
  final waveform = visualizationData.waveform;
  final fft = visualizationData.fft;

  // Update your visualization UI
});
```

### Recording

```dart
// Start recording
await player.startRecording(
  sampleRate: 44100,
  channels: 2,
  bitDepth: 16,
  title: 'My Recording',
);

// Stop recording and save to file
await player.stopRecording('/path/to/recording.wav');

// Get all recordings
final recordings = await player.getRecordings();
```

## Platform Support

- Android
- iOS (coming soon)

## License

This project is licensed under the MIT License - see the LICENSE file for details.
