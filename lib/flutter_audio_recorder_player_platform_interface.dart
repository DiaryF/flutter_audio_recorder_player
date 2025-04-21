import 'dart:async';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_audio_recorder_player_method_channel.dart';
import 'visualization_data.dart';
import 'pcm_data.dart';
import 'recording.dart';
import 'playback_state.dart';

abstract class FlutterAudioRecorderPlayerPlatform extends PlatformInterface {
  /// Constructs a FlutterAudioRecorderPlayerPlatform.
  FlutterAudioRecorderPlayerPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterAudioRecorderPlayerPlatform _instance =
      MethodChannelFlutterAudioRecorderPlayer();

  /// The default instance of [FlutterAudioRecorderPlayerPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterAudioRecorderPlayer].
  static FlutterAudioRecorderPlayerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterAudioRecorderPlayerPlatform] when
  /// they register themselves.
  static set instance(FlutterAudioRecorderPlayerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Returns the current platform version.
  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  /// Starts playback of the audio stream from the given URL.
  Future<bool> startPlayback(String url) {
    throw UnimplementedError('startPlayback() has not been implemented.');
  }

  /// Stops the current playback.
  Future<void> stopPlayback() {
    throw UnimplementedError('stopPlayback() has not been implemented.');
  }

  /// Returns whether audio is currently playing.
  Future<bool> isPlaying() {
    throw UnimplementedError('isPlaying() has not been implemented.');
  }

  /// Pauses the current playback.
  Future<void> pausePlayback() {
    throw UnimplementedError('pausePlayback() has not been implemented.');
  }

  /// Resumes the current playback.
  Future<void> resumePlayback() {
    throw UnimplementedError('resumePlayback() has not been implemented.');
  }

  /// Gets the current playback position in milliseconds.
  Future<int> getPosition() {
    throw UnimplementedError('getPosition() has not been implemented.');
  }

  /// Gets the duration of the current audio in milliseconds.
  Future<int> getDuration() {
    throw UnimplementedError('getDuration() has not been implemented.');
  }

  /// Seeks to the specified position in milliseconds.
  Future<void> seekTo(int position) {
    throw UnimplementedError('seekTo() has not been implemented.');
  }

  /// Sets the volume (0.0 to 1.0).
  Future<void> setVolume(double volume) {
    throw UnimplementedError('setVolume() has not been implemented.');
  }

  /// Sets the playback speed (0.5 to 2.0).
  Future<void> setSpeed(double speed) {
    throw UnimplementedError('setSpeed() has not been implemented.');
  }

  /// Saves the current PCM buffer as a WAV file.
  Future<bool> savePcmAsWav(String filePath) {
    throw UnimplementedError('savePcmAsWav() has not been implemented.');
  }

  /// Starts recording the audio that's currently playing.
  ///
  /// Optional parameters:
  /// - [sampleRate]: Sample rate in Hz (default: 44100)
  /// - [channels]: Number of audio channels (default: 2)
  /// - [bitDepth]: Bit depth (default: 16)
  /// - [title]: Optional title for the recording
  Future<bool> startRecording({
    int? sampleRate,
    int? channels,
    int? bitDepth,
    String? title,
  }) {
    throw UnimplementedError('startRecording() has not been implemented.');
  }

  /// Stops recording and saves the recorded audio as a WAV file.
  Future<bool> stopRecording(String filePath) {
    throw UnimplementedError('stopRecording() has not been implemented.');
  }

  /// Cancels the current recording without saving.
  Future<bool> cancelRecording() {
    throw UnimplementedError('cancelRecording() has not been implemented.');
  }

  /// Returns a stream of visualization data.
  Stream<VisualizationData> getVisualizationDataStream() {
    throw UnimplementedError(
      'getVisualizationDataStream() has not been implemented.',
    );
  }

  /// Returns a stream of PCM audio data.
  Stream<PcmData> getPcmDataStream() {
    throw UnimplementedError('getPcmDataStream() has not been implemented.');
  }

  /// Returns a stream of playback state updates.
  Stream<PlaybackState> getPlaybackStateStream() {
    throw UnimplementedError(
      'getPlaybackStateStream() has not been implemented.',
    );
  }

  /// Gets all recordings as a list of AudioRecording objects.
  Future<List<AudioRecording>> getRecordings() {
    throw UnimplementedError('getRecordings() has not been implemented.');
  }

  /// Updates the title of a recording.
  Future<bool> updateRecordingTitle(String id, String title) {
    throw UnimplementedError(
      'updateRecordingTitle() has not been implemented.',
    );
  }

  /// Deletes a recording.
  Future<bool> deleteRecording(String id) {
    throw UnimplementedError('deleteRecording() has not been implemented.');
  }

  /// Generates waveform data from a WAV file.
  Future<String> generateWaveformData(String filePath, int samplesCount) {
    throw UnimplementedError(
      'generateWaveformData() has not been implemented.',
    );
  }

  /// Parses a WAV file header.
  Future<Map<dynamic, dynamic>> parseWavHeader(String filePath) {
    throw UnimplementedError('parseWavHeader() has not been implemented.');
  }

  /// Trims a WAV file to the specified start and end times.
  Future<bool> trimWavFile(
    String inputPath,
    String outputPath,
    int startMs,
    int endMs,
  ) {
    throw UnimplementedError('trimWavFile() has not been implemented.');
  }

  /// Joins multiple WAV files into a single file.
  Future<bool> joinWavFiles(List<String> inputPaths, String outputPath) {
    throw UnimplementedError('joinWavFiles() has not been implemented.');
  }
}
