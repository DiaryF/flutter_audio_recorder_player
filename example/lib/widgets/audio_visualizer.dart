import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_audio_recorder_player/flutter_audio_recorder_player.dart';

/// A widget that visualizes audio data
class AudioVisualizer extends StatefulWidget {
  /// The FlutterAudioRecorderPlayer plugin instance
  final FlutterAudioRecorderPlayer mymediaPlugin;

  /// Whether to show the waveform visualization
  final bool showWaveform;

  /// Whether to show the spectrum visualization
  final bool showSpectrum;

  /// Creates a new AudioVisualizer
  const AudioVisualizer({
    super.key,
    required this.mymediaPlugin,
    this.showWaveform = true,
    this.showSpectrum = true,
  });

  @override
  State<AudioVisualizer> createState() => _AudioVisualizerState();
}

class _AudioVisualizerState extends State<AudioVisualizer> {
  List<int> _waveformData = [];
  List<int> _spectrumData = [];
  StreamSubscription<VisualizationData>? _visualizationSubscription;
  bool _isActive = false;

  @override
  void initState() {
    super.initState();
    _subscribeToVisualizationData();
  }

  @override
  void dispose() {
    _visualizationSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToVisualizationData() {
    _visualizationSubscription = widget.mymediaPlugin
        .getVisualizationDataStream()
        .listen((data) {
          if (mounted) {
            setState(() {
              if (widget.showWaveform &&
                  data.waveform != null &&
                  data.waveform!.isNotEmpty) {
                _waveformData = data.waveform!.toList();
                _isActive = true;
              }
              if (widget.showSpectrum &&
                  data.fft != null &&
                  data.fft!.isNotEmpty) {
                _spectrumData = data.fft!.toList();
                _isActive = true;
              }
            });
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!_isActive) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.graphic_eq,
              size: 48,
              color: theme.colorScheme.primary.withAlpha(128),
            ),
            const SizedBox(height: 16),
            Text(
              'Start playback to see visualization',
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (widget.showWaveform) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text('Waveform', style: theme.textTheme.titleMedium),
          ),
          SizedBox(
            height: 100,
            child: CustomPaint(
              painter: WaveformPainter(
                waveformData: _waveformData,
                color: theme.colorScheme.primary,
              ),
              size: Size.infinite,
            ),
          ),
          const SizedBox(height: 24),
        ],
        if (widget.showSpectrum) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text('Spectrum', style: theme.textTheme.titleMedium),
          ),
          SizedBox(
            height: 100,
            child: CustomPaint(
              painter: SpectrumPainter(
                spectrumData: _spectrumData,
                color: theme.colorScheme.secondary,
              ),
              size: Size.infinite,
            ),
          ),
        ],
      ],
    );
  }
}

/// Painter for the waveform visualization
class WaveformPainter extends CustomPainter {
  /// The waveform data
  final List<int> waveformData;

  /// The color of the waveform
  final Color color;

  /// Creates a new WaveformPainter
  WaveformPainter({required this.waveformData, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (waveformData.isEmpty) return;

    final paint =
        Paint()
          ..color = color
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

    final path = Path();
    final width = size.width;
    final height = size.height;
    final middle = height / 2;

    // Calculate the step size to fit all data points
    final step = width / (waveformData.length - 1);

    // Start at the first point
    path.moveTo(0, middle - (waveformData[0] / 255.0) * middle);

    // Draw the waveform
    for (int i = 1; i < waveformData.length; i++) {
      final x = i * step;
      final y = middle - (waveformData[i] / 255.0) * middle;
      path.lineTo(x, y);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return oldDelegate.waveformData != waveformData ||
        oldDelegate.color != color;
  }
}

/// Painter for the spectrum visualization
class SpectrumPainter extends CustomPainter {
  /// The spectrum data
  final List<int> spectrumData;

  /// The color of the spectrum
  final Color color;

  /// Creates a new SpectrumPainter
  SpectrumPainter({required this.spectrumData, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (spectrumData.isEmpty) return;

    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;

    final width = size.width;
    final height = size.height;

    // Calculate the bar width and spacing
    final barCount = math.min(spectrumData.length, 64); // Limit to 64 bars
    final barWidth =
        width / barCount * 0.8; // 80% width for bars, 20% for spacing
    final spacing = width / barCount * 0.2;

    // Draw each bar
    for (int i = 0; i < barCount; i++) {
      final barHeight = (spectrumData[i] / 255.0) * height;
      final rect = Rect.fromLTWH(
        i * (barWidth + spacing),
        height - barHeight,
        barWidth,
        barHeight,
      );
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(SpectrumPainter oldDelegate) {
    return oldDelegate.spectrumData != spectrumData ||
        oldDelegate.color != color;
  }
}
