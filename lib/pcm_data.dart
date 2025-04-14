import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

/// A class that represents PCM audio data.
class PcmData {
  /// Raw PCM data as bytes.
  final Uint8List pcmData;

  /// RMS (Root Mean Square) value of the PCM data.
  final double rmsValue;

  /// Timestamp when the PCM data was captured.
  final int timestamp;

  /// Creates a new [PcmData] instance.
  PcmData({required this.pcmData, this.rmsValue = 0.0, this.timestamp = 0});

  /// Creates a [PcmData] from a map.
  factory PcmData.fromMap(Map<dynamic, dynamic> map) {
    if (map.containsKey('pcm') && map['pcm'] is String) {
      final pcmData = base64Decode(map['pcm'] as String);
      final rmsValue = map['rms'] as double? ?? 0.0;
      final timestamp =
          map['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch;

      return PcmData(
        pcmData: pcmData,
        rmsValue: rmsValue,
        timestamp: timestamp,
      );
    }

    throw FormatException('Invalid PCM data format');
  }

  /// Gets the PCM samples as 16-bit integers.
  ///
  /// This assumes the PCM data is in 16-bit format (2 bytes per sample).
  List<int> getSamples16Bit() {
    final result = <int>[];
    final byteData = ByteData.sublistView(pcmData);

    for (int i = 0; i < byteData.lengthInBytes; i += 2) {
      if (i + 1 < byteData.lengthInBytes) {
        final sample = byteData.getInt16(i, Endian.little);
        result.add(sample);
      }
    }

    return result;
  }

  /// Gets the PCM samples normalized to values between -1.0 and 1.0.
  List<double> getNormalizedSamples() {
    final samples = getSamples16Bit();
    final maxValue = 32768.0; // 2^15

    return samples.map((sample) => sample / maxValue).toList();
  }

  /// Gets the RMS (Root Mean Square) value of the PCM data.
  ///
  /// This is a measure of the average power of the signal.
  ///
  /// If the RMS value was provided when creating this object, that value is returned.
  /// Otherwise, it's calculated from the PCM data.
  double getRmsValue() {
    // If we already have an RMS value, use it
    if (rmsValue > 0) {
      return rmsValue;
    }

    // Otherwise calculate it from the PCM data
    final samples = getNormalizedSamples();
    if (samples.isEmpty) return 0.0;

    double sumOfSquares = 0.0;
    for (final sample in samples) {
      sumOfSquares += sample * sample;
    }

    return math.sqrt(sumOfSquares / samples.length);
  }

  /// Gets the peak amplitude of the PCM data.
  double getPeakAmplitude() {
    final samples = getNormalizedSamples();
    if (samples.isEmpty) return 0.0;

    double maxAmplitude = 0.0;
    for (final sample in samples) {
      final absValue = sample.abs();
      if (absValue > maxAmplitude) {
        maxAmplitude = absValue;
      }
    }

    return maxAmplitude;
  }
}
