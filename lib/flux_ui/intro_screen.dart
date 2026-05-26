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
      subtitle: 'Use sleep timer, alarm, record and equalizer for the perfect listening experience.',
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
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: _skip,
                  child: const Text('Skip', style: TextStyle(color: Colors.white70)),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pages.length,
                  onPageChanged: (index) => setState(() => _currentPage = index),
                  itemBuilder: (context, index) {
                    final item = _pages[index];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                         Container(
                           width: 120,
                           height: 120,
                           decoration: BoxDecoration(
                             shape: BoxShape.circle,
                             gradient: const LinearGradient(
                               colors: [Colors.red, Color(0xFFFF6B6B)],
                             ),
                             boxShadow: [
                               BoxShadow(
                                 color: Colors.red.withValues(alpha: 0.3),
                                 blurRadius: 20,
                                 spreadRadius: 5,
                               ),
                             ],
                           ),
                           child: Icon(item.icon, size: 52, color: Colors.white),
                         ),
                        const SizedBox(height: 32),
                        Text(
                          item.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          item.subtitle,
                          style: const TextStyle(color: Colors.white70, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 18 : 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _currentPage == index ? Colors.red : Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _nextPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: Text(
                  _currentPage == _pages.length - 1 ? 'Get Started' : 'Next',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
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
