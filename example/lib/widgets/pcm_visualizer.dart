import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_audio_recorder_player/flutter_audio_recorder_player.dart';

/// A widget that visualizes PCM data
class PcmVisualizer extends StatefulWidget {
  /// The FlutterAudioRecorderPlayer plugin instance
  final FlutterAudioRecorderPlayer mymediaPlugin;

  /// Creates a new PcmVisualizer
  const PcmVisualizer({super.key, required this.mymediaPlugin});

  @override
  State<PcmVisualizer> createState() => _PcmVisualizerState();
}

class _PcmVisualizerState extends State<PcmVisualizer> {
  List<double> _pcmSamples = [];
  double _rmsValue = 0.0;
  StreamSubscription<PcmData>? _pcmDataSubscription;
  bool _isActive = false;

  // Buffer for RMS history to create a smoother visualization
  final List<double> _rmsHistory = List.filled(30, 0.0);
  int _rmsHistoryIndex = 0;

  @override
  void initState() {
    super.initState();
    _subscribeToPcmData();
  }

  @override
  void dispose() {
    _pcmDataSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToPcmData() {
    _pcmDataSubscription = widget.mymediaPlugin.getPcmDataStream().listen((
      data,
    ) {
      if (mounted) {
        setState(() {
          // Get normalized samples (values between -1.0 and 1.0)
          final samples = data.getNormalizedSamples();

          // Only keep a subset of samples for visualization
          // to avoid overwhelming the UI
          if (samples.isNotEmpty) {
            final step = math.max(1, samples.length ~/ 200);
            _pcmSamples = [];
            for (int i = 0; i < samples.length; i += step) {
              _pcmSamples.add(samples[i]);
            }

            // Update RMS value
            _rmsValue = data.rmsValue;

            // Add to RMS history
            _rmsHistory[_rmsHistoryIndex] = _rmsValue;
            _rmsHistoryIndex = (_rmsHistoryIndex + 1) % _rmsHistory.length;

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
              Icons.audio_file,
              size: 48,
              color: theme.colorScheme.primary.withAlpha(128),
            ),
            const SizedBox(height: 16),
            Text(
              'Start playback to see PCM data',
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text('PCM Waveform', style: theme.textTheme.titleMedium),
        ),
        SizedBox(
          height: 100,
          child: CustomPaint(
            painter: PcmWaveformPainter(
              pcmSamples: _pcmSamples,
              color: theme.colorScheme.tertiary,
            ),
            size: Size.infinite,
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text('Audio Level (RMS)', style: theme.textTheme.titleMedium),
        ),
        SizedBox(
          height: 100,
          child: CustomPaint(
            painter: RmsLevelPainter(
              rmsHistory: _rmsHistory,
              color: theme.colorScheme.primary,
            ),
            size: Size.infinite,
          ),
        ),
        const SizedBox(height: 16),
        // Display RMS value as a percentage
        Text(
          'Current RMS: ${(_rmsValue * 100).toStringAsFixed(1)}%',
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}

/// Painter for the PCM waveform visualization
class PcmWaveformPainter extends CustomPainter {
  /// The PCM samples
  final List<double> pcmSamples;

  /// The color of the waveform
  final Color color;

  /// Creates a new PcmWaveformPainter
  PcmWaveformPainter({required this.pcmSamples, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (pcmSamples.isEmpty) return;

    final paint =
        Paint()
          ..color = color
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

    final path = Path();
    final width = size.width;
    final height = size.height;
    final middle = height / 2;

    // Calculate the step size to fit all data points
    final step = width / (pcmSamples.length - 1);

    // Start at the first point
    path.moveTo(0, middle - pcmSamples[0] * middle);

    // Draw the waveform
    for (int i = 1; i < pcmSamples.length; i++) {
      final x = i * step;
      final y = middle - pcmSamples[i] * middle;
      path.lineTo(x, y);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(PcmWaveformPainter oldDelegate) {
    return oldDelegate.pcmSamples != pcmSamples || oldDelegate.color != color;
  }
}

/// Painter for the RMS level visualization
class RmsLevelPainter extends CustomPainter {
  /// The RMS history
  final List<double> rmsHistory;

  /// The color of the level
  final Color color;

  /// Creates a new RmsLevelPainter
  RmsLevelPainter({required this.rmsHistory, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

    final fillPaint =
        Paint()
          ..color = color.withAlpha(51)
          ..style = PaintingStyle.fill;

    final path = Path();
    final width = size.width;
    final height = size.height;

    // Calculate the step size to fit all data points
    final step = width / (rmsHistory.length - 1);

    // Start at the first point
    path.moveTo(0, height - rmsHistory[0] * height);

    // Draw the level curve
    for (int i = 1; i < rmsHistory.length; i++) {
      final x = i * step;
      final y = height - rmsHistory[i] * height;
      path.lineTo(x, y);
    }

    // Complete the path for filling
    final fillPath = Path.from(path);
    fillPath.lineTo(width, height);
    fillPath.lineTo(0, height);
    fillPath.close();

    // Draw the filled area
    canvas.drawPath(fillPath, fillPaint);

    // Draw the line
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(RmsLevelPainter oldDelegate) {
    return oldDelegate.rmsHistory != rmsHistory || oldDelegate.color != color;
  }
}
