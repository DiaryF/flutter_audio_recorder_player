import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_audio_recorder_player/flutter_audio_recorder_player_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelFlutterAudioRecorderPlayer platform = MethodChannelFlutterAudioRecorderPlayer();
  const MethodChannel channel = MethodChannel(
    'com.it7.flutter_audio_recorder_player/methods',
  );

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          return '42';
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });

  test('startPlayback', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          if (methodCall.method == 'startPlayback') {
            return true;
          }
          return null;
        });

    expect(await platform.startPlayback('https://example.com/stream'), true);
  });

  test('isPlaying', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          if (methodCall.method == 'isPlaying') {
            return false;
          }
          return null;
        });

    expect(await platform.isPlaying(), false);
  });
}
