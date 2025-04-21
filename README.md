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
- Join multiple WAV files with compatible formats
- Manage audio sessions

## Getting Started

### Installation

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_audio_recorder_player: ^0.1.0
  permission_handler: ^11.0.0  # For handling runtime permissions
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

### Joining Audio Files

The plugin allows you to join multiple WAV files with compatible audio formats (same sample rate, channels, and bit depth). The UI provides visual indicators to help users identify which files can be joined together:

```dart
// Get all recordings
final recordings = await player.getRecordings();

// Select recordings to join
final selectedRecordings = [recordings[0], recordings[1]];

// Join the recordings
final joinedFile = await player.joinWavFiles(
  recordings: selectedRecordings,
  outputPath: '/path/to/joined_recording.wav',
  title: 'Joined Recording',
);

// Play the joined file
await player.setAudioSource(FileAudioSource(
  file: joinedFile,
  title: 'Joined Recording',
));
await player.play();
```

> **Note:** The plugin automatically checks for format compatibility when joining files. If the selected files have different formats (sample rate, channels, or bit depth), the operation will fail with an appropriate error message.

## Required Permissions

### Android

Add the following permissions to your `AndroidManifest.xml` file:

```xml
<!-- Basic permissions -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />

<!-- Storage permissions for all Android versions -->
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />

<!-- For Android 11+ (API 30+) -->
<uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE"
                 tools:ignore="ScopedStorage" />

<!-- For background playback -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />
```

For Android 10+ (API 29+), add these attributes to your application tag:

```xml
android:requestLegacyExternalStorage="true"
android:preserveLegacyExternalStorage="true"
```

### Runtime Permissions

You also need to request runtime permissions in your Flutter app. You can use the [permission_handler](https://pub.dev/packages/permission_handler) package:

```dart
import 'package:permission_handler/permission_handler.dart';

Future<bool> requestPermissions() async {
  // Request storage permissions
  Map<Permission, PermissionStatus> statuses = await [
    Permission.storage,
    Permission.microphone,
  ].request();

  return statuses[Permission.storage]!.isGranted &&
         statuses[Permission.microphone]!.isGranted;
}

// Call this before initializing the audio player
await requestPermissions();
```

## Platform Support

- Android
- iOS (coming soon)

## License

This project is licensed under the MIT License - see the LICENSE file for details.
