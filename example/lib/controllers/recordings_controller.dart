import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/recording.dart';
import '../services/audio_service.dart';

/// Controller for managing recordings
class RecordingsController extends ChangeNotifier {
  /// List of recordings
  List<Recording> _recordings = [];

  /// Currently playing recording
  Recording? _currentlyPlaying;

  /// Whether a recording is currently playing
  bool _isPlaying = false;

  /// Get the list of recordings
  List<Recording> get recordings => _recordings;

  /// Get the currently playing recording
  Recording? get currentlyPlaying => _currentlyPlaying;

  /// Whether a recording is currently playing
  bool get isPlaying => _isPlaying;

  /// Audio service
  final AudioService _audioService = AudioService();

  /// Constructor
  RecordingsController() {
    _loadRecordings();

    // Listen for changes in the audio service
    _setupAudioServiceListeners();
  }

  /// Set up listeners for the audio service
  void _setupAudioServiceListeners() {
    // This would be used to listen for changes in the audio service
    // For example, if the audio service had a stream of playback state changes
  }

  /// Load recordings from the recordings directory
  Future<void> _loadRecordings() async {
    try {
      // Get the app-specific directory
      final appDir = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${appDir.path}/recordings/recordings');

      // Check if directory exists
      if (!await recordingsDir.exists()) {
        debugPrint(
          'Recordings directory does not exist: ${recordingsDir.path}',
        );
        await recordingsDir.create(recursive: true);
        notifyListeners();
        return;
      }

      debugPrint('Looking for recordings in: ${recordingsDir.path}');

      // List all WAV files in the recordings directory
      final files =
          recordingsDir
              .listSync()
              .whereType<File>()
              .where((file) => file.path.endsWith('.wav'))
              .toList();

      debugPrint('Found ${files.length} recordings');

      _recordings = files.map((file) => Recording.fromFile(file)).toList();

      // Sort by date (newest first)
      _recordings.sort((a, b) => b.dateTime.compareTo(a.dateTime));

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading recordings: $e');
    }
  }

  /// Refresh the list of recordings
  Future<void> refreshRecordings() async {
    await _loadRecordings();
  }

  /// Add a new recording
  void addRecording(Recording recording) {
    _recordings.add(recording);

    // Sort by date (newest first)
    _recordings.sort((a, b) => b.dateTime.compareTo(a.dateTime));

    notifyListeners();
  }

  /// Delete a recording
  Future<bool> deleteRecording(Recording recording) async {
    try {
      // Delete the file
      await recording.file.delete();

      // Remove from the list
      _recordings.remove(recording);

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting recording: $e');
      return false;
    }
  }

  /// Rename a recording
  void renameRecording(Recording recording, String newName) {
    final index = _recordings.indexOf(recording);
    if (index >= 0) {
      _recordings[index] = recording.copyWith(name: newName);
      notifyListeners();
    }
  }

  /// Set the currently playing recording
  void setCurrentlyPlaying(Recording? recording) {
    _currentlyPlaying = recording;
    _isPlaying = recording != null;
    notifyListeners();
  }

  /// Play a recording
  Future<bool> playRecording(Recording recording) async {
    final success = await _audioService.playRecording(recording);
    if (success) {
      setCurrentlyPlaying(recording);
    }
    return success;
  }

  /// Pause playback
  Future<bool> pausePlayback() async {
    final success = await _audioService.pausePlayback();
    if (success) {
      _isPlaying = true; // Still playing, just paused
      notifyListeners();
    }
    return success;
  }

  /// Resume playback
  Future<bool> resumePlayback() async {
    final success = await _audioService.resumePlayback();
    if (success) {
      _isPlaying = true;
      notifyListeners();
    }
    return success;
  }

  /// Stop playback
  Future<bool> stopPlayback() async {
    final success = await _audioService.stopPlayback();
    if (success) {
      setCurrentlyPlaying(null);
    }
    return success;
  }

  /// Get the audio service
  AudioService get audioService => _audioService;

  /// Update the duration of a recording
  void updateRecordingDuration(Recording recording, int duration) {
    final index = _recordings.indexOf(recording);
    if (index >= 0) {
      _recordings[index] = recording.copyWith(duration: duration);
      notifyListeners();
    }
  }

  /// Share a recording
  Future<void> shareRecording(Recording recording) async {
    try {
      await Share.shareXFiles([
        XFile(recording.file.path),
      ], text: 'Sharing recording: ${recording.name}');
    } catch (e) {
      debugPrint('Error sharing recording: $e');
    }
  }
}
