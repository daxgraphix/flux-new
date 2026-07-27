import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../flux_engine/radio_engine.dart';
import 'main_screen.dart';
import 'library_screen.dart';
import 'settings_screen.dart';
import 'countries_screen.dart';
import 'widgets/enhanced_mini_player.dart';
import 'now_playing_screen.dart';

class NavigationWrapper extends StatefulWidget {
  const NavigationWrapper({super.key});

  @override
  State<NavigationWrapper> createState() => _NavigationWrapperState();
}

class _NavigationWrapperState extends State<NavigationWrapper> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const MainScreen(),
    const LibraryScreen(),
    const CountriesScreen(),
    const SettingsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final engine = Provider.of<RadioEngine>(context);
    final size = MediaQuery.of(context).size;
    final isTablet = size.shortestSide >= 600;

    return Scaffold(
      body: Stack(
        children: [
          Row(
            children: [
              if (isTablet)
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _onItemTapped,
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: const Color(0xFF0A0A0A),
                  selectedIconTheme: const IconThemeData(color: Color(0xFFE53935)),
                  unselectedIconTheme: const IconThemeData(color: Colors.grey),
                  selectedLabelTextStyle: const TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.bold),
                  unselectedLabelTextStyle: const TextStyle(color: Colors.grey),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home_rounded),
                      label: Text('Home'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.library_music_outlined),
                      selectedIcon: Icon(Icons.library_music_rounded),
                      label: Text('Library'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.public_outlined),
                      selectedIcon: Icon(Icons.public_rounded),
                      label: Text('Explore'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings_rounded),
                      label: Text('Settings'),
                    ),
                  ],
                ),
              Expanded(
                child: IndexedStack(
                  index: _selectedIndex,
                  children: _screens,
                ),
              ),
            ],
          ),
          if (engine.currentStation != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: isTablet ? 0 : kBottomNavigationBarHeight,
              child: SafeArea(
                child: EnhancedMiniPlayer(
                  engine: engine,
                  isDark: true,
                  onExpandTap: () => Navigator.of(context).push(
                    _slideRoute(NowPlayingScreen(engine: engine, isDark: true)),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: isTablet
          ? null
          : Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.05),
                    width: 0.5,
                  ),
                ),
              ),
              child: BottomNavigationBar(
                currentIndex: _selectedIndex,
                onTap: _onItemTapped,
                type: BottomNavigationBarType.fixed,
                backgroundColor: const Color(0xFF0A0A0A),
                selectedItemColor: const Color(0xFFE53935),
                unselectedItemColor: Colors.grey,
                showUnselectedLabels: true,
                selectedFontSize: 12,
                unselectedFontSize: 12,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home_outlined),
                    activeIcon: Icon(Icons.home_rounded),
                    label: 'Home',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.library_music_outlined),
                    activeIcon: Icon(Icons.library_music_rounded),
                    label: 'Library',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.public_outlined),
                    activeIcon: Icon(Icons.public_rounded),
                    label: 'Explore',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.settings_outlined),
                    activeIcon: Icon(Icons.settings_rounded),
                    label: 'Settings',
                  ),
                ],
              ),
            ),
    );
  }

  PageRoute _slideRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, anim, secondaryAnim, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 380),
    );
  }
}
