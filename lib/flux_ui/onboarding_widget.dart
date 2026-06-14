import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';

// ─── Color System ─────────────────────────────────────────────────
const _kBlack = Color(0xFF0A0A0A);
const _kRed = Color(0xFFE53935);
const _kCard = Color(0xFF1C1C1C);

// ─── Animated Splash Screen ───────────────────────────────────────
class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late AnimationController _textController;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;
  late AnimationController _particleController;
  late Animation<double> _particleAnimation;
  late AnimationController _glowController;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
        duration: const Duration(milliseconds: 1600), vsync: this);
    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _logoController,
          curve: const Interval(0.0, 0.65, curve: Curves.elasticOut)),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _logoController,
          curve: const Interval(0.0, 0.4, curve: Curves.easeIn)),
    );

    _textController = AnimationController(
        duration: const Duration(milliseconds: 900), vsync: this);
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _textController, curve: Curves.easeIn));
    _textSlide = Tween<Offset>(
            begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _textController, curve: Curves.easeOut));

    _particleController = AnimationController(
        duration: const Duration(seconds: 3), vsync: this)
      ..repeat();
    _particleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _particleController, curve: Curves.linear));

    _glowController = AnimationController(
        duration: const Duration(milliseconds: 1800), vsync: this)
      ..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _glowController, curve: Curves.easeInOut));

    _startAnimations();
  }

  void _startAnimations() {
    _logoController.forward().then((_) {
      _logoController.animateTo(1.0,
          duration: const Duration(milliseconds: 300));
    });
    Timer(const Duration(milliseconds: 700), () {
      if (mounted) _textController.forward();
    });
    Timer(const Duration(milliseconds: 3000), () {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _particleController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kBlack,
      child: Stack(
        children: [
          // Animated red particles
          AnimatedBuilder(
            animation: _particleAnimation,
            builder: (context, _) => Positioned.fill(
              child: CustomPaint(
                  painter: _ParticlePainter(_particleAnimation.value)),
            ),
          ),
          // Glow under logo
          Center(
            child: AnimatedBuilder(
              animation: _glowAnim,
              builder: (context, _) => Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _kRed.withValues(alpha: 0.18 * _glowAnim.value),
                      blurRadius: 80,
                      spreadRadius: 30,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                AnimatedBuilder(
                  animation: _logoController,
                  builder: (context, _) => Transform.scale(
                    scale: _logoScale.value,
                    child: Opacity(
                      opacity: _logoOpacity.value,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _kRed,
                          boxShadow: [
                            BoxShadow(
                              color: _kRed.withValues(alpha: 0.4),
                              blurRadius: 30,
                              spreadRadius: 6,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.radio_rounded,
                          color: Colors.white,
                          size: 60,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                // Text
                AnimatedBuilder(
                  animation: _textController,
                  builder: (context, _) => SlideTransition(
                    position: _textSlide,
                    child: Opacity(
                      opacity: _textOpacity.value,
                      child: Column(
                        children: [
                          const Text(
                            'FLUX',
                            style: TextStyle(
                              fontSize: 52,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 8,
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'RADIO',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFE53935),
                              letterSpacing: 6,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Global · Live · Unlimited',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 13,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Version
          Positioned(
            bottom: 24,
            right: 20,
            child: Text(
              'v1.0.0',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.25),
                  fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final double animationValue;
  _ParticlePainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 20; i++) {
      final baseX = (i * 41.0) % size.width;
      final baseY = (i * 29.0) % size.height;
      final radius = 1.0 + (i % 3) * 0.8;
      final waveOffset = sin(animationValue * 2 + i) * 12;
      final x = baseX + waveOffset;
      final y =
          (baseY + animationValue * 30) % size.height;
      final opacity = 0.04 + (sin(animationValue * 2 + i * 0.6) + 1) * 0.04;
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()
          ..color =
              const Color(0xFFE53935).withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) =>
      animationValue != old.animationValue;
}

// ─── Onboarding Screen ────────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pc = PageController();
  int _page = 0;

  static const _pages = [
    _OBPage(
      title: 'Welcome to FLUX',
      subtitle: 'Your Global Radio Experience',
      description:
          'Discover 50,000+ live radio stations from every corner of the world.',
      icon: Icons.radio_rounded,
    ),
    _OBPage(
      title: 'Tanzania First',
      subtitle: 'Local Stations Priority',
      description:
          '200+ Tanzanian stations with GPS-based nearby discovery.',
      icon: Icons.location_on_rounded,
    ),
    _OBPage(
      title: 'Smart Features',
      subtitle: 'Advanced Audio Controls',
      description:
          'Sleep timer, recording, equalizer, and instant one-tap playback.',
      icon: Icons.tune_rounded,
    ),
    _OBPage(
      title: 'Your Library',
      subtitle: 'Organize Your Stations',
      description:
          'Favourites, recent plays, and smart recommendations — all in one place.',
      icon: Icons.library_music_rounded,
    ),
  ];

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBlack,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pc,
            onPageChanged: (i) => setState(() => _page = i),
            itemCount: _pages.length,
            itemBuilder: (_, i) => _OnboardingPageWidget(page: _pages[i]),
          ),
          // Dots
          Positioned(
            bottom: 104,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin:
                      const EdgeInsets.symmetric(horizontal: 4),
                  width: _page == i ? 28 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _page == i ? _kRed : Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
          // Nav Buttons
          Positioned(
            bottom: 36,
            left: 24,
            right: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_page > 0)
                  TextButton(
                    onPressed: () => _pc.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut),
                    child: const Text('Back',
                        style:
                            TextStyle(color: Colors.white70, fontSize: 15)),
                  )
                else
                  const SizedBox(width: 60),
                ElevatedButton(
                  onPressed: _page == _pages.length - 1
                      ? widget.onComplete
                      : () => _pc.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 36, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28)),
                    elevation: 0,
                  ),
                  child: Text(
                    _page == _pages.length - 1
                        ? 'Get Started'
                        : 'Next',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          // Skip
          Positioned(
            top: 52,
            right: 20,
            child: TextButton(
              onPressed: widget.onComplete,
              child: const Text('Skip',
                  style:
                      TextStyle(color: Colors.white54, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

class _OBPage {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  const _OBPage(
      {required this.title,
      required this.subtitle,
      required this.description,
      required this.icon});
}

class _OnboardingPageWidget extends StatelessWidget {
  final _OBPage page;
  const _OnboardingPageWidget({required this.page});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kBlack,
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon circle
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _kCard,
              border: Border.all(
                  color: _kRed.withValues(alpha: 0.6), width: 2),
              boxShadow: [
                BoxShadow(
                  color: _kRed.withValues(alpha: 0.25),
                  blurRadius: 40,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: Icon(page.icon, color: _kRed, size: 80),
          ),
          const SizedBox(height: 52),
          Text(
            page.title,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            page.subtitle,
            style: TextStyle(
              fontSize: 16,
              color: _kRed.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Text(
            page.description,
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.65),
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          // Red decorative line
          const SizedBox(height: 32),
          Container(
            width: 48,
            height: 3,
            decoration: BoxDecoration(
              color: _kRed,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}