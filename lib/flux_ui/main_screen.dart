import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../flux_engine/station_provider.dart';
import '../flux_engine/playback_controller.dart';
import '../flux_engine/library_manager.dart';
import '../flux_hardware/radio_service.dart';
import '../helpers/navigation_helper.dart';
import 'now_playing_screen.dart';
import 'library_screen.dart';
import 'countries_screen.dart';
import 'streema_browser_screen.dart';
import 'podcast_details_screen.dart';
import 'models/podcast.dart';
import 'flux_search_delegate.dart';

import 'widgets/flux_image.dart';

import '../flux_engine/app_exception.dart';

void _showErrorSnackBar(BuildContext context, AppException error, VoidCallback onRetry) {
  final theme = Theme.of(context);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(error.localizedMessage),
      backgroundColor: theme.colorScheme.error,
      behavior: SnackBarBehavior.floating,
      action: error.canRetry 
        ? SnackBarAction(
            label: 'RETRY',
            textColor: Colors.white,
            onPressed: onRetry,
          )
        : null,
    ),
  );
}

void _playStation(BuildContext context, RadioStation station, PlaybackController playbackController) {
  playbackController.playStation(station).then((_) {
    if (context.mounted) {
      if (playbackController.error != null) {
        _showErrorSnackBar(context, playbackController.error!, () => _playStation(context, station, playbackController));
      } else {
        Navigator.of(context).push(NavigationHelper.slideUpRoute(const NowPlayingScreen()));
      }
    }
  });
}

// ─── Main Screen ──────────────────────────────────────────────────────────
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTablet = MediaQuery.of(context).size.width >= 600;
    
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: isTablet ? 160 : 140,
            floating: true,
            pinned: true,
            elevation: 0,
            stretch: true,
            backgroundColor: theme.colorScheme.surface,
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.blurBackground, StretchMode.zoomBackground],
              titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getGreeting().toUpperCase(),
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'FLUX',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.5,
                      fontSize: 36,
                    ),
                  ),
                ],
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      theme.colorScheme.primary.withValues(alpha: 0.2),
                      theme.colorScheme.surface,
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.search_rounded),
                  onPressed: () => showSearch(
                    context: context,
                    delegate: FluxSearchDelegate(),
                  ),
                ),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildQuickActions(context, isTablet),
                  const SizedBox(height: 32),
                  const _ContinueListeningSection(),
                  const SizedBox(height: 32),
                  const _FavoriteCategoriesSection(),
                  const SizedBox(height: 32),
                  _SectionHeader(
                    title: 'COUNTRIES',
                    onViewAll: () => Navigator.of(context).push(MaterialPageRoute(builder: (c) => const CountriesScreen())),
                  ),
                  const SizedBox(height: 16),
                  const _CountryGrid(),
                  const SizedBox(height: 32),
                  _SectionHeader(
                    title: 'TRENDING PODCASTS',
                    onViewAll: () => Navigator.of(context).push(MaterialPageRoute(builder: (c) => const LibraryScreen(initialIndex: 1))),
                  ),
                  const SizedBox(height: 16),
                  const _TrendingPodcasts(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, bool isTablet) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _QuickActionBtn(
            icon: Icons.explore_rounded,
            label: 'Browse',
            color: Colors.blue,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (c) => const StreemaBrowserScreen(url: 'https://streema.com/radios/'))),
            isTablet: isTablet,
          ),
          _QuickActionBtn(
            icon: Icons.favorite_rounded,
            label: 'Favorites',
            color: Colors.red,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (c) => const LibraryScreen(initialIndex: 3))),
            isTablet: isTablet,
          ),
          _QuickActionBtn(
            icon: Icons.history_rounded,
            label: 'History',
            color: Colors.orange,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (c) => const LibraryScreen(initialIndex: 4))),
            isTablet: isTablet,
          ),
          _QuickActionBtn(
            icon: Icons.podcasts_rounded,
            label: 'Podcasts',
            color: Colors.deepPurple,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (c) => const LibraryScreen(initialIndex: 1))),
            isTablet: isTablet,
          ),
          _QuickActionBtn(
            icon: Icons.public_rounded,
            label: 'Explore',
            color: Colors.green,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (c) => const CountriesScreen())),
            isTablet: isTablet,
          ),
        ],
      ),
    );
  }
}

// ─── Favorite Categories Section ──────────────────────────────────────────
class _ContinueListeningSection extends StatelessWidget {
  const _ContinueListeningSection();

