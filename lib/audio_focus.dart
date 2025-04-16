import 'package:flutter/foundation.dart';
import 'audio_session_manager.dart';

/// Represents the audio focus state
enum AudioFocusState {
  /// No audio focus
  none,
  
  /// Full audio focus
  gain,
  
  /// Transient audio focus (short duration)
  gainTransient,
  
  /// Transient audio focus with duck (other audio streams should lower volume)
  gainTransientMayDuck,
  
  /// Audio focus lost
  loss,
  
  /// Transient audio focus loss (short duration)
  lossTransient,
  
  /// Transient audio focus loss with duck (should lower volume)
  lossTransientDuck,
}

/// Callback for audio focus changes
typedef AudioFocusChangeCallback = void Function(AudioFocusState state);

/// Manages audio focus for the application
class AudioFocusManager {
  /// The current audio focus state
  AudioFocusState _currentState = AudioFocusState.none;
  
  /// The audio session manager
  final AudioSessionManager _sessionManager;
  
  /// The callback to invoke when audio focus changes
  AudioFocusChangeCallback? _onAudioFocusChange;
  
  /// Creates a new audio focus manager
  AudioFocusManager(this._sessionManager) {
    // Listen for interruption events
    _sessionManager.interruptionEventStream.listen(_handleInterruption);
  }
  
  /// Gets the current audio focus state
  AudioFocusState get currentState => _currentState;
  
  /// Sets the callback to invoke when audio focus changes
  set onAudioFocusChange(AudioFocusChangeCallback? callback) {
    _onAudioFocusChange = callback;
  }
  
  /// Requests audio focus
  Future<bool> requestFocus() async {
    final result = await _sessionManager.setActive(true);
    if (result) {
      _updateFocusState(AudioFocusState.gain);
    }
    return result;
  }
  
  /// Abandons audio focus
  Future<bool> abandonFocus() async {
    final result = await _sessionManager.setActive(false);
    if (result) {
      _updateFocusState(AudioFocusState.none);
    }
    return result;
  }
  
  /// Handles interruption events
  void _handleInterruption(InterruptionEvent event) {
    if (event.begin) {
      // Interruption began
      switch (event.type) {
        case InterruptionType.duck:
          _updateFocusState(AudioFocusState.lossTransientDuck);
          break;
        case InterruptionType.pause:
          _updateFocusState(AudioFocusState.lossTransient);
          break;
        case InterruptionType.unknown:
          _updateFocusState(AudioFocusState.loss);
          break;
      }
    } else {
      // Interruption ended
      switch (event.type) {
        case InterruptionType.duck:
          _updateFocusState(AudioFocusState.gain);
          break;
        case InterruptionType.pause:
          _updateFocusState(AudioFocusState.gain);
          break;
        case InterruptionType.unknown:
          // Do nothing
          break;
      }
    }
  }
  
  /// Updates the focus state and notifies the callback
  void _updateFocusState(AudioFocusState state) {
    if (_currentState == state) return;
    
    _currentState = state;
    
    try {
      _onAudioFocusChange?.call(state);
    } catch (e) {
      debugPrint('Error in audio focus change callback: $e');
    }
  }
}
