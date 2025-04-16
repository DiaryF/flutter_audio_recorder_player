import 'dart:io';
import 'package:path/path.dart' as path;

/// Base class for all audio sources
abstract class AudioSource {
  /// The unique identifier for this audio source
  String get id;

  /// Converts this audio source to a map for platform channel
  Map<String, dynamic> toMap();
}

/// An audio source from a URI (remote URL, asset, or file)
class UriAudioSource extends AudioSource {
  /// The URI of the audio source
  final Uri uri;

  /// The title of the audio source
  final String? title;

  /// The artist of the audio source
  final String? artist;

  /// The album of the audio source
  final String? album;

  /// The URI of the album art
  final String? artUri;

  /// The genre of the audio source
  final String? genre;

  /// The track number of the audio source
  final int? trackNumber;

  /// The total number of tracks in the album
  final int? trackCount;

  /// The year of the audio source
  final int? year;

  /// The headers to use when making HTTP requests
  final Map<String, String>? headers;

  /// Creates an audio source from a URI
  UriAudioSource({
    required this.uri,
    this.title,
    this.artist,
    this.album,
    this.artUri,
    this.genre,
    this.trackNumber,
    this.trackCount,
    this.year,
    this.headers,
  });

  @override
  String get id => uri.toString();

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': 'uri',
      'uri': uri.toString(),
      'title': title,
      'artist': artist,
      'album': album,
      'artUri': artUri,
      'genre': genre,
      'trackNumber': trackNumber,
      'trackCount': trackCount,
      'year': year,
      'headers': headers,
    };
  }

  @override
  String toString() {
    return 'UriAudioSource(uri: $uri, title: $title)';
  }
}

/// An audio source from a URL
class UrlAudioSource extends UriAudioSource {
  /// Creates an audio source from a URL
  UrlAudioSource({
    required String url,
    String? title,
    super.artist,
    super.album,
    super.artUri,
    super.genre,
    super.trackNumber,
    super.trackCount,
    super.year,
    super.headers,
  }) : super(uri: Uri.parse(url), title: title ?? _extractTitle(url));

  /// Extracts a title from a URL
  static String? _extractTitle(String url) {
    final uri = Uri.parse(url);
    final pathSegments = uri.pathSegments;
    if (pathSegments.isEmpty) {
      return null;
    }
    final fileName = pathSegments.last;
    final fileNameWithoutExtension = path.basenameWithoutExtension(fileName);
    return fileNameWithoutExtension;
  }
}

/// An audio source from a file
class FileAudioSource extends UriAudioSource {
  /// The file
  final File file;

  /// Creates an audio source from a file
  FileAudioSource({
    required this.file,
    String? title,
    super.artist,
    super.album,
    super.artUri,
    super.genre,
    super.trackNumber,
    super.trackCount,
    super.year,
  }) : super(
         uri: file.uri,
         title: title ?? path.basenameWithoutExtension(file.path),
       );
}

/// An audio source from an asset
class AssetAudioSource extends UriAudioSource {
  /// The asset path
  final String assetPath;

  /// Creates an audio source from an asset
  AssetAudioSource({
    required this.assetPath,
    String? title,
    super.artist,
    super.album,
    super.artUri,
    super.genre,
    super.trackNumber,
    super.trackCount,
    super.year,
  }) : super(
         uri: Uri.parse('asset:///$assetPath'),
         title: title ?? path.basenameWithoutExtension(assetPath),
       );

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map['type'] = 'asset';
    map['assetPath'] = assetPath;
    return map;
  }
}

/// A concatenating audio source that plays multiple audio sources one after the other
class ConcatenatingAudioSource extends AudioSource {
  /// The child audio sources
  final List<AudioSource> children;

  /// Whether to use lazy preparation
  final bool useLazyPreparation;

  /// Creates a concatenating audio source
  ConcatenatingAudioSource({
    required this.children,
    this.useLazyPreparation = true,
  });

  @override
  String get id => 'concatenating-${children.map((c) => c.id).join('-')}';

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': 'concatenating',
      'children': children.map((c) => c.toMap()).toList(),
      'useLazyPreparation': useLazyPreparation,
    };
  }

  /// Adds a child audio source
  Future<void> add(AudioSource audioSource) async {
    children.add(audioSource);
    // In a real implementation, we would notify the platform side
  }

  /// Inserts a child audio source at the given index
  Future<void> insert(int index, AudioSource audioSource) async {
    children.insert(index, audioSource);
    // In a real implementation, we would notify the platform side
  }

  /// Removes the child audio source at the given index
  Future<void> removeAt(int index) async {
    children.removeAt(index);
    // In a real implementation, we would notify the platform side
  }
}
