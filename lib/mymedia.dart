import 'dart:async';

import 'mymedia_platform_interface.dart';
import 'visualization_data.dart';
import 'pcm_data.dart';
import 'recording.dart';
import 'playback_state.dart';

/// A Flutter plugin for audio streaming and visualization.
class Mymedia {
  /// Returns the current platform version.
  Future<String?> getPlatformVersion() {
    return MymediaPlatform.instance.getPlatformVersion();
  }

  /// Starts playback of the audio stream from the given URL.
  ///
  /// Returns true if playback started successfully, false otherwise.
  Future<bool> startPlayback(String url) {
    return MymediaPlatform.instance.startPlayback(url);
  }

  /// Stops the current playback.
  Future<void> stopPlayback() {
    return MymediaPlatform.instance.stopPlayback();
  }

  /// Returns whether audio is currently playing.
  Future<bool> isPlaying() {
    return MymediaPlatform.instance.isPlaying();
  }

  /// Pauses the current playback.
  Future<void> pausePlayback() {
    return MymediaPlatform.instance.pausePlayback();
  }

  /// Resumes the current playback.
  Future<void> resumePlayback() {
    return MymediaPlatform.instance.resumePlayback();
  }

  /// Gets the current playback position in milliseconds.
  Future<int> getPosition() {
    return MymediaPlatform.instance.getPosition();
  }

  /// Gets the duration of the current audio in milliseconds.
  Future<int> getDuration() {
    return MymediaPlatform.instance.getDuration();
  }

  /// Seeks to the specified position in milliseconds.
  Future<void> seekTo(int position) {
    return MymediaPlatform.instance.seekTo(position);
  }

  /// Sets the volume (0.0 to 1.0).
  Future<void> setVolume(double volume) {
    return MymediaPlatform.instance.setVolume(volume);
  }

  /// Saves the current PCM buffer as a WAV file.
  ///
  /// Returns true if successful, false otherwise.
  Future<bool> savePcmAsWav(String filePath) {
    return MymediaPlatform.instance.savePcmAsWav(filePath);
  }

  /// Starts recording the audio that's currently playing.
  ///
  /// Optional parameters:
  /// - [sampleRate]: Sample rate in Hz (default: 44100)
  /// - [channels]: Number of audio channels (default: 2)
  /// - [bitDepth]: Bit depth (default: 16)
  /// - [title]: Optional title for the recording
  ///
  /// Returns true if recording started successfully, false otherwise.
  Future<bool> startRecording({
    int? sampleRate,
    int? channels,
    int? bitDepth,
    String? title,
  }) {
    return MymediaPlatform.instance.startRecording(
      sampleRate: sampleRate,
      channels: channels,
      bitDepth: bitDepth,
      title: title,
    );
  }

  /// Stops recording and saves the recorded audio as a WAV file.
  ///
  /// Returns true if the recording was saved successfully, false otherwise.
  Future<bool> stopRecording(String filePath) {
    return MymediaPlatform.instance.stopRecording(filePath);
  }

  /// Cancels the current recording without saving.
  ///
  /// Returns true if recording was successfully canceled, false if no recording was in progress.
  Future<bool> cancelRecording() {
    return MymediaPlatform.instance.cancelRecording();
  }

  /// Returns a stream of visualization data.
  ///
  /// This stream emits [VisualizationData] objects containing waveform and
  /// frequency data that can be used to create audio visualizations.
  Stream<VisualizationData> getVisualizationDataStream() {
    return MymediaPlatform.instance.getVisualizationDataStream();
  }

  /// Returns a stream of PCM audio data.
  ///
  /// This stream emits [PcmData] objects containing raw PCM audio samples
  /// that can be used for advanced audio processing or visualization.
  Stream<PcmData> getPcmDataStream() {
    return MymediaPlatform.instance.getPcmDataStream();
  }

  /// Returns a stream of playback state updates.
  ///
  /// This stream emits [PlaybackState] objects containing information about
  /// the current playback state, including state (playing, paused, stopped),
  /// title, position, and duration.
  Stream<PlaybackState> getPlaybackStateStream() {
    return MymediaPlatform.instance.getPlaybackStateStream();
  }

  /// Gets all recordings as a list of Recording objects.
  Future<List<Recording>> getRecordings() {
    return MymediaPlatform.instance.getRecordings();
  }

  /// Updates the title of a recording.
  ///
  /// Returns true if successful, false otherwise.
  Future<bool> updateRecordingTitle(String id, String title) {
    return MymediaPlatform.instance.updateRecordingTitle(id, title);
  }

  /// Deletes a recording.
  ///
  /// Returns true if successful, false otherwise.
  Future<bool> deleteRecording(String id) {
    return MymediaPlatform.instance.deleteRecording(id);
  }
}
