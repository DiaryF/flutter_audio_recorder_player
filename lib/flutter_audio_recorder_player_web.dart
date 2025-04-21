import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/foundation.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

import 'flutter_audio_recorder_player_platform_interface.dart';
import 'visualization_data.dart';
import 'pcm_data.dart';
import 'recording.dart';
import 'playback_state.dart';

/// A web implementation of the FlutterAudioRecorderPlayerPlatform.
class FlutterAudioRecorderPlayerWeb extends FlutterAudioRecorderPlayerPlatform {
  /// The HTML audio element used for playback
  html.AudioElement? _audioElement;

  /// Stream controller for visualization data
  final _visualizationDataController =
      StreamController<VisualizationData>.broadcast();

  /// Stream controller for PCM data
  final _pcmDataController = StreamController<PcmData>.broadcast();

  /// Stream controller for playback state
  final _playbackStateController = StreamController<PlaybackState>.broadcast();

  /// Registers this class as the default instance of [FlutterAudioRecorderPlayerPlatform]
  static void registerWith(Registrar registrar) {
    FlutterAudioRecorderPlayerPlatform.instance =
        FlutterAudioRecorderPlayerWeb();
  }

  @override
  Future<String?> getPlatformVersion() async {
    final version = html.window.navigator.userAgent;
    return version;
  }

  @override
  Future<bool> startPlayback(String url) async {
    try {
      // Create a new audio element
      _audioElement = html.AudioElement(url);

      // Set up event listeners
      _setupEventListeners();

      // Start playback
      await _audioElement!.play();

      return true;
    } catch (e) {
      debugPrint('Error starting playback: $e');
      return false;
    }
  }

  /// Sets up event listeners for the audio element
  void _setupEventListeners() {
    final audio = _audioElement;
    if (audio == null) return;

    // Listen for time updates to track position
    audio.onTimeUpdate.listen((_) {
      _updatePlaybackState();
    });

    // Listen for playback state changes
    audio.onPlay.listen((_) {
      _updatePlaybackState();
    });

    audio.onPause.listen((_) {
      _updatePlaybackState();
    });

    audio.onEnded.listen((_) {
      _updatePlaybackState();
    });

    audio.onError.listen((_) {
      _updatePlaybackState();
    });
  }

  /// Updates the playback state and sends it to listeners
  void _updatePlaybackState() {
    final audio = _audioElement;
    if (audio == null) return;

    final state = PlaybackState(
      processingState:
          audio.error != null
              ? ProcessingState.error
              : audio.ended
              ? ProcessingState.completed
              : ProcessingState.ready,
      playing: !audio.paused,
      position: (audio.currentTime * 1000).toInt(),
      duration: (audio.duration.isFinite ? audio.duration * 1000 : 0).toInt(),
      timestamp: DateTime.now().millisecondsSinceEpoch,
      title: audio.src.split('/').last,
      url: audio.src,
    );

    _playbackStateController.add(state);
  }

  @override
  Future<void> stopPlayback() async {
    final audio = _audioElement;
    if (audio != null) {
      audio.pause();
      audio.currentTime = 0;
      _audioElement = null;

      // Update playback state
      _playbackStateController.add(
        PlaybackState(
          processingState: ProcessingState.idle,
          playing: false,
          position: 0,
          duration: 0,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          title: '',
        ),
      );
    }
  }

  @override
  Future<bool> isPlaying() async {
    final audio = _audioElement;
    return audio != null && !audio.paused;
  }

  @override
  Future<void> pausePlayback() async {
    final audio = _audioElement;
    if (audio != null) {
      audio.pause();
      _updatePlaybackState();
    }
  }

  @override
  Future<void> resumePlayback() async {
    final audio = _audioElement;
    if (audio != null) {
      await audio.play();
      _updatePlaybackState();
    }
  }

  @override
  Future<int> getPosition() async {
    final audio = _audioElement;
    if (audio != null) {
      return (audio.currentTime * 1000).toInt();
    }
    return 0;
  }

  @override
  Future<int> getDuration() async {
    final audio = _audioElement;
    if (audio != null && audio.duration.isFinite) {
      return (audio.duration * 1000).toInt();
    }
    return 0;
  }

  @override
  Future<void> seekTo(int position) async {
    final audio = _audioElement;
    if (audio != null) {
      audio.currentTime = position / 1000;
      _updatePlaybackState();
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    final audio = _audioElement;
    if (audio != null) {
      audio.volume = volume;
    }
  }

  @override
  Future<void> setSpeed(double speed) async {
    final audio = _audioElement;
    if (audio != null) {
      audio.playbackRate = speed;
    }
  }

  @override
  Stream<VisualizationData> getVisualizationDataStream() {
    return _visualizationDataController.stream;
  }

  @override
  Stream<PcmData> getPcmDataStream() {
    return _pcmDataController.stream;
  }

  @override
  Stream<PlaybackState> getPlaybackStateStream() {
    return _playbackStateController.stream;
  }

  // The following methods are not supported on web

  @override
  Future<bool> savePcmAsWav(String filePath) async {
    return false;
  }

  @override
  Future<bool> startRecording({
    int? sampleRate,
    int? channels,
    int? bitDepth,
    String? title,
  }) async {
    return false;
  }

  @override
  Future<bool> stopRecording(String filePath) async {
    return false;
  }

  @override
  Future<bool> cancelRecording() async {
    return false;
  }

  @override
  Future<List<AudioRecording>> getRecordings() async {
    return [];
  }

  @override
  Future<bool> updateRecordingTitle(String id, String title) async {
    return false;
  }

  @override
  Future<bool> deleteRecording(String id) async {
    return false;
  }
}
