import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mymedia/mymedia_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelMymedia platform = MethodChannelMymedia();
  const MethodChannel channel = MethodChannel('com.example.mymedia/methods');

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
