import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../flux_engine/playback_controller.dart';
import '../helpers/navigation_helper.dart';
import 'main_screen.dart';
import 'library_screen.dart';
import 'settings_screen.dart';
import 'countries_screen.dart';
import 'streema_browser_screen.dart';
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
    const StreemaBrowserScreen(url: 'https://streema.com/radios/'),
    const SettingsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildBody(BuildContext context, bool isTablet) {
    final playbackController = Provider.of<PlaybackController>(context);
    final hasPlayer = playbackController.currentStation != null || playbackController.currentEpisode != null;

    return Row(
      children: [
        if (isTablet)
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onItemTapped,
            labelType: NavigationRailLabelType.all,
            backgroundColor: Colors.white,
            selectedIconTheme: IconThemeData(color: Theme.of(context).primaryColor),
            unselectedIconTheme: const IconThemeData(color: Colors.grey),
            selectedLabelTextStyle: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold),
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
                icon: Icon(Icons.language_outlined),
                selectedIcon: Icon(Icons.language_rounded),
                label: Text('Streema'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_rounded),
                label: Text('Settings'),
              ),
            ],
          ),
        Expanded(
          child: Stack(
            children: [
              IndexedStack(
                index: _selectedIndex,
                children: _screens.map((screen) {
                  if (!isTablet && hasPlayer) {
                    return Padding(
                      padding: EdgeInsets.only(bottom: 80),
                      child: screen,
                    );
                  }
                  return screen;
                }).toList(),
              ),
              if (!isTablet && hasPlayer)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: kBottomNavigationBarHeight,
                  child: EnhancedMiniPlayer(
                    onExpandTap: () => Navigator.of(context).push(
                      NavigationHelper.slideUpRoute(const NowPlayingScreen()),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.shortestSide >= 600;

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: _buildBody(context, isTablet),
      bottomNavigationBar: isTablet
          ? null
          : BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              type: BottomNavigationBarType.fixed,
              backgroundColor: theme.colorScheme.surface,
              selectedItemColor: theme.primaryColor,
              unselectedItemColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              showUnselectedLabels: true,
              selectedFontSize: 12,
              unselectedFontSize: 12,
              elevation: 8,
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
                  icon: Icon(Icons.language_outlined),
                  activeIcon: Icon(Icons.language_rounded),
                  label: 'Streema',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings_outlined),
                  activeIcon: Icon(Icons.settings_rounded),
                  label: 'Settings'),
              ],
            ),
    );
  }
}
