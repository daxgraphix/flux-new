import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../flux_engine/station_provider.dart';
import '../flux_engine/playback_controller.dart';
import '../flux_hardware/radio_service.dart';
import '../helpers/navigation_helper.dart';
import 'now_playing_screen.dart';
import 'library_screen.dart';
import 'countries_screen.dart';
import 'streema_browser_screen.dart';
import 'podcast_details_screen.dart';
import 'models/podcast.dart';

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
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTablet = MediaQuery.of(context).size.width >= 600;
    
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: isTablet ? 140 : 120,
            floating: true,
            pinned: true,
            elevation: 0,
            backgroundColor: theme.colorScheme.surface,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              title: Text(
                'FLUX',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                  fontSize: 20,
                ),
              ),
              background: Container(color: theme.colorScheme.surface),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.search_rounded),
                onPressed: () => Navigator.of(context).push(NavigationHelper.slideUpRoute(const LibraryScreen())),
              ),
              const SizedBox(width: 8),
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
                  _SectionHeader(
                    title: 'FEATURED STATIONS',
                    onViewAll: () => Navigator.of(context).push(MaterialPageRoute(builder: (c) => const CategoryScreen(title: 'Top Stations', tag: 'top', url: ''))),
                  ),
                  const SizedBox(height: 16),
                  const _FeaturedStations(),
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
                    onViewAll: () => Navigator.of(context).push(MaterialPageRoute(builder: (c) => const LibraryScreen())),
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
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _QuickActionBtn(
            icon: Icons.language_rounded,
            label: 'Browse',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (c) => const StreemaBrowserScreen(url: 'https://streema.com/radios/'))),
            isTablet: isTablet,
          ),
          _QuickActionBtn(
            icon: Icons.favorite_rounded,
            label: 'Favorites',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (c) => const LibraryScreen())),
            isTablet: isTablet,
          ),
          _QuickActionBtn(
            icon: Icons.history_rounded,
            label: 'History',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (c) => const LibraryScreen())),
            isTablet: isTablet,
          ),
          _QuickActionBtn(
            icon: Icons.podcasts_rounded,
            label: 'Podcasts',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (c) => const LibraryScreen())),
            isTablet: isTablet,
          ),
        ],
      ),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        TextButton(
          onPressed: onViewAll,
          child: Text(
            'VIEW ALL',
            style: TextStyle(
              color: theme.primaryColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Quick Action Button ──────────────────────────────────────────────────
class _QuickActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isTablet;

  const _QuickActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isTablet = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = isTablet ? 90.0 : 80.0;
    
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
          ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: theme.primaryColor, size: isTablet ? 32 : 28),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: isTablet ? 13 : 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
        ),
      ),
    );
  }
}

// ─── Featured Stations ────────────────────────────────────────────────────
class _FeaturedStations extends StatelessWidget {
  const _FeaturedStations();

  @override
  Widget build(BuildContext context) {
    return Consumer<StationProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return _buildShimmer(context);
        }
        
        final stations = provider.stations.take(6).toList();
        if (stations.isEmpty) return const SizedBox.shrink();

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.5,
          ),
          itemCount: stations.length,
          itemBuilder: (context, index) => _StationCard(station: stations[index]),
        );
      },
    );
  }

  Widget _buildShimmer(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      highlightColor: Theme.of(context).colorScheme.surface,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.5,
        ),
        itemCount: 4,
        itemBuilder: (context, _) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _StationCard extends StatelessWidget {
  final RadioStation station;
  const _StationCard({required this.station});

  @override
  Widget build(BuildContext context) {
    final playbackController = Provider.of<PlaybackController>(context);
    final isPlaying = playbackController.currentStation?.url == station.url && playbackController.isPlaying;

    return InkWell(
      onTap: () => _playStation(context, station, playbackController),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          image: DecorationImage(
            image: NetworkImage(station.favicon),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.4),
              BlendMode.darken,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isPlaying)
                const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 20)
              else
                const Icon(Icons.play_circle_filled_rounded, color: Colors.white, size: 20),
              const SizedBox(height: 4),
              Text(
                station.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                station.country,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 10,
                ),
                maxLines: 1,
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
    final countries = [
      {'name': 'USA', 'code': 'US', 'icon': '🇺🇸'},
      {'name': 'UK', 'code': 'GB', 'icon': '🇬🇧'},
      {'name': 'Germany', 'code': 'DE', 'icon': '🇩🇪'},
      {'name': 'France', 'code': 'FR', 'icon': '🇫🇷'},
    ];

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: countries.length,
        itemBuilder: (context, index) {
          final c = countries[index];
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: InkWell(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => CategoryScreen(title: c['name']!, tag: c['code']!, url: ''))),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 140,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(c['icon']!, style: const TextStyle(fontSize: 24)),
                    const SizedBox(height: 8),
                    Text(
                      c['name']!,
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FluxImage(
              imageUrl: podcast.image,
              width: 60,
              height: 60,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  podcast.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  podcast.publisher,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: theme.dividerColor),
        ],
      ),
    );
  }
}
