/// WAV file header information
class WavHeader {
  final int sampleRate;
  final int channels;
  final int bitsPerSample;
  final int dataSize;
  final int durationMs;

  WavHeader({
    required this.sampleRate,
    required this.channels,
    required this.bitsPerSample,
    required this.dataSize,
    required this.durationMs,
  });

  factory WavHeader.fromMap(Map<dynamic, dynamic> map) {
    return WavHeader(
      sampleRate: map['sampleRate'] as int,
      channels: map['channels'] as int,
      bitsPerSample: map['bitsPerSample'] as int,
      dataSize: map['dataSize'] as int,
      durationMs: map['durationMs'] as int,
    );
  }
}
