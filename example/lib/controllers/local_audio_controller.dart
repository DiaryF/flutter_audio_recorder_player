import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/audio_file.dart';

/// Controller for managing local audio files
class LocalAudioController extends ChangeNotifier {
  /// List of audio files
  List<AudioFile> _audioFiles = [];

  /// Filtered list of audio files (for search)
  List<AudioFile> _filteredAudioFiles = [];

  /// Current directory being browsed
  String _currentDirectory = '';

  /// Whether files are currently being loaded
  bool _isLoading = false;

  /// Error message, if any
  String? _errorMessage;

  /// Current search query
  String _searchQuery = '';

  /// Get the list of audio files (filtered if search is active)
  List<AudioFile> get audioFiles =>
      _searchQuery.isEmpty ? _audioFiles : _filteredAudioFiles;

  /// Get the current directory
  String get currentDirectory => _currentDirectory;

  /// Whether files are currently being loaded
  bool get isLoading => _isLoading;

  /// Error message, if any
  String? get errorMessage => _errorMessage;

  /// Get the current search query
  String get searchQuery => _searchQuery;

  /// Whether search is active
  bool get isSearchActive => _searchQuery.isNotEmpty;

  /// Constructor
  LocalAudioController();

  /// Initialize the controller
  Future<void> initialize() async {
    await _initializeStorage();
  }

  /// Initialize storage access
  Future<void> _initializeStorage() async {
    try {
      // Request storage permissions
      final status = await Permission.storage.request();
      if (status.isGranted) {
        // Get the external storage directory
        final directory = await getExternalStorageDirectory();
        if (directory != null) {
          _currentDirectory = directory.path;
          await loadAudioFiles();
        } else {
          _errorMessage = 'Could not access external storage';
          notifyListeners();
        }
      } else {
        _errorMessage = 'Storage permission denied';
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Error initializing storage: $e';
      notifyListeners();
    }
  }

  /// Load audio files from the current directory
  Future<void> loadAudioFiles() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final directory = Directory(_currentDirectory);
      if (!await directory.exists()) {
        _errorMessage = 'Directory does not exist: $_currentDirectory';
        _isLoading = false;
        notifyListeners();
        return;
      }

      // List all files and directories in the current directory
      final entities = await directory.list().toList();

      // Filter for audio files and directories
      _audioFiles = [];

      for (final entity in entities) {
        if (entity is File) {
          final audioFile = AudioFile.fromFile(entity);
          if (audioFile.isAudioFile) {
            _audioFiles.add(audioFile);
          }
        }
      }

      // Sort by name
      _audioFiles.sort((a, b) => a.name.compareTo(b.name));

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error loading audio files: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Navigate to a directory
  Future<void> navigateToDirectory(String path) async {
    _currentDirectory = path;
    await loadAudioFiles();
  }

  /// Navigate up one directory
  Future<void> navigateUp() async {
    final directory = Directory(_currentDirectory);
    final parent = directory.parent;
    _currentDirectory = parent.path;
    await loadAudioFiles();
  }

  /// Scan the device for audio files
  Future<void> scanForAudioFiles() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Get the external storage directory
      final externalDir = await getExternalStorageDirectory();
      if (externalDir == null) {
        _errorMessage = 'Could not access external storage';
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Start from the root of external storage
      final rootDir = Directory(externalDir.path);

      // Find all audio files recursively
      final audioFiles = <AudioFile>[];

      await _scanDirectory(rootDir, audioFiles);

      _audioFiles = audioFiles;

      // Sort by name
      _audioFiles.sort((a, b) => a.name.compareTo(b.name));

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error scanning for audio files: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Recursively scan a directory for audio files
  Future<void> _scanDirectory(
    Directory directory,
    List<AudioFile> audioFiles,
  ) async {
    try {
      final entities = await directory.list().toList();

      for (final entity in entities) {
        if (entity is File) {
          final audioFile = AudioFile.fromFile(entity);
          if (audioFile.isAudioFile) {
            audioFiles.add(audioFile);
          }
        } else if (entity is Directory) {
          // Skip certain system directories
          final dirName = entity.path.split('/').last;
          if (!dirName.startsWith('.') &&
              !dirName.contains('Android/data') &&
              !dirName.contains('Android/obb')) {
            await _scanDirectory(entity, audioFiles);
          }
        }
      }
    } catch (e) {
      debugPrint('Error scanning directory ${directory.path}: $e');
      // Continue with other directories
    }
  }

  /// Refresh the list of audio files
  Future<void> refreshAudioFiles() async {
    await loadAudioFiles();
  }

  /// Search for audio files matching the query
  void searchAudioFiles(String query) {
    _searchQuery = query.trim().toLowerCase();

    if (_searchQuery.isEmpty) {
      _filteredAudioFiles = [];
      notifyListeners();
      return;
    }

    _filteredAudioFiles =
        _audioFiles.where((file) {
          return file.name.toLowerCase().contains(_searchQuery);
        }).toList();

    notifyListeners();
  }

  /// Clear the search query
  void clearSearch() {
    _searchQuery = '';
    _filteredAudioFiles = [];
    notifyListeners();
  }
}
