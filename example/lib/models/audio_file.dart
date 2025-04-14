import 'dart:io';

/// Model representing a local audio file
class AudioFile {
  /// The file object
  final File file;
  
  /// The file name
  final String name;
  
  /// The file path
  final String path;
  
  /// The file size in bytes
  final int size;
  
  /// The file extension
  final String extension;
  
  /// The file's parent directory
  final String directory;
  
  /// The file's last modified date
  final DateTime lastModified;
  
  /// Optional metadata
  final Map<String, dynamic>? metadata;
  
  /// Creates a new AudioFile
  AudioFile({
    required this.file,
    required this.name,
    required this.path,
    required this.size,
    required this.extension,
    required this.directory,
    required this.lastModified,
    this.metadata,
  });
  
  /// Creates an AudioFile from a File object
  factory AudioFile.fromFile(File file) {
    final path = file.path;
    final name = path.split('/').last;
    final extension = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    final directory = path.substring(0, path.length - name.length);
    
    return AudioFile(
      file: file,
      name: name,
      path: path,
      size: file.lengthSync(),
      extension: extension,
      directory: directory,
      lastModified: file.lastModifiedSync(),
      metadata: {},
    );
  }
  
  /// Returns a formatted string representing the file size
  String get formattedSize {
    if (size < 1024) {
      return '$size B';
    } else if (size < 1024 * 1024) {
      final kb = size / 1024;
      return '${kb.toStringAsFixed(1)} KB';
    } else if (size < 1024 * 1024 * 1024) {
      final mb = size / (1024 * 1024);
      return '${mb.toStringAsFixed(1)} MB';
    } else {
      final gb = size / (1024 * 1024 * 1024);
      return '${gb.toStringAsFixed(1)} GB';
    }
  }
  
  /// Returns a formatted string representing the last modified date
  String get formattedDate {
    return '${lastModified.year}-${lastModified.month.toString().padLeft(2, '0')}-${lastModified.day.toString().padLeft(2, '0')}';
  }
  
  /// Returns a formatted string representing the last modified time
  String get formattedTime {
    return '${lastModified.hour.toString().padLeft(2, '0')}:${lastModified.minute.toString().padLeft(2, '0')}';
  }
  
  /// Returns whether this file is an audio file
  bool get isAudioFile {
    final audioExtensions = ['mp3', 'wav', 'aac', 'ogg', 'm4a', 'flac', 'wma'];
    return audioExtensions.contains(extension.toLowerCase());
  }
  
  /// Returns a copy of this AudioFile with the given fields replaced
  AudioFile copyWith({
    File? file,
    String? name,
    String? path,
    int? size,
    String? extension,
    String? directory,
    DateTime? lastModified,
    Map<String, dynamic>? metadata,
  }) {
    return AudioFile(
      file: file ?? this.file,
      name: name ?? this.name,
      path: path ?? this.path,
      size: size ?? this.size,
      extension: extension ?? this.extension,
      directory: directory ?? this.directory,
      lastModified: lastModified ?? this.lastModified,
      metadata: metadata ?? this.metadata,
    );
  }
}
