import 'package:flutter/material.dart';
import 'dart:math';

class FrequencyDial extends StatefulWidget {
  final double frequency;
  final double minFreq;
  final double maxFreq;
  final ValueChanged<double> onFrequencyChanged;

  const FrequencyDial({
    super.key,
    required this.frequency,
    this.minFreq = 87.5,
    this.maxFreq = 108.0,
    required this.onFrequencyChanged,
  });

  @override
  State<FrequencyDial> createState() => _FrequencyDialState();
}

class _FrequencyDialState extends State<FrequencyDial>
    with SingleTickerProviderStateMixin {
  double _dragStart = 0;
  double _currentAngle = 0;

  @override
  void initState() {
    super.initState();
    _updateAngle();
  }

  void _updateAngle() {
    double range = widget.maxFreq - widget.minFreq;
    double normalized = (widget.frequency - widget.minFreq) / range;
    _currentAngle = normalized * 2 * pi - pi; // -pi to pi
  }

  @override
  void didUpdateWidget(FrequencyDial oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.frequency != widget.frequency) {
      _updateAngle();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) {
        _dragStart = details.localPosition.dx;
      },
      onPanUpdate: (details) {
        double delta = details.localPosition.dx - _dragStart;
        double angleDelta = delta / 100; // Sensitivity
        double newAngle = _currentAngle + angleDelta;
        newAngle = newAngle.clamp(-pi, pi);
        double range = widget.maxFreq - widget.minFreq;
        double normalized = (newAngle + pi) / (2 * pi);
        double newFreq = widget.minFreq + normalized * range;
        widget.onFrequencyChanged(newFreq);
        _currentAngle = newAngle;
      },
      child: RepaintBoundary(
        child: CustomPaint(
          size: const Size(200, 200),
          painter: DialPainter(
            frequency: widget.frequency,
            minFreq: widget.minFreq,
            maxFreq: widget.maxFreq,
          ),
        ),
      ),
    );
  }
}

class DialPainter extends CustomPainter {
  final double frequency;
  final double minFreq;
  final double maxFreq;

  DialPainter({
    required this.frequency,
    required this.minFreq,
    required this.maxFreq,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 20;

    // Draw outer circle
    final outerPaint = Paint()
      ..color = Colors.grey[800]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, radius, outerPaint);

    // Draw inner circle
    final innerPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - 10, innerPaint);

    // Draw frequency marks
    final markPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2;

    for (int i = 0; i <= 10; i++) {
      double angle = -pi + (i / 10) * 2 * pi;
      double markRadius = radius - 15;
      Offset start =
          center + Offset(cos(angle) * (radius - 5), sin(angle) * (radius - 5));
      Offset end =
          center + Offset(cos(angle) * markRadius, sin(angle) * markRadius);
      canvas.drawLine(start, end, markPaint);
    }

    // Draw frequency labels
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    for (int i = 0; i <= 10; i++) {
      double freq = minFreq + (i / 10) * (maxFreq - minFreq);
      double angle = -pi + (i / 10) * 2 * pi;
      Offset labelPos =
          center +
          Offset(cos(angle) * (radius - 30), sin(angle) * (radius - 30));
      textPainter.text = TextSpan(
        text: freq.toStringAsFixed(1),
        style: const TextStyle(color: Colors.white, fontSize: 12),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        labelPos - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }

    // Draw needle
    double range = maxFreq - minFreq;
    double normalized = (frequency - minFreq) / range;
    double angle = -pi + normalized * 2 * pi;
    Offset needleEnd =
        center + Offset(cos(angle) * (radius - 20), sin(angle) * (radius - 20));
    final needlePaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, needleEnd, needlePaint);

    // Draw center dot
    canvas.drawCircle(center, 5, Paint()..color = Colors.red);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
