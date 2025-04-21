import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'playback_state.dart';

/// Callback for handling notification actions
typedef NotificationActionCallback = void Function(String action);

/// Service for managing audio playback notifications
class NotificationService {
  /// The platform channel for communication with native code
  static const MethodChannel _channel = MethodChannel(
    'com.it7.flutter_audio_recorder_player/notification',
  );

  /// The event channel for receiving notification actions
  static const EventChannel _eventChannel = EventChannel(
    'com.it7.flutter_audio_recorder_player/notification_events',
  );

  /// Stream controller for notification actions
  final StreamController<String> _actionController =
      StreamController<String>.broadcast();

  /// Callback for handling notification actions
  NotificationActionCallback? _actionCallback;

  /// Whether the service is initialized
  bool _initialized = false;

  /// Whether the platform implementation is available
  bool _platformImplementationAvailable = true;

  /// Creates a new notification service
  NotificationService() {
    // Try to listen for notification actions
    try {
      _eventChannel.receiveBroadcastStream().listen(
        (dynamic event) {
          final action = event as String;
          _actionController.add(action);
          _actionCallback?.call(action);
        },
        onError: (error) {
          if (error is PlatformException || error is MissingPluginException) {
            _platformImplementationAvailable = false;
            debugPrint('Notification service not available on this platform');
          }
        },
      );
    } catch (e) {
      _platformImplementationAvailable = false;
      debugPrint('Notification service not available: $e');
    }
  }

  /// Initializes the notification service
  Future<bool> initialize({
    required String channelId,
    required String channelName,
    String? channelDescription,
    int notificationId = 1,
    String? smallIconName,
  }) async {
    if (_initialized) return true;

    // If platform implementation is not available, return false
    if (!_platformImplementationAvailable) {
      debugPrint('Notification service not available on this platform');
      return false;
    }

    try {
      final result = await _channel.invokeMethod<bool>('initialize', {
        'channelId': channelId,
        'channelName': channelName,
        'channelDescription': channelDescription ?? 'Audio playback controls',
        'notificationId': notificationId,
        'smallIconName': smallIconName ?? 'ic_notification',
      });

      _initialized = result ?? false;
      return _initialized;
    } catch (e) {
      if (e is MissingPluginException) {
        _platformImplementationAvailable = false;
        debugPrint('Notification service not available on this platform');
      } else {
        debugPrint('Error initializing notification service: $e');
      }
      return false;
    }
  }

  /// Shows a playback notification
  Future<bool> showPlaybackNotification({
    required String title,
    String? artist,
    String? album,
    String? artUri,
    required bool isPlaying,
    int position = 0,
    int duration = 0,
    bool showControls = true,
  }) async {
    // If platform implementation is not available or not initialized, return false
    if (!_platformImplementationAvailable || !_initialized) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod<bool>('showNotification', {
        'title': title,
        'artist': artist,
        'album': album,
        'artUri': artUri,
        'isPlaying': isPlaying,
        'position': position,
        'duration': duration,
        'showControls': showControls,
      });

      return result ?? false;
    } catch (e) {
      if (e is MissingPluginException) {
        _platformImplementationAvailable = false;
      }
      return false;
    }
  }

  /// Updates the playback notification with the current state
  Future<bool> updatePlaybackState(PlaybackState state) async {
    // If platform implementation is not available, return false
    if (!_platformImplementationAvailable) {
      return false;
    }

    return showPlaybackNotification(
      title: state.title,
      artist: state.artist,
      album: state.album,
      artUri: state.artUri,
      isPlaying: state.playing,
      position: state.position,
      duration: state.duration,
    );
  }

  /// Hides the playback notification
  Future<bool> hideNotification() async {
    // If platform implementation is not available or not initialized, return false
    if (!_platformImplementationAvailable || !_initialized) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod<bool>('hideNotification');
      return result ?? false;
    } catch (e) {
      if (e is MissingPluginException) {
        _platformImplementationAvailable = false;
      }
      return false;
    }
  }

  /// Sets the callback for handling notification actions
  set onActionReceived(NotificationActionCallback callback) {
    _actionCallback = callback;
  }

  /// Gets the stream of notification actions
  Stream<String> get actionStream => _actionController.stream;

  /// Disposes of resources
  void dispose() {
    _actionController.close();
  }
}
