/// Represents a recorded audio file with metadata
class Recording {
  /// Unique identifier for the recording
  final String id;

  /// Path to the recording file
  final String filePath;

  /// Title of the recording
  final String title;

  /// Sample rate in Hz
  final int sampleRate;

  /// Number of audio channels
  final int channels;

  /// Bit depth
  final int bitDepth;

  /// Duration in milliseconds
  final int durationMs;

  /// Timestamp when the recording was created (milliseconds since epoch)
  final int timestamp;

  /// Creates a new Recording instance
  Recording({
    required this.id,
    required this.filePath,
    required this.title,
    required this.sampleRate,
    required this.channels,
    required this.bitDepth,
    required this.durationMs,
    required this.timestamp,
  });

  /// Creates a Recording from a JSON map
  factory Recording.fromJson(Map<String, dynamic> json) {
    return Recording(
      id: json['id'] as String,
      filePath: json['filePath'] as String,
      title: json['title'] as String,
      sampleRate: json['sampleRate'] as int,
      channels: json['channels'] as int,
      bitDepth: json['bitDepth'] as int,
      durationMs: json['durationMs'] as int,
      timestamp: json['timestamp'] as int,
    );
  }

  /// Converts the Recording to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filePath': filePath,
      'title': title,
      'sampleRate': sampleRate,
      'channels': channels,
      'bitDepth': bitDepth,
      'durationMs': durationMs,
      'timestamp': timestamp,
    };
  }

  /// Creates a copy of this Recording with the given fields replaced
  Recording copyWith({
    String? id,
    String? filePath,
    String? title,
    int? sampleRate,
    int? channels,
    int? bitDepth,
    int? durationMs,
    int? timestamp,
  }) {
    return Recording(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      title: title ?? this.title,
      sampleRate: sampleRate ?? this.sampleRate,
      channels: channels ?? this.channels,
      bitDepth: bitDepth ?? this.bitDepth,
      durationMs: durationMs ?? this.durationMs,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  /// Returns a formatted duration string (mm:ss)
  String get formattedDuration {
    final seconds = (durationMs / 1000).round();
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  /// Returns a formatted date string
  String get formattedDate {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
