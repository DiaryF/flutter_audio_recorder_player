import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_audio_recorder_player/flutter_audio_recorder_player.dart';

/// A widget that displays a waveform visualization of a WAV file.
class WaveformView extends StatefulWidget {
  /// The path to the WAV file to visualize.
  final String filePath;

  /// The number of samples to display in the waveform.
  final int samplesCount;

  /// The color of the waveform.
  final Color waveformColor;

  /// The color of the waveform background.
  final Color backgroundColor;

  /// The color of the selection area.
  final Color selectionColor;

  /// The color of the playback position indicator.
  final Color positionColor;

  /// The width of each waveform bar.
  final double barWidth;

  /// The spacing between each waveform bar.
  final double spacing;

  /// Whether to enable selection.
  final bool enableSelection;

  /// Callback when selection changes.
  final Function(int startMs, int endMs)? onSelectionChanged;

  /// Callback when the user taps on the waveform.
  final Function(int positionMs)? onPositionTapped;

  /// The current playback position in milliseconds.
  final int? currentPositionMs;

  /// The total duration of the audio in milliseconds.
  final int? durationMs;

  const WaveformView({
    super.key,
    required this.filePath,
    this.samplesCount = 100,
    this.waveformColor = Colors.blue,
    this.backgroundColor = Colors.black12,
    this.selectionColor = Colors.blue,
    this.positionColor = Colors.red,
    this.barWidth = 2.0,
    this.spacing = 1.0,
    this.enableSelection = false,
    this.onSelectionChanged,
    this.onPositionTapped,
    this.currentPositionMs,
    this.durationMs,
  });

  @override
  State<WaveformView> createState() => _WaveformViewState();
}

class _WaveformViewState extends State<WaveformView> {
  Uint8List? _waveformData;
  bool _isLoading = true;
  int? _startSelectionMs;
  int? _endSelectionMs;
  double? _startSelectionPosition;
  double? _endSelectionPosition;
  int? _wavDurationMs;

  @override
  void initState() {
    super.initState();
    _loadWaveformData();
  }

