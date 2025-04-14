/// Utility functions for formatting
class FormatUtils {
  /// Format duration in milliseconds to mm:ss format
  static String formatDuration(int milliseconds) {
    final seconds = (milliseconds / 1000).floor();
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }
  
  /// Create a display name from a stream URL
  static String createDisplayName(String url) {
    final streamName = url.split('/').last;
    
    return streamName
        .replaceAll('-', ' ')
        .replaceAll('.mp3', '')
        .replaceAll('.aac', '')
        .split(' ')
        .map((word) => word.isNotEmpty 
            ? '${word[0].toUpperCase()}${word.substring(1)}' 
            : '')
        .join(' ');
  }
}
