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
    final theme = Theme.of(context);
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
          size: const Size(240, 240),
          painter: DialPainter(
            frequency: widget.frequency,
            minFreq: widget.minFreq,
            maxFreq: widget.maxFreq,
            theme: theme,
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
  final ThemeData theme;

  DialPainter({
    required this.frequency,
    required this.minFreq,
    required this.maxFreq,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 10;
    final primaryColor = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;

    // Draw outer glow/shadow
    final shadowPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(center, radius, shadowPaint);

    // Draw outer border
    final outerPaint = Paint()
      ..color = theme.colorScheme.outline.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, outerPaint);

    // Draw background
    final bgPaint = Paint()
      ..color = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - 2, bgPaint);

    // Draw inner circle for depth
    final innerPaint = Paint()
      ..color = theme.colorScheme.surface.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - 15, innerPaint);

    // Draw frequency marks
    final markPaint = Paint()
      ..color = onSurface.withValues(alpha: 0.6)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final boldMarkPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.8)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i <= 20; i++) {
      double angle = -pi + (i / 20) * 2 * pi;
      bool isMajor = i % 2 == 0;
      double markLen = isMajor ? 12 : 6;
      
      Offset start = center + Offset(cos(angle) * (radius - 2), sin(angle) * (radius - 2));
      Offset end = center + Offset(cos(angle) * (radius - 2 - markLen), sin(angle) * (radius - 2 - markLen));
      
      canvas.drawLine(start, end, isMajor ? boldMarkPaint : markPaint);
    }

    // Draw frequency labels
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    for (int i = 0; i <= 10; i++) {
      double freq = minFreq + (i / 10) * (maxFreq - minFreq);
      double angle = -pi + (i / 10) * 2 * pi;
      Offset labelPos = center + Offset(cos(angle) * (radius - 35), sin(angle) * (radius - 35));
      
      textPainter.text = TextSpan(
        text: freq.toStringAsFixed(0),
        style: TextStyle(
          color: onSurface.withValues(alpha: 0.9),
          fontSize: 13,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
        ),
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
    
    // Needle shadow
    final needleShadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    
    Offset needleEnd = center + Offset(cos(angle) * (radius - 12), sin(angle) * (radius - 12));
    canvas.drawLine(center + const Offset(1, 1), needleEnd + const Offset(1, 1), needleShadowPaint);

    final needlePaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, needleEnd, needlePaint);

    // Draw center hub
    canvas.drawCircle(center, 10, Paint()..color = theme.colorScheme.surface);
    canvas.drawCircle(center, 10, Paint()..color = primaryColor.withValues(alpha: 0.2)..style = PaintingStyle.fill);
    canvas.drawCircle(center, 10, Paint()..color = primaryColor..style = PaintingStyle.stroke..strokeWidth = 2);
    canvas.drawCircle(center, 4, Paint()..color = primaryColor);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