  @override
  void didUpdateWidget(WaveformView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath ||
        oldWidget.samplesCount != widget.samplesCount) {
      _loadWaveformData();
    }
  }

  Future<void> _loadWaveformData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get the WAV header information
      final player = FlutterAudioRecorderPlayer();
      final header = await player.parseWavHeader(widget.filePath);
      _wavDurationMs = header.durationMs;

      // Generate the waveform data
      final waveformData = await player.generateWaveformData(
        widget.filePath,
        samplesCount: widget.samplesCount,
      );

      setState(() {
        _waveformData = waveformData;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading waveform data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _handlePanStart(DragStartDetails details) {
    if (!widget.enableSelection) return;

    final box = context.findRenderObject() as RenderBox;
    final localPosition = box.globalToLocal(details.globalPosition);
    final position = localPosition.dx / box.size.width;
    final duration = (_wavDurationMs ?? 0) > 0 ? _wavDurationMs! : 0;
    final positionMs = (position * duration).round();

    setState(() {
      _startSelectionPosition = position;
      _endSelectionPosition = position;
      _startSelectionMs = positionMs;
      _endSelectionMs = positionMs;
    });
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!widget.enableSelection || _startSelectionPosition == null) return;

    final box = context.findRenderObject() as RenderBox;
    final localPosition = box.globalToLocal(details.globalPosition);
    final position = localPosition.dx / box.size.width;
    final clampedPosition = position.clamp(0.0, 1.0);
    final duration = (_wavDurationMs ?? 0) > 0 ? _wavDurationMs! : 0;
    final positionMs = (clampedPosition * duration).round();

    setState(() {
      _endSelectionPosition = clampedPosition;
      _endSelectionMs = positionMs;
    });

    // Notify selection change
    if (widget.onSelectionChanged != null &&
        _startSelectionMs != null &&
        _endSelectionMs != null) {
      final startMs = _startSelectionMs!;
      final endMs = _endSelectionMs!;
      widget.onSelectionChanged!(
        startMs < endMs ? startMs : endMs,
        startMs < endMs ? endMs : startMs,
      );
    }
  }

  void _handleTap(TapDownDetails details) {
    if (widget.onPositionTapped == null || _wavDurationMs == null) return;

    final box = context.findRenderObject() as RenderBox;
    final localPosition = box.globalToLocal(details.globalPosition);
    final position = localPosition.dx / box.size.width;
    final duration =
        _wavDurationMs! > 0
            ? _wavDurationMs!
            : 1; // Use 1 as fallback to avoid division by zero
    final positionMs = (position * duration).round();

    widget.onPositionTapped!(positionMs);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 100,
        color: widget.backgroundColor,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_waveformData == null) {
      return Container(
        height: 100,
        color: widget.backgroundColor,
        child: const Center(child: Text('Failed to load waveform')),
      );
    }

    return GestureDetector(
      onPanStart: _handlePanStart,
      onPanUpdate: _handlePanUpdate,
      onTapDown: _handleTap,
      child: CustomPaint(
        size: Size.fromHeight(100),
        painter: _WaveformPainter(
          waveformData: _waveformData!,
          waveformColor: widget.waveformColor,
          backgroundColor: widget.backgroundColor,
          selectionColor: widget.selectionColor.withAlpha(76), // 0.3 opacity
          positionColor: widget.positionColor,
          barWidth: widget.barWidth,
          spacing: widget.spacing,
          startSelectionPosition: _startSelectionPosition,
          endSelectionPosition: _endSelectionPosition,
          currentPositionMs: widget.currentPositionMs,
          durationMs:
              (widget.durationMs ?? _wavDurationMs ?? 0) > 0
                  ? (widget.durationMs ?? _wavDurationMs)
                  : 0,
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final Uint8List waveformData;
  final Color waveformColor;
  final Color backgroundColor;
  final Color selectionColor;
  final Color positionColor;
  final double barWidth;
  final double spacing;
  final double? startSelectionPosition;
  final double? endSelectionPosition;
  final int? currentPositionMs;
  final int? durationMs;

  _WaveformPainter({
    required this.waveformData,
    required this.waveformColor,
    required this.backgroundColor,
    required this.selectionColor,
    required this.positionColor,
    required this.barWidth,
    required this.spacing,
    this.startSelectionPosition,
    this.endSelectionPosition,
    this.currentPositionMs,
    this.durationMs,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw background
    final backgroundPaint = Paint()..color = backgroundColor;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      backgroundPaint,
    );

    // Calculate bar positions
    final totalWidth = waveformData.length * (barWidth + spacing) - spacing;
    final scale = size.width / totalWidth;
    final scaledBarWidth = barWidth * scale;
    final scaledSpacing = spacing * scale;

    // Draw selection area if enabled
    if (startSelectionPosition != null && endSelectionPosition != null) {
      final left =
          startSelectionPosition! < endSelectionPosition!
              ? startSelectionPosition!
              : endSelectionPosition!;
      final right =
          startSelectionPosition! < endSelectionPosition!
              ? endSelectionPosition!
              : startSelectionPosition!;

      final selectionPaint = Paint()..color = selectionColor;
      canvas.drawRect(
        Rect.fromLTWH(
          left * size.width,
          0,
          (right - left) * size.width,
          size.height,
        ),
        selectionPaint,
      );
    }

    // Draw waveform bars
    final waveformPaint = Paint()..color = waveformColor;
    for (int i = 0; i < waveformData.length; i++) {
      final x = i * (scaledBarWidth + scaledSpacing);
      final amplitude = waveformData[i] / 255.0;
      final height = size.height * amplitude;
      final y = (size.height - height) / 2;

      canvas.drawRect(
        Rect.fromLTWH(x, y, scaledBarWidth, height),
        waveformPaint,
      );
    }

    // Draw current position indicator
    if (currentPositionMs != null && durationMs != null && durationMs! > 0) {
      // Ensure currentPositionMs is valid and not greater than durationMs
      final validPositionMs = currentPositionMs!.clamp(0, durationMs!);
      final position = validPositionMs / durationMs!;
      // Ensure position is between 0 and 1
      final clampedPosition = position.clamp(0.0, 1.0);
      final positionX = clampedPosition * size.width;
      final positionPaint =
          Paint()
            ..color = positionColor
            ..strokeWidth = 2.0;

      canvas.drawLine(
        Offset(positionX, 0),
        Offset(positionX, size.height),
        positionPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return waveformData != oldDelegate.waveformData ||
        waveformColor != oldDelegate.waveformColor ||
        backgroundColor != oldDelegate.backgroundColor ||
        selectionColor != oldDelegate.selectionColor ||
        positionColor != oldDelegate.positionColor ||
        barWidth != oldDelegate.barWidth ||
        spacing != oldDelegate.spacing ||
        startSelectionPosition != oldDelegate.startSelectionPosition ||
        endSelectionPosition != oldDelegate.endSelectionPosition ||
        currentPositionMs != oldDelegate.currentPositionMs ||
        durationMs != oldDelegate.durationMs;
  }
}
