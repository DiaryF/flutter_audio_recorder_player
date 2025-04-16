import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mymedia/mymedia.dart';
import 'package:mymedia/mymedia_platform_interface.dart';
import 'package:mymedia/mymedia_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockMymediaPlatform
    with MockPlatformInterfaceMixin
    implements MymediaPlatform {
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
  final MymediaPlatform initialPlatform = MymediaPlatform.instance;

  test('$MethodChannelMymedia is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelMymedia>());
  });

  test('getPlatformVersion', () async {
    Mymedia mymediaPlugin = Mymedia();
    MockMymediaPlatform fakePlatform = MockMymediaPlatform();
    MymediaPlatform.instance = fakePlatform;

    expect(await mymediaPlugin.getPlatformVersion(), '42');
  });

  test('startPlayback', () async {
    Mymedia mymediaPlugin = Mymedia();
    MockMymediaPlatform fakePlatform = MockMymediaPlatform();
    MymediaPlatform.instance = fakePlatform;

    expect(
      await mymediaPlugin.startPlayback('https://example.com/stream'),
      true,
    );
  });

  test('isPlaying', () async {
    Mymedia mymediaPlugin = Mymedia();
    MockMymediaPlatform fakePlatform = MockMymediaPlatform();
    MymediaPlatform.instance = fakePlatform;

    expect(await mymediaPlugin.isPlaying(), false);
  });
}
