import 'dart:convert';
import 'dart:typed_data';

/// A class that represents audio visualization data.
class VisualizationData {
  /// Raw waveform data as bytes.
  final Uint8List? waveform;

  /// Raw FFT (frequency) data as bytes.
  final Uint8List? fft;

  /// Timestamp when the visualization data was captured.
  final int timestamp;

  /// Creates a new [VisualizationData] instance.
  VisualizationData({this.waveform, this.fft, this.timestamp = 0});

  /// Creates a [VisualizationData] from a map.
  factory VisualizationData.fromMap(Map<dynamic, dynamic> map) {
    Uint8List? waveformData;
    Uint8List? fftData;
    int timestamp =
        map['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch;

    if (map.containsKey('waveform') && map['waveform'] is String) {
      final waveformStr = map['waveform'] as String;
      if (waveformStr.isNotEmpty) {
        waveformData = base64Decode(waveformStr);
      }
    }

    if (map.containsKey('fft') && map['fft'] is String) {
      final fftStr = map['fft'] as String;
      if (fftStr.isNotEmpty) {
        fftData = base64Decode(fftStr);
      }
    }

    return VisualizationData(
      waveform: waveformData,
      fft: fftData,
      timestamp: timestamp,
    );
  }

  /// Returns true if this visualization data has valid waveform data.
  bool get hasWaveform => waveform != null && waveform!.isNotEmpty;

  /// Returns true if this visualization data has valid FFT data.
  bool get hasFft => fft != null && fft!.isNotEmpty;

  /// Gets the amplitude values from the waveform data.
  ///
  /// Returns a list of values between 0.0 and 1.0 representing the amplitude.
  List<double> getAmplitudeValues() {
    if (waveform == null || waveform!.isEmpty) {
      // Return a flat line if no data is available
      return List.filled(64, 0.5);
    }

    return waveform!.map((byte) => byte / 255.0).toList();
  }

  /// Gets the frequency spectrum values from the FFT data.
  ///
  /// Returns a list of values between 0.0 and 1.0 representing the magnitude
  /// of each frequency band.
  List<double> getFrequencyValues() {
    if (fft == null || fft!.isEmpty) {
      // Return a flat line if no data is available
      return List.filled(32, 0.1);
    }

    // FFT data is in complex form (real/imaginary pairs)
    // We need to calculate the magnitude of each pair
    final result = <double>[];

    try {
      for (int i = 0; i < fft!.length; i += 2) {
        if (i + 1 < fft!.length) {
          final real = fft![i].toDouble() - 128;
          final imag = fft![i + 1].toDouble() - 128;
          final magnitude = _calculateMagnitude(real, imag);
          result.add(magnitude);
        }
      }

      // If we somehow got no results, return a default array
      if (result.isEmpty) {
        return List.filled(32, 0.1);
      }

      return result;
    } catch (e) {
      // Log error but continue with default data
      // ignore: avoid_print
      print('Error processing FFT data: $e');
      return List.filled(32, 0.1);
    }
  }

  /// Calculates the magnitude of a complex number.
  double _calculateMagnitude(double real, double imag) {
    // Calculate magnitude and normalize to 0.0-1.0 range
    final magnitude = (real * real + imag * imag) / (128.0 * 128.0);
    return magnitude > 1.0 ? 1.0 : magnitude;
  }
}
