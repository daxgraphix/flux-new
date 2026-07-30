import 'package:flutter/material.dart';

class IntroScreen extends StatefulWidget {
  final VoidCallback onFinish;

  const IntroScreen({super.key, required this.onFinish});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_IntroPage> _pages = const [
    _IntroPage(
      icon: Icons.public,
      title: 'Endless Global Radio',
      subtitle: 'Browse 100,000+ AM/FM stations and podcasts from every country.',
    ),
    _IntroPage(
      icon: Icons.location_on,
      title: 'Tanzania & Nearby',
      subtitle: 'Discover local Tanzania stations and live regional radio near you.',
    ),
    _IntroPage(
      icon: Icons.equalizer,
      title: 'Pro Audio Controls',
      subtitle: 'Use alarm, record and equalizer for the perfect listening experience.',
    ),
    _IntroPage(
      icon: Icons.play_circle,
      title: 'Fast Playback Flow',
      subtitle: 'Instant playback, now playing controls, favorites, and smart discovery.',
    ),
  ];

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      widget.onFinish();
    }
  }

  void _skip() {
    widget.onFinish();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final textColor = theme.colorScheme.onSurface;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: _skip,
                  child: Text(
                    'SKIP',
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pages.length,
                  onPageChanged: (index) => setState(() => _currentPage = index),
                  itemBuilder: (context, index) {
                    final item = _pages[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [primaryColor, primaryColor.withBlue(255)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withValues(alpha: 0.4),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Icon(item.icon, size: 64, color: Colors.white),
                          ),
                          const SizedBox(height: 48),
                          Text(
                            item.title.toUpperCase(),
                            style: TextStyle(
                              color: textColor,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              height: 1.1,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            item.subtitle,
                            style: TextStyle(
                              color: textColor.withValues(alpha: 0.8),
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(right: 8),
                    height: 8,
                    width: _currentPage == index ? 24 : 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index ? primaryColor : primaryColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _nextPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(60),
                  elevation: 8,
                  shadowColor: primaryColor.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: Text(
                  _currentPage == _pages.length - 1 ? 'GET STARTED' : 'CONTINUE',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroPage {
  final IconData icon;
  final String title;
  final String subtitle;

  const _IntroPage({required this.icon, required this.title, required this.subtitle});
}