import 'dart:io';

/// Represents an audio recording
class Recording {
  /// The file containing the recording
  final File file;
  
  /// The name of the recording
  final String name;
  
  /// The date and time when the recording was created
  final DateTime dateTime;
  
  /// The duration of the recording in milliseconds
  final int duration;
  
  /// The size of the recording file in bytes
  final int fileSize;
  
  /// Creates a new Recording
  Recording({
    required this.file,
    required this.name,
    required this.dateTime,
    required this.duration,
    required this.fileSize,
  });
  
  /// Creates a Recording from a file
  /// 
  /// The name is derived from the file name, and the date is derived from the file creation time.
  /// The duration and file size are set to default values and should be updated later.
  factory Recording.fromFile(File file) {
    final fileName = file.path.split('/').last;
    final name = fileName.replaceAll(RegExp(r'recording_\d+\.wav'), '').isEmpty
        ? fileName
        : fileName.replaceAll(RegExp(r'recording_\d+\.wav'), '');
    
    return Recording(
      file: file,
      name: name,
      dateTime: file.lastModifiedSync(),
      duration: 0, // Will be updated when the recording is played
      fileSize: file.lengthSync(),
    );
  }
  
  /// Returns a copy of this recording with the given fields replaced
  Recording copyWith({
    File? file,
    String? name,
    DateTime? dateTime,
    int? duration,
    int? fileSize,
  }) {
    return Recording(
      file: file ?? this.file,
      name: name ?? this.name,
      dateTime: dateTime ?? this.dateTime,
      duration: duration ?? this.duration,
      fileSize: fileSize ?? this.fileSize,
    );
  }
  
  /// Returns a formatted string representing the file size
  String get formattedFileSize {
    final kb = fileSize / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    } else {
      final mb = kb / 1024;
      return '${mb.toStringAsFixed(1)} MB';
    }
  }
  
  /// Returns a formatted string representing the duration
  String get formattedDuration {
    final seconds = duration ~/ 1000;
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }
  
  /// Returns a formatted string representing the date
  String get formattedDate {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
  }
  
  /// Returns a formatted string representing the time
  String get formattedTime {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
