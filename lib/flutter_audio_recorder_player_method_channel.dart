import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_audio_recorder_player_platform_interface.dart';
import 'visualization_data.dart';
import 'pcm_data.dart';
import 'recording.dart';
import 'playback_state.dart';

/// An implementation of [FlutterAudioRecorderPlayerPlatform] that uses method channels.
class MethodChannelFlutterAudioRecorderPlayer
    extends FlutterAudioRecorderPlayerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel(
    'com.it7.flutter_audio_recorder_player/methods',
  );

  /// The event channel used to receive visualization data.
  @visibleForTesting
  final eventChannel = const EventChannel(
    'com.it7.flutter_audio_recorder_player/events',
  );

  /// Stream controller for visualization data.
  final _visualizationDataController =
      StreamController<VisualizationData>.broadcast();

  /// Stream controller for PCM data.
  final _pcmDataController = StreamController<PcmData>.broadcast();

  /// Stream controller for playback state updates.
  final _playbackStateController = StreamController<PlaybackState>.broadcast();

  /// Constructor that sets up the event channel listener.
  MethodChannelFlutterAudioRecorderPlayer() {
    eventChannel.receiveBroadcastStream().listen(_onVisualizationData);
  }

  /// Handles data events from the platform.
  void _onVisualizationData(dynamic event) {
    if (event is Map<dynamic, dynamic>) {
      final type = event['type'] as String?;

      if (type == 'visualization') {
        final visualizationData = VisualizationData.fromMap(event);
        _visualizationDataController.add(visualizationData);
      } else if (type == 'pcm') {
        try {
          final pcmData = PcmData.fromMap(event);
          _pcmDataController.add(pcmData);
        } catch (e) {
          debugPrint('Error parsing PCM data: $e');
        }
      } else if (type == 'playbackState') {
        try {
          final playbackState = PlaybackState.fromMap(event);
          _playbackStateController.add(playbackState);
        } catch (e) {
          debugPrint('Error parsing playback state: $e');
        }
      }
    }
  }

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }

  @override
  Future<bool> startPlayback(String url) async {
    final result = await methodChannel.invokeMethod<bool>('startPlayback', {
      'url': url,
    });
    return result ?? false;
  }

  @override
  Future<void> stopPlayback() async {
    await methodChannel.invokeMethod<void>('stopPlayback');
  }

  @override
  Future<bool> isPlaying() async {
    final result = await methodChannel.invokeMethod<bool>('isPlaying');
    return result ?? false;
  }

  @override
  Future<void> pausePlayback() async {
    await methodChannel.invokeMethod<void>('pausePlayback');
  }

  @override
  Future<void> resumePlayback() async {
    await methodChannel.invokeMethod<void>('resumePlayback');
  }

  @override
  Future<int> getPosition() async {
    final result = await methodChannel.invokeMethod<int>('getPosition');
    return result ?? 0;
  }

  @override
  Future<int> getDuration() async {
    final result = await methodChannel.invokeMethod<int>('getDuration');
    return result ?? 0;
  }

  @override
  Future<void> seekTo(int position) async {
    await methodChannel.invokeMethod<void>('seekTo', {'position': position});
  }

  @override
  Future<void> setVolume(double volume) async {
    await methodChannel.invokeMethod<void>('setVolume', {'volume': volume});
  }

  @override
  Future<void> setSpeed(double speed) async {
    await methodChannel.invokeMethod<void>('setSpeed', {'speed': speed});
  }

  @override
  Future<bool> savePcmAsWav(String filePath) async {
    final result = await methodChannel.invokeMethod<bool>('savePcmAsWav', {
      'filePath': filePath,
    });
    return result ?? false;
  }

  @override
  Future<bool> startRecording({
    int? sampleRate,
    int? channels,
    int? bitDepth,
    String? title,
  }) async {
    final result = await methodChannel.invokeMethod<bool>('startRecording', {
      if (sampleRate != null) 'sampleRate': sampleRate,
      if (channels != null) 'channels': channels,
      if (bitDepth != null) 'bitDepth': bitDepth,
      if (title != null) 'title': title,
    });
    return result ?? false;
  }

  @override
  Future<bool> stopRecording(String filePath) async {
    final result = await methodChannel.invokeMethod<bool>('stopRecording', {
      'filePath': filePath,
    });
    return result ?? false;
  }

  @override
  Future<bool> cancelRecording() async {
    final result = await methodChannel.invokeMethod<bool>('cancelRecording');
    return result ?? false;
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

  @override
  Future<List<AudioRecording>> getRecordings() async {
    final jsonString = await methodChannel.invokeMethod<String>(
      'getRecordings',
    );
    if (jsonString == null) return [];

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((json) => AudioRecording.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error parsing recordings: $e');
      return [];
    }
  }

  @override
  Future<bool> updateRecordingTitle(String id, String title) async {
    final result = await methodChannel.invokeMethod<bool>(
      'updateRecordingTitle',
      {'id': id, 'title': title},
    );
    return result ?? false;
  }

  @override
  Future<bool> deleteRecording(String id) async {
    final result = await methodChannel.invokeMethod<bool>('deleteRecording', {
      'id': id,
    });
    return result ?? false;
  }

  @override
  Future<String> generateWaveformData(String filePath, int samplesCount) async {
    final result = await methodChannel.invokeMethod<String>(
      'generateWaveformData',
      {'filePath': filePath, 'samplesCount': samplesCount},
    );
    return result ?? '';
  }

  @override
  Future<Map<dynamic, dynamic>> parseWavHeader(String filePath) async {
    final result = await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
      'parseWavHeader',
      {'filePath': filePath},
    );
    return result ?? {};
  }

  @override
  Future<bool> trimWavFile(
    String inputPath,
    String outputPath,
    int startMs,
    int endMs,
  ) async {
    final result = await methodChannel.invokeMethod<bool>('trimWavFile', {
      'inputPath': inputPath,
      'outputPath': outputPath,
      'startMs': startMs,
      'endMs': endMs,
    });
    return result ?? false;
  }

  @override
  Future<bool> joinWavFiles(List<String> inputPaths, String outputPath) async {
    final result = await methodChannel.invokeMethod<bool>('joinWavFiles', {
      'inputPaths': inputPaths,
      'outputPath': outputPath,
    });
    return result ?? false;
  }
}
