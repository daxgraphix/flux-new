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
    // Generate mock spectrum data based on current frequency
    final spectrumData = List.generate(101, (i) {
      final freq = 87.5 + i * 0.2;
      final distance = (freq - currentFrequency).abs();
      if (distance < 0.5) {
        return 80.0 - distance * 20; // Peak at current freq
      }
      return 20.0 + (i % 10) * 3.0; // Noise
    });

    return RepaintBoundary(
      child: ShaderBuilder(
        assetKey: 'shaders/spectrum.frag',
        (context, shader, child) => CustomPaint(
          size: const Size(double.infinity, 100),
          painter: SpectrumPainter(
            shader: shader,
            currentFrequency: currentFrequency,
            signalStrengths: spectrumData,
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class SpectrumPainter extends CustomPainter {
  final FragmentShader shader;
  final double currentFrequency;
  final List<double> signalStrengths;

  SpectrumPainter({
    required this.shader,
    required this.currentFrequency,
    required this.signalStrengths,
  });

  @override
  void paint(Canvas canvas, Size size) {
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, currentFrequency);
    // Pass signal strengths as uniform array, but for simplicity, assume fixed
    // In real, might need texture or multiple uniforms

    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
