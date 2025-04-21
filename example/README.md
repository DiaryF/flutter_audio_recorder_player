# Flutter Audio Recorder Player Example

This example app demonstrates how to use the flutter_audio_recorder_player plugin with its various features.

## Features Demonstrated

- Audio streaming and playback
- Background playback with notification controls
- Audio focus handling
- PCM data access
- Recording audio to WAV files
- Joining multiple WAV files with compatible formats
- Audio file management

## Screens

### Home Screen

The main screen shows the current playback status and provides navigation to other screens.

### Local Files Screen

Browse and play audio files stored on the device. You can:
- Play/pause/stop audio files
- View file details
- Search for files

### Audio Editing Screen

Edit and manage audio recordings. You can:
- Join multiple WAV files with compatible formats
- View audio format information (sample rate, channels, bit depth)
- Play recordings to preview them

## Implementation Notes

- The app uses a single AudioPlayer instance for all playback
- Background playback is handled through a foreground service
- The app demonstrates proper audio session management
- The UI shows how to implement audio controls and visualizations

## Getting Started

1. Clone the repository
2. Run `flutter pub get`
3. Run the app on an Android device or emulator

```bash
flutter run
```
