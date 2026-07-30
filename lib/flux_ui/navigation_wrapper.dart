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
    final theme = Theme.of(context);
    final hasPlayer = playbackController.currentStation != null || playbackController.currentEpisode != null;

    return Row(
      children: [
        if (isTablet)
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onItemTapped,
            labelType: NavigationRailLabelType.all,
            backgroundColor: theme.colorScheme.surface,
            selectedIconTheme: IconThemeData(color: theme.colorScheme.primary),
            unselectedIconTheme: IconThemeData(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            selectedLabelTextStyle: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
            unselectedLabelTextStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: Text('Home', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.library_music_outlined),
                selectedIcon: Icon(Icons.library_music_rounded),
                label: Text('Library', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.public_outlined),
                selectedIcon: Icon(Icons.public_rounded),
                label: Text('Explore', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.language_outlined),
                selectedIcon: Icon(Icons.language_rounded),
                label: Text('Streema', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_rounded),
                label: Text('Settings', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5)),
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
                      padding: const EdgeInsets.only(bottom: 72),
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
                  bottom: kBottomNavigationBarHeight + 4,
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
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _buildBody(context, isTablet),
      bottomNavigationBar: isTablet
          ? null
          : NavigationBar(
                selectedIndex: _selectedIndex,
                onDestinationSelected: _onItemTapped,
                height: 65,
                elevation: 0,
                backgroundColor: theme.colorScheme.surface,
                indicatorColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.library_music_outlined),
                    selectedIcon: Icon(Icons.library_music_rounded),
                    label: 'Library',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.public_outlined),
                    selectedIcon: Icon(Icons.public_rounded),
                    label: 'Explore',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.language_outlined),
                    selectedIcon: Icon(Icons.language_rounded),
                    label: 'Streema',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings_rounded),
                    label: 'Settings',
                  ),
                ],
              ),
    );
  }
}
