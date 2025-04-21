import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_audio_recorder_player/flutter_audio_recorder_player.dart';
import 'package:flutter_audio_recorder_player/flutter_audio_recorder_player_platform_interface.dart';
import 'package:flutter_audio_recorder_player/flutter_audio_recorder_player_method_channel.dart';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterAudioRecorderPlayerPlatform
    with MockPlatformInterfaceMixin
    implements FlutterAudioRecorderPlayerPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<bool> startPlayback(String url) => Future.value(true);

  @override
  Future<void> stopPlayback() => Future.value();

  @override
  Future<bool> isPlaying() => Future.value(false);

  @override
  Future<void> pausePlayback() => Future.value();

  @override
  Future<void> resumePlayback() => Future.value();

  @override
  Future<int> getPosition() => Future.value(0);

  @override
  Future<int> getDuration() => Future.value(0);

  @override
  Future<void> seekTo(int position) => Future.value();

  @override
  Future<void> setVolume(double volume) => Future.value();

  @override
  Future<void> setSpeed(double speed) => Future.value();

  @override
  Future<bool> savePcmAsWav(String filePath) => Future.value(true);

  @override
  Future<bool> startRecording({
    int? sampleRate,
    int? channels,
    int? bitDepth,
    String? title,
  }) => Future.value(true);

  @override
  Future<bool> stopRecording(String filePath) => Future.value(true);

  @override
  Future<bool> cancelRecording() => Future.value(true);

  @override
  Stream<VisualizationData> getVisualizationDataStream() {
    return Stream.empty();
  }

  @override
  Stream<PcmData> getPcmDataStream() {
    return Stream.empty();
  }

  @override
  Stream<PlaybackState> getPlaybackStateStream() {
    return Stream.empty();
  }

  @override
  Future<List<AudioRecording>> getRecordings() {
    return Future.value([]);
  }

  @override
  Future<bool> updateRecordingTitle(String id, String title) {
    return Future.value(true);
  }

  @override
  Future<bool> deleteRecording(String id) {
    return Future.value(true);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final FlutterAudioRecorderPlayerPlatform initialPlatform =
      FlutterAudioRecorderPlayerPlatform.instance;

  test('$MethodChannelFlutterAudioRecorderPlayer is the default instance', () {
    expect(
      initialPlatform,
      isInstanceOf<MethodChannelFlutterAudioRecorderPlayer>(),
    );
  });

  test('getPlatformVersion', () async {
    FlutterAudioRecorderPlayer plugin = FlutterAudioRecorderPlayer();
    MockFlutterAudioRecorderPlayerPlatform fakePlatform =
        MockFlutterAudioRecorderPlayerPlatform();
    FlutterAudioRecorderPlayerPlatform.instance = fakePlatform;

    expect(await plugin.getPlatformVersion(), '42');
  });

  test('startPlayback', () async {
    FlutterAudioRecorderPlayer plugin = FlutterAudioRecorderPlayer();
    MockFlutterAudioRecorderPlayerPlatform fakePlatform =
        MockFlutterAudioRecorderPlayerPlatform();
    FlutterAudioRecorderPlayerPlatform.instance = fakePlatform;

    expect(await plugin.startPlayback('https://example.com/stream'), true);
  });

  test('isPlaying', () async {
    FlutterAudioRecorderPlayer plugin = FlutterAudioRecorderPlayer();
    MockFlutterAudioRecorderPlayerPlatform fakePlatform =
        MockFlutterAudioRecorderPlayerPlatform();
    FlutterAudioRecorderPlayerPlatform.instance = fakePlatform;

    expect(await plugin.isPlaying(), false);
  });
}
