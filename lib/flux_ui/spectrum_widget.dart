import 'package:flutter/material.dart';
import 'package:flutter_shaders/flutter_shaders.dart';

class SpectrumVisualizer extends StatelessWidget {
  final double currentFrequency;
  final List<double> signalStrengths; // List of RSSI for frequencies

  const SpectrumVisualizer({
    super.key,
    required this.currentFrequency,
    required this.signalStrengths,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    // Generate mock spectrum data based on current frequency
    final spectrumData = List.generate(101, (i) {
      final freq = 87.5 + i * 0.2;
      final distance = (freq - currentFrequency).abs();
      if (distance < 0.5) {
        return 80.0 - distance * 20; // Peak at current freq
      }
      return 20.0 + (i % 10) * 3.0; // Noise
    });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryColor.withValues(alpha: 0.2), width: 1.5),
      ),
      child: RepaintBoundary(
        child: ShaderBuilder(
          assetKey: 'shaders/spectrum.frag',
          (context, shader, child) => CustomPaint(
            size: const Size(double.infinity, 100),
            painter: SpectrumPainter(
              shader: shader,
              currentFrequency: currentFrequency,
              signalStrengths: spectrumData,
              primaryColor: primaryColor,
              onSurface: theme.colorScheme.onSurface,
            ),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class SpectrumPainter extends CustomPainter {
  final FragmentShader shader;
  final double currentFrequency;
  final List<double> signalStrengths;
  final Color primaryColor;
  final Color onSurface;

  SpectrumPainter({
    required this.shader,
    required this.currentFrequency,
    required this.signalStrengths,
    required this.primaryColor,
    required this.onSurface,
  });

  @override
  void paint(Canvas canvas, Size size) {
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, currentFrequency);
    // In a real app, we'd pass the primary color to the shader too
    // shader.setFloat(3, primaryColor.red / 255); ...

    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);

    // Draw scale/marks
    final markPaint = Paint()
      ..color = onSurface.withValues(alpha: 0.2)
      ..strokeWidth = 1;

    for (int i = 0; i <= 10; i++) {
      double x = (i / 10) * size.width;
      canvas.drawLine(Offset(x, size.height), Offset(x, size.height - 10), markPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
