/// Exception thrown by the audio player
class PlayerException implements Exception {
  /// The error code
  final String code;
  
  /// The error message
  final String message;
  
  /// Additional error details
  final dynamic details;
  
  /// Creates a new player exception
  PlayerException(this.code, this.message, [this.details]);
  
  @override
  String toString() {
    return 'PlayerException($code, $message${details != null ? ', $details' : ''})';
  }
  
  /// Creates a player exception from a map
  factory PlayerException.fromMap(Map<dynamic, dynamic> map) {
    return PlayerException(
      map['code'] as String? ?? 'unknown',
      map['message'] as String? ?? 'Unknown error',
      map['details'],
    );
  }
  
  /// Converts this exception to a map
  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'message': message,
      'details': details,
    };
  }
}

/// Exception thrown when loading an audio source fails
class SourceException extends PlayerException {
  /// The URL or path of the source that failed to load
  final String source;
  
  /// Creates a new source exception
  SourceException(String code, String message, this.source, [dynamic details])
      : super(code, message, details);
  
  @override
  String toString() {
    return 'SourceException($code, $message, $source${details != null ? ', $details' : ''})';
  }
  
  /// Creates a source exception from a map
  factory SourceException.fromMap(Map<dynamic, dynamic> map) {
    return SourceException(
      map['code'] as String? ?? 'unknown',
      map['message'] as String? ?? 'Unknown error',
      map['source'] as String? ?? 'unknown',
      map['details'],
    );
  }
  
  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map['source'] = source;
    return map;
  }
}