  @override
  Widget build(BuildContext context) {
    final playbackController = Provider.of<PlaybackController>(context, listen: false);

    return Consumer<LibraryManager>(
      builder: (context, libraryManager, _) {
        final inProgress = libraryManager.inProgressEpisodes
            .where((e) => e.duration > 0 && e.lastPosition < e.duration - 5)
            .toList();
        
        final recentStations = libraryManager.recentStations;

        if (inProgress.isEmpty && recentStations.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              title: 'CONTINUE LISTENING',
              onViewAll: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (c) => const LibraryScreen(initialIndex: 4)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ...inProgress.map((episode) => _ContinueListItem(
                        title: episode.title,
                        subtitle: episode.podcastTitle ?? 'Podcast',
                        imageUrl: episode.image,
                        progress: episode.duration > 0 ? episode.lastPosition / episode.duration : 0,
                        onTap: () => playbackController.playEpisode(episode).then((_) {
                          if (context.mounted) {
                            Navigator.of(context).push(NavigationHelper.slideUpRoute(const NowPlayingScreen()));
                          }
                        }),
                        isEpisode: true,
                      )),
                  ...recentStations.map((station) => _ContinueListItem(
                        title: station.name,
                        subtitle: station.country,
                        imageUrl: station.favicon,
                        onTap: () => _playStation(context, station, playbackController),
                        isEpisode: false,
                      )),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ContinueListItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imageUrl;
  final double? progress;
  final VoidCallback onTap;
  final bool isEpisode;

  const _ContinueListItem({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    this.progress,
    required this.onTap,
    required this.isEpisode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 140,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.colorScheme.outline,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      child: FluxImage(
                        imageUrl: imageUrl,
                        width: 140,
                        height: double.infinity,
                      ),
                    ),
                    if (isEpisode && progress != null)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.black26,
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: progress,
                            child: Container(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.4),
                          ],
                        ),
                      ),
                    ),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          isEpisode ? Icons.play_arrow_rounded : Icons.radio_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Favorite Categories Section ──────────────────────────────────────────
class _FavoriteCategoriesSection extends StatelessWidget {
  const _FavoriteCategoriesSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stationProvider = Provider.of<StationProvider>(context, listen: false);
    
    return Consumer<LibraryManager>(
      builder: (context, libraryManager, _) {
        final favorites = libraryManager.favoriteCategories;
        if (favorites.isEmpty) return const SizedBox.shrink();

        final allCategories = stationProvider.categories;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              title: 'MY SHORTCUTS',
              onViewAll: () => Navigator.of(context).push(MaterialPageRoute(builder: (c) => const LibraryScreen())),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: favorites.length,
                  itemBuilder: (context, index) {
                  final title = favorites[index];
                  final catData = allCategories.firstWhere(
                    (c) => c['title'] == title,
                    orElse: () => {'title': title, 'icon': Icons.star, 'color': theme.colorScheme.primary, 'action': () {}},
                  );

                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: InkWell(
                      onTap: () {
                        final action = catData['action'] as Function;
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (ctx) => CategoryScreen(
                            title: title,
                            loadFunction: () => action(),
                          ),
                        ));
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.primary,
                              theme.colorScheme.primary.withValues(alpha: 0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(catData['icon'] as IconData, size: 16, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onViewAll;

  const _SectionHeader({required this.title, required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 20,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
              ),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: onViewAll,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'VIEW ALL',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 16, color: theme.colorScheme.primary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Quick Action Button ──────────────────────────────────────────────────
class _QuickActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isTablet;

  const _QuickActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isTablet = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = isTablet ? 100.0 : 85.0;
    
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.25),
                color.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: isTablet ? 30 : 26),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: isTablet ? 13 : 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Country Grid ─────────────────────────────────────────────────────────
class _CountryGrid extends StatelessWidget {
  const _CountryGrid();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final countries = [
      {'name': 'USA', 'code': 'US', 'icon': '🇺🇸', 'color': Colors.blue},
      {'name': 'UK', 'code': 'GB', 'icon': '🇬🇧', 'color': Colors.red},
      {'name': 'Germany', 'code': 'DE', 'icon': '🇩🇪', 'color': Colors.amber},
      {'name': 'France', 'code': 'FR', 'icon': '🇫🇷', 'color': Colors.blueAccent},
    ];

    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: countries.length,
        itemBuilder: (context, index) {
          final c = countries[index];
          final color = c['color'] as Color;
          final stationProvider = Provider.of<StationProvider>(context, listen: false);
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: InkWell(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => CategoryScreen(
                title: c['name']! as String, 
                loadFunction: () => stationProvider.loadStationsByCountryCode(c['code']! as String),
              ))),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 130,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: theme.colorScheme.outline,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Text(c['icon']! as String, style: const TextStyle(fontSize: 24)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      c['name']! as String,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Trending Podcasts ────────────────────────────────────────────────────
class _TrendingPodcasts extends StatelessWidget {
  const _TrendingPodcasts();

  @override
  Widget build(BuildContext context) {
    return Consumer<StationProvider>(
      builder: (context, provider, _) {
        final podcasts = provider.podcasts.take(5).toList();
        if (podcasts.isEmpty) return const SizedBox.shrink();

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: podcasts.length,
          separatorBuilder: (context, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _PodcastListItem(
            podcast: podcasts[index],
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (c) => PodcastDetailsScreen(podcast: podcasts[index]))),
          ),
        );
      },
    );
  }
}

class _PodcastListItem extends StatelessWidget {
  final Podcast podcast;
  final VoidCallback onTap;

  const _PodcastListItem({required this.podcast, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outline,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Hero(
                    tag: 'podcast_image_${podcast.id}',
                    child: FluxImage(
                      imageUrl: podcast.image,
                      width: 70,
                      height: 70,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      podcast.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      podcast.publisher,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'PODCAST',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(6),
                child: Icon(Icons.play_arrow_rounded, color: theme.colorScheme.primary, size: 30),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
