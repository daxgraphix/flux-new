import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../flux_engine/playback_controller.dart';
import '../flux_engine/station_provider.dart';
import '../flux_engine/library_manager.dart';
import '../flux_engine/download_service.dart';
import '../flux_storage/radio_storage.dart';
import '../flux_hardware/radio_service.dart';
import '../helpers/navigation_helper.dart';
import 'recent_screen.dart';
import 'widgets/flux_image.dart';
import 'widgets/empty_state_widget.dart';
import 'widgets/shimmer_list_widget.dart';
import 'podcast_details_screen.dart';
import 'now_playing_screen.dart';
import 'models/podcast.dart';

import '../flux_engine/app_exception.dart';

String _formatBytes(int bytes, {int decimals = 2}) {
  if (bytes <= 0) return "0 B";
  const suffixes = ["B", "KB", "MB", "GB", "TB"];
  var i = (math.log(bytes) / math.log(1024)).floor();
  return "${(bytes / math.pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}";
}

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

class CategoryScreen extends StatefulWidget {
  final String title;
  final String? tag;
  final String? url;
  final VoidCallback? loadFunction;

  const CategoryScreen({
    super.key,
    required this.title,
    this.tag,
    this.url,
    this.loadFunction,
  });

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final stationProvider = Provider.of<StationProvider>(context, listen: false);
      if (widget.loadFunction != null) {
        widget.loadFunction!();
      } else if (widget.tag != null) {
        stationProvider.loadStationsByTag(widget.tag!, limit: 500);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: 0,
      ),
      body: Container(
        color: theme.colorScheme.surface,
        child: Consumer<StationProvider>(
          builder: (context, stationProvider, child) {
            if (stationProvider.isLoading) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  return ShimmerListWidget(isGrid: constraints.maxWidth >= 600);
                },
              );
            }
            if (stationProvider.stations.isEmpty) {
              return EmptyStateWidget(
                icon: Icons.radio,
                title: 'No stations found',
                message: 'Try adjusting your search or check back later.',
                buttonLabel: 'Go Back',
                onButtonPressed: () => Navigator.of(context).pop(),
              );
            }
            return LayoutBuilder(
              builder: (context, constraints) {
                final isTablet = constraints.maxWidth >= 600;
                if (isTablet) {
                  return GridView.builder(
                    key: const ValueKey('category_stations_grid'),
                    padding: const EdgeInsets.all(16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: constraints.maxWidth > 900 ? 3 : 2,
                      childAspectRatio: 3.5,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: stationProvider.stations.take(100).length,
                    itemBuilder: (context, index) {
                      final station = stationProvider.stations[index];
                      return _buildStationItem(context, station);
                    },
                  );
                }
                return ListView.builder(
                  key: const ValueKey('category_stations_list'),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: stationProvider.stations.take(100).length,
                  itemBuilder: (context, index) {
                    final station = stationProvider.stations[index];
                    return _buildStationItem(context, station);
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildStationItem(BuildContext context, RadioStation station) {
    final theme = Theme.of(context);
    final playbackController = context.read<PlaybackController>();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: FluxImage(
            imageUrl: station.favicon,
            width: 52,
            height: 52,
            placeholder: Container(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Icon(Icons.radio, color: theme.primaryColor, size: 24),
            ),
            errorWidget: Container(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Icon(Icons.radio, color: theme.primaryColor, size: 24),
            ),
          ),
        ),
        title: Text(
          station.name,
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            '${station.country} • ${station.genre}',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: Container(
          decoration: BoxDecoration(
            color: theme.primaryColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(Icons.play_arrow_rounded, color: theme.primaryColor, size: 24),
            onPressed: () => _playStation(context, station, playbackController),
          ),
        ),
        onTap: () => _playStation(context, station, playbackController),
      ),
    );
  }

  void _playStation(BuildContext context, RadioStation station, PlaybackController playbackController) {
    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);
    
    playbackController.playStation(station).then((_) {
      if (context.mounted) {
        if (playbackController.error != null) {
          _showErrorSnackBar(context, playbackController.error!, () => _playStation(context, station, playbackController));
        } else {
          Navigator.of(context).push(NavigationHelper.slideUpRoute(const NowPlayingScreen()));
        }
      }
    }).catchError((e) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to play: ${station.name}'),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    });
  }
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _searchScope = "podcasts";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
_tabController.addListener(() {
  if (!_tabController.indexIsChanging) {
    setState(() {
      _searchQuery = "";
      _searchController.clear();
      _searchScope = "podcasts";
    });
  }
});
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Library', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          if (_tabController.index >= 2 && _tabController.index <= 4)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Clear All',
              onPressed: () => _showClearDialog(context),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_tabController.index >= 2 && _tabController.index <= 4 ? 110 : 48),
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                labelColor: theme.tabBarTheme.labelColor,
                unselectedLabelColor: theme.tabBarTheme.unselectedLabelColor,
                indicatorColor: theme.tabBarTheme.indicatorColor,
                labelStyle: theme.tabBarTheme.labelStyle,
                unselectedLabelStyle: theme.tabBarTheme.unselectedLabelStyle,
                indicatorSize: theme.tabBarTheme.indicatorSize,
                isScrollable: true,
                tabs: const [
                  Tab(text: 'Stations'),
                  Tab(text: 'Podcasts'),
                  Tab(text: 'Downloads'),
                  Tab(text: 'Favorites'),
                  Tab(text: 'History'),
                ],
              ),
              if (_tabController.index >= 1 && _tabController.index <= 4)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      if (_tabController.index == 1)
                        Row(
                          children: [
                            _SearchScopeChip(
                              label: 'Podcasts',
                              selected: _searchScope == 'podcasts',
                              onTap: () => setState(() => _searchScope = 'podcasts'),
                            ),
                            const SizedBox(width: 8),
                            _SearchScopeChip(
                              label: 'Episodes',
                              selected: _searchScope == 'episodes',
                              onTap: () => setState(() => _searchScope = 'episodes'),
                            ),
                          ],
                        ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          final trimmed = value.trim();
                          setState(() => _searchQuery = trimmed.toLowerCase());
                          if (_tabController.index == 1 && _searchScope == 'podcasts') {
                            final stationProvider = Provider.of<StationProvider>(context, listen: false);
                            if (trimmed.isNotEmpty) {
                              stationProvider.searchPodcasts(trimmed);
                            } else {
                              stationProvider.loadTrendingPodcasts();
                            }
                          }
                        },
                        decoration: InputDecoration(
                          hintText: _searchScope == 'episodes' && _tabController.index == 1
                            ? 'Search episodes...'
                            : 'Search ${_getTabName(_tabController.index)}...',
                          hintStyle: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear_rounded, size: 20, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = "");
                                },
                              )
                            : null,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(
                              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(
                              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(
                              color: theme.primaryColor.withValues(alpha: 0.5),
                              width: 1.5,
                            ),
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        ),
                        style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 15),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      body: Container(
        color: theme.colorScheme.surface,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildStationsTab(),
            _buildPodcastsTab(),
            _buildDownloadsTab(),
            _buildFavoritesTab(),
            const RecentScreen(),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadsTab() {
    return Consumer2<DownloadService, PlaybackController>(
      builder: (context, downloadService, playbackController, child) {
        final downloadedEpisodes = downloadService.downloadedEpisodes.where((e) => 
          e.title.toLowerCase().contains(_searchQuery) || 
          e.description.toLowerCase().contains(_searchQuery)
        ).toList();
        
        if (downloadedEpisodes.isEmpty) {
          return EmptyStateWidget(
            icon: Icons.download_for_offline,
            title: _searchQuery.isEmpty ? 'No downloads' : 'No results found',
            message: _searchQuery.isEmpty 
              ? 'Episodes you download will appear here for offline listening.'
              : 'Try a different search term.',
            buttonLabel: _searchQuery.isEmpty ? 'Browse Podcasts' : 'Clear Search',
            onButtonPressed: () {
              if (_searchQuery.isEmpty) {
                _tabController.animateTo(1);
              } else {
                _searchController.clear();
                setState(() => _searchQuery = "");
              }
            },
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = constraints.maxWidth >= 600;
            return RefreshIndicator(
              onRefresh: () async {
                await downloadService.loadDownloadedEpisodes();
              },
              child: Column(
                children: [
                  FutureBuilder<int>(
                    future: downloadService.getTotalDownloadSize(),
                    builder: (context, snapshot) {
                      final size = snapshot.data ?? 0;
                      final sizeStr = _formatBytes(size);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            Icon(Icons.storage_rounded, size: 16, color: Theme.of(context).primaryColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '$sizeStr • ${downloadedEpisodes.length} episodes',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.cleaning_services_rounded, size: 18, color: Theme.of(context).primaryColor),
                              onPressed: () async {
                                final playedCount = downloadedEpisodes.where((e) => e.lastPosition > 0 && e.duration > 0 && e.lastPosition >= e.duration).length;
                                if (playedCount == 0) {
                                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No played episodes to delete')));
                                  return;
                                }
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Played Episodes'),
                                    content: Text('Delete $playedCount played episodes from downloads?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                                    ],
                                  ),
                                );
                                if (confirm == true && context.mounted) {
                                  await downloadService.deletePlayedEpisodes();
                                }
                              },
                              tooltip: 'Delete played episodes',
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  Expanded(
                    child: isTablet
                        ? GridView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: constraints.maxWidth > 900 ? 3 : 2,
                              childAspectRatio: 3.5,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 8,
                            ),
                            itemCount: downloadedEpisodes.length,
                            itemBuilder: (context, index) {
                              return _buildDownloadItem(context, downloadedEpisodes[index], downloadService, playbackController);
                            },
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 0),
                            itemCount: downloadedEpisodes.length,
                            itemBuilder: (context, index) {
                              return _buildDownloadItem(context, downloadedEpisodes[index], downloadService, playbackController);
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDownloadItem(BuildContext context, Episode episode, DownloadService downloadService, PlaybackController playbackController) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: FluxImage(
            imageUrl: episode.image,
            width: 52,
            height: 52,
            errorWidget: Container(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Icon(Icons.mic, color: theme.primaryColor, size: 28),
            ),
          ),
        ),
        title: Text(
          episode.title,
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            'Downloaded • ${(episode.duration / 60).floor()} min',
            style: TextStyle(
              color: theme.primaryColor, 
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.offline_pin_rounded, color: Colors.green, size: 20),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.onSurfaceVariant),
              onPressed: () => downloadService.deleteDownloadedEpisode(episode),
            ),
          ],
        ),
        onTap: () => _playEpisode(context, episode, playbackController),
      ),
    );
  }

  Widget _buildStationsTab() {
    final theme = Theme.of(context);
    return Consumer<StationProvider>(
      builder: (context, stationProvider, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = constraints.maxWidth >= 600;
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Browse Stations',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: isTablet ? (constraints.maxWidth > 900 ? 4 : 3) : 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      children: [
                        _CategoryCard(
                          title: 'Trending',
                          icon: Icons.trending_up,
                          isTablet: isTablet,
                          onTap: () => Navigator.push(
                            context,
                            NavigationHelper.slideRightRoute(
                              CategoryScreen(
                                title: 'Trending Stations',
                                loadFunction: () => stationProvider.loadTrendingStations(),
                              ),
                            ),
                          ),
                        ),
                        _CategoryCard(
                          title: 'Music',
                          icon: Icons.music_note,
                          isTablet: isTablet,
                          onTap: () => Navigator.push(
                            context,
                            NavigationHelper.slideRightRoute(
                              CategoryScreen(
                                title: 'Music Stations',
                                loadFunction: () => stationProvider.loadMusicStations(),
                              ),
                            ),
                          ),
                        ),
                        _CategoryCard(
                          title: 'News',
                          icon: Icons.article,
                          isTablet: isTablet,
                          onTap: () => Navigator.push(
                            context,
                            NavigationHelper.slideRightRoute(
                              CategoryScreen(
                                title: 'News Stations',
                                loadFunction: () => stationProvider.loadNewsStations(),
                              ),
                            ),
                          ),
                        ),
                        _CategoryCard(
                          title: 'Sports',
                          icon: Icons.sports_soccer,
                          isTablet: isTablet,
                          onTap: () => Navigator.push(
                            context,
                            NavigationHelper.slideRightRoute(
                              CategoryScreen(
                                title: 'Sports Stations',
                                loadFunction: () => stationProvider.loadSportsStations(),
                              ),
                            ),
                          ),
                        ),
                        _CategoryCard(
                          title: 'Talk',
                          icon: Icons.mic,
                          isTablet: isTablet,
                          onTap: () => Navigator.push(
                            context,
                            NavigationHelper.slideRightRoute(
                              CategoryScreen(
                                title: 'Talk Stations',
                                loadFunction: () => stationProvider.loadTalkStations(),
                              ),
                            ),
                          ),
                        ),
                        _CategoryCard(
                          title: 'Live',
                          icon: Icons.wifi,
                          isTablet: isTablet,
                          onTap: () => Navigator.push(
                            context,
                            NavigationHelper.slideRightRoute(
                              CategoryScreen(
                                title: 'Live Stations',
                                loadFunction: () => stationProvider.loadLiveStations(),
                              ),
                            ),
                          ),
                        ),
                        _CategoryCard(
                          title: 'Global AM/FM',
                          icon: Icons.public,
                          isTablet: isTablet,
                          onTap: () => Navigator.push(
                            context,
                            NavigationHelper.slideRightRoute(
                              CategoryScreen(
                                title: 'Global AM/FM Stations',
                                loadFunction: () => stationProvider.loadGlobalAmFmStations(),
                              ),
                            ),
                          ),
                        ),
                        _CategoryCard(
                          title: 'Tanzania',
                          icon: Icons.location_on,
                          isTablet: isTablet,
                          onTap: () => Navigator.push(
                            context,
                            NavigationHelper.slideRightRoute(
                              CategoryScreen(
                                title: 'Tanzania Stations',
                                loadFunction: () => stationProvider.loadTanzaniaStations(),
                              ),
                            ),
                          ),
                        ),
                        _CategoryCard(
                          title: 'Kenya',
                          icon: Icons.location_on,
                          isTablet: isTablet,
                          onTap: () => Navigator.push(
                            context,
                            NavigationHelper.slideRightRoute(
                              CategoryScreen(
                                title: 'Kenya Stations',
                                loadFunction: () => stationProvider.loadKenyaStations(),
                              ),
                            ),
                          ),
                        ),
                        _CategoryCard(
                          title: 'Uganda',
                          icon: Icons.location_on,
                          isTablet: isTablet,
                          onTap: () => Navigator.push(
                            context,
                            NavigationHelper.slideRightRoute(
                              CategoryScreen(
                                title: 'Uganda Stations',
                                loadFunction: () => stationProvider.loadUgandaStations(),
                              ),
                            ),
                          ),
                        ),
                        _CategoryCard(
                          title: 'Rwanda',
                          icon: Icons.location_on,
                          isTablet: isTablet,
                          onTap: () => Navigator.push(
                            context,
                            NavigationHelper.slideRightRoute(
                              CategoryScreen(
                                title: 'Rwanda Stations',
                                loadFunction: () => stationProvider.loadRwandaStations(),
                              ),
                            ),
                          ),
                        ),
                        _CategoryCard(
                          title: 'Nearby',
                          icon: Icons.my_location,
                          isTablet: isTablet,
                          onTap: () => Navigator.push(
                            context,
                            NavigationHelper.slideRightRoute(
                              CategoryScreen(
                                title: 'Nearby Stations',
                                loadFunction: () => stationProvider.loadTanzaniaStations(), // Nearby usually Tanzania for now
                              ),
                            ),
                          ),
                        ),
                        _CategoryCard(
                          title: 'All Stations',
                          icon: Icons.radio,
                          isTablet: isTablet,
                          onTap: () => Navigator.push(
                            context,
                            NavigationHelper.slideRightRoute(
                              CategoryScreen(
                                title: 'All Stations',
                                loadFunction: () => stationProvider.loadTopStations(),
                              ),
                            ),
                          ),
                        ),
                        _CategoryCard(
                          title: 'Classical',
                          icon: Icons.piano,
                          isTablet: isTablet,
                          onTap: () => Navigator.push(
                            context,
                            NavigationHelper.slideRightRoute(
                              CategoryScreen(
                                title: 'Classical Music',
                                tag: 'classical',
                              ),
                            ),
                          ),
                        ),
                        _CategoryCard(
                          title: 'Jazz',
                          icon: Icons.music_note,
                          isTablet: isTablet,
                          onTap: () => Navigator.push(
                            context,
                            NavigationHelper.slideRightRoute(
                              CategoryScreen(
                                title: 'Jazz Music',
                                tag: 'jazz',
                              ),
                            ),
                          ),
                        ),
                        _CategoryCard(
                          title: 'Rock',
                          icon: Icons.album,
                          onTap: () => Navigator.push(
                            context,
                            NavigationHelper.slideRightRoute(
                              CategoryScreen(
                                title: 'Rock Music',
                                tag: 'rock',
                              ),
                            ),
                          ),
                        ),
                        _CategoryCard(
                          title: 'Pop',
                          icon: Icons.queue_music,
                          isTablet: isTablet,
                          onTap: () => Navigator.push(
                            context,
                            NavigationHelper.slideRightRoute(
                              CategoryScreen(
                                title: 'Pop Music',
                                tag: 'pop',
                              ),
                            ),
                          ),
                        ),
                        _CategoryCard(
                          title: 'Electronic',
                          icon: Icons.surround_sound,
                          isTablet: isTablet,
                          onTap: () => Navigator.push(
                            context,
                            NavigationHelper.slideRightRoute(
                              CategoryScreen(
                                title: 'Electronic Music',
                                tag: 'electronic',
                              ),
                            ),
                          ),
                        ),
                        _CategoryCard(
                          title: 'Reggae',
                          icon: Icons.grass,
                          isTablet: isTablet,
                          onTap: () => Navigator.push(
                            context,
                            NavigationHelper.slideRightRoute(
                              CategoryScreen(
                                title: 'Reggae Music',
                                tag: 'reggae',
                              ),
                            ),
                          ),
                        ),
                        _CategoryCard(
                          title: 'Blues',
                          icon: Icons.mic_external_on,
                          isTablet: isTablet,
                          onTap: () => Navigator.push(
                            context,
                            NavigationHelper.slideRightRoute(
                              CategoryScreen(
                                title: 'Blues Music',
                                tag: 'blues',
                              ),
                            ),
                          ),
                        ),
                        _CategoryCard(
                          title: 'Country',
                          icon: Icons.agriculture,
                          isTablet: isTablet,
                          onTap: () => Navigator.push(
                            context,
                            NavigationHelper.slideRightRoute(
                              CategoryScreen(
                                title: 'Country Music',
                                tag: 'country',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPodcastsTab() {
    final theme = Theme.of(context);
    return Consumer2<StationProvider, PlaybackController>(
      builder: (context, stationProvider, playbackController, child) {
        if (stationProvider.isLoading && stationProvider.podcasts.isEmpty) {
          return Center(child: CircularProgressIndicator(color: theme.primaryColor));
        }

        final q = _searchQuery;
        late final List<dynamic> results;
        late final bool isEmpty;

        if (q.isEmpty) {
          if (stationProvider.podcasts.isEmpty && !stationProvider.isLoading) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _searchQuery.isEmpty) {
                stationProvider.loadTrendingPodcasts();
              }
            });
          }
          results = [];
          isEmpty = false;
        } else if (_searchScope == 'episodes') {
          // Note: episodes are usually loaded per podcast, so global search for episodes might need a separate service logic
          // For now, filtering what's already loaded in stationProvider and downloaded/inProgress
          final allEpisodes = [
            ...stationProvider.episodes,
          ];
          final unique = <String, Episode>{};
          for (final e in allEpisodes) {
            unique[e.id] = e;
          }
          results = unique.values.where((e) {
            return e.title.toLowerCase().contains(q) ||
                e.description.toLowerCase().contains(q);
          }).toList();
          isEmpty = results.isEmpty;
        } else {
          final filtered = stationProvider.podcasts.where((p) {
            return p.title.toLowerCase().contains(q) ||
                p.publisher.toLowerCase().contains(q) ||
                p.description.toLowerCase().contains(q);
          }).toList();
          results = filtered;
          isEmpty = filtered.isEmpty;
        }
        
        return LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = constraints.maxWidth >= 600;
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Podcasts',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: theme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.refresh, color: theme.iconTheme.color?.withValues(alpha: 0.7)),
                        onPressed: () {
                          if (_searchQuery.isEmpty) {
                            stationProvider.loadTrendingPodcasts();
                          } else {
                            _searchController.clear();
                            setState(() => _searchQuery = "");
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  Expanded(
                    child: q.isEmpty
                      ? stationProvider.podcasts.isEmpty 
                          ? _buildPodcastCategories(stationProvider, isTablet, constraints.maxWidth)
                          : _buildPodcastList(stationProvider, isTablet, constraints.maxWidth)
                      : isEmpty
                        ? EmptyStateWidget(
                            icon: _searchScope == 'episodes' ? Icons.mic_off : Icons.podcasts,
                            title: 'No results found',
                            message: 'Try a different search term.',
                            buttonLabel: 'Clear Search',
                            onButtonPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = "");
                            },
                          )
                        : _buildSearchResults(results, isTablet, constraints.maxWidth, theme, playbackController),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSearchResults(List<dynamic> results, bool isTablet, double maxWidth, ThemeData theme, PlaybackController playbackController) {
    if (_searchScope == 'episodes') {
      final episodes = results.cast<Episode>();
      return ListView(
        shrinkWrap: true,
        children: [
          Text(
            '${episodes.length} Episode${episodes.length == 1 ? '' : 's'}',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...episodes.map((e) => _buildEpisodeResultItem(e, theme, playbackController)),
        ],
      );
    } else {
      final podcasts = results.cast<Podcast>();
      return _buildPodcastListItems(podcasts, isTablet, maxWidth);
    }
  }

  Widget _buildEpisodeResultItem(Episode episode, ThemeData theme, PlaybackController playbackController) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: FluxImage(
            imageUrl: episode.image,
            width: 52,
            height: 52,
            errorWidget: Container(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Icon(Icons.mic_rounded, color: theme.primaryColor, size: 28),
            ),
          ),
        ),
        title: Text(
          episode.title,
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            episode.description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (episode.isDownloaded)
              const Padding(
                padding: EdgeInsets.only(right: 8.0),
                child: Icon(Icons.offline_pin_rounded, color: Colors.green, size: 20),
              ),
            Container(
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.play_arrow_rounded, color: theme.primaryColor, size: 28),
            ),
          ],
        ),
        onTap: () => _playEpisode(context, episode, playbackController),
      ),
    );
  }

  Widget _buildPodcastListItems(List<Podcast> podcasts, bool isTablet, double maxWidth) {
    if (isTablet) {
      return GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: maxWidth > 900 ? 3 : 2,
          childAspectRatio: 3.5,
          crossAxisSpacing: 12,
          mainAxisSpacing: 8,
        ),
        itemCount: podcasts.length,
        itemBuilder: (context, index) {
          return _buildPodcastItem(podcasts[index]);
        },
      );
    }
    return ListView.builder(
      itemCount: podcasts.length,
      itemBuilder: (context, index) {
        return _buildPodcastItem(podcasts[index]);
      },
    );
  }

  Widget _buildPodcastCategories(StationProvider stationProvider, bool isTablet, double maxWidth) {
    return GridView.count(
      crossAxisCount: isTablet ? (maxWidth > 900 ? 4 : 3) : 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _CategoryCard(
          title: 'News',
          icon: Icons.article,
          color: Colors.blue,
          onTap: () => stationProvider.searchPodcasts('news'),
        ),
        _CategoryCard(
          title: 'Tech',
          icon: Icons.computer,
          color: Colors.purple,
          onTap: () => stationProvider.searchPodcasts('tech'),
        ),
        _CategoryCard(
          title: 'AI',
          icon: Icons.psychology,
          color: Colors.teal,
          onTap: () => stationProvider.searchPodcasts('ai'),
        ),
        _CategoryCard(
          title: 'Security',
          icon: Icons.security,
          color: Colors.red,
          onTap: () => stationProvider.searchPodcasts('cyber security'),
        ),
        _CategoryCard(
          title: 'Business',
          icon: Icons.business,
          color: Colors.indigo,
          onTap: () => stationProvider.searchPodcasts('business'),
        ),
        _CategoryCard(
          title: 'Comedy',
          icon: Icons.theater_comedy,
          color: Colors.orange,
          onTap: () => stationProvider.searchPodcasts('comedy'),
        ),
        _CategoryCard(
          title: 'Science',
          icon: Icons.science,
          color: Colors.green,
          onTap: () => stationProvider.searchPodcasts('science'),
        ),
        _CategoryCard(
          title: 'Health',
          icon: Icons.favorite,
          color: Colors.pink,
          onTap: () => stationProvider.searchPodcasts('health'),
        ),
      ],
    );
  }

  Widget _buildPodcastList(StationProvider stationProvider, bool isTablet, double maxWidth) {
    if (isTablet) {
      return GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: maxWidth > 900 ? 3 : 2,
          childAspectRatio: 3.5,
          crossAxisSpacing: 12,
          mainAxisSpacing: 8,
        ),
        itemCount: stationProvider.podcasts.length,
        itemBuilder: (context, index) {
          return _buildPodcastItem(stationProvider.podcasts[index]);
        },
      );
    }
    return ListView.builder(
      itemCount: stationProvider.podcasts.length,
      itemBuilder: (context, index) {
        return _buildPodcastItem(stationProvider.podcasts[index]);
      },
    );
  }

  Widget _buildPodcastItem(Podcast podcast) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: FluxImage(
            imageUrl: podcast.image,
            width: 52,
            height: 52,
            errorWidget: Container(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Icon(Icons.podcasts_rounded, color: theme.primaryColor, size: 24),
            ),
          ),
        ),
        title: Text(
          podcast.title,
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            podcast.publisher,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
        onTap: () {
          Navigator.push(
            context,
            NavigationHelper.slideUpRoute(PodcastDetailsScreen(podcast: podcast)),
          );
        },
      ),
    );
  }

  Widget _buildFavoritesTab() {
    return Consumer2<LibraryManager, PlaybackController>(
      builder: (context, libraryManager, playbackController, child) {
        final favoriteStations = libraryManager.favorites.where((f) => 
          f.name.toLowerCase().contains(_searchQuery) || 
          f.genre.toLowerCase().contains(_searchQuery) ||
          f.country.toLowerCase().contains(_searchQuery)
        ).toList();
        
        final bookmarkedEpisodes = libraryManager.bookmarkedEpisodes.where((e) => 
          e.title.toLowerCase().contains(_searchQuery) || 
          e.description.toLowerCase().contains(_searchQuery)
        ).toList();
        
        final hasStations = favoriteStations.isNotEmpty;
        final hasEpisodes = bookmarkedEpisodes.isNotEmpty;
        final isEmpty = !hasStations && !hasEpisodes;
        
        if (isEmpty) {
          return EmptyStateWidget(
            icon: Icons.favorite_border,
            title: _searchQuery.isEmpty ? 'No favorites yet' : 'No results found',
            message: _searchQuery.isEmpty 
              ? 'Bookmark episodes and save stations to access them quickly here.'
              : 'Try a different search term.',
            buttonLabel: _searchQuery.isEmpty ? 'Discover Stations' : 'Clear Search',
            onButtonPressed: () {
              if (_searchQuery.isEmpty) {
                _tabController.animateTo(0);
              } else {
                _searchController.clear();
                setState(() => _searchQuery = "");
              }
            },
          );
        }
        
        return LayoutBuilder(
          builder: (context, constraints) {
            final theme = Theme.of(context);
            return ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                if (hasStations) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.radio_rounded, size: 18, color: theme.primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          'Favorite Stations',
                          style: TextStyle(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${favoriteStations.length}',
                            style: TextStyle(
                              color: theme.primaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...favoriteStations.map((f) => _buildFavoriteItem(context, f, libraryManager, playbackController)),
                  if (hasEpisodes) const SizedBox(height: 16),
                ],
                if (hasEpisodes) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.bookmark_rounded, size: 18, color: theme.primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          'Bookmarked Episodes',
                          style: TextStyle(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${bookmarkedEpisodes.length}',
                            style: TextStyle(
                              color: theme.primaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...bookmarkedEpisodes.map((e) => _buildBookmarkedEpisodeItem(context, e, libraryManager, playbackController)),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBookmarkedEpisodeItem(BuildContext context, Episode episode, LibraryManager libraryManager, PlaybackController playbackController) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: FluxImage(
            imageUrl: episode.image,
            width: 52,
            height: 52,
            errorWidget: Container(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Icon(Icons.mic_rounded, color: theme.primaryColor, size: 28),
            ),
          ),
        ),
        title: Text(
          episode.title,
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            episode.description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (episode.isDownloaded)
              const Padding(
                padding: EdgeInsets.only(right: 8.0),
                child: Icon(Icons.offline_pin_rounded, color: Colors.green, size: 20),
              ),
            Container(
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(Icons.play_arrow_rounded, color: theme.primaryColor, size: 28),
                onPressed: () => _playEpisode(context, episode, playbackController),
              ),
            ),
            IconButton(
              icon: Icon(Icons.bookmark_remove_rounded, color: theme.primaryColor, size: 24),
              onPressed: () => libraryManager.toggleBookmark(episode),
            ),
          ],
        ),
        onTap: () => _playEpisode(context, episode, playbackController),
      ),
    );
  }

  void _playEpisode(BuildContext context, Episode episode, PlaybackController playbackController) {
    playbackController.playEpisode(episode).then((_) {
      if (context.mounted) {
        if (playbackController.error != null) {
          _showErrorSnackBar(context, playbackController.error!, () => _playEpisode(context, episode, playbackController));
        } else {
          Navigator.of(context).push(NavigationHelper.slideUpRoute(const NowPlayingScreen()));
        }
      }
    });
  }

  Widget _buildFavoriteItem(BuildContext context, FavoriteStation favorite, LibraryManager libraryManager, PlaybackController playbackController) {
    final theme = Theme.of(context);
    final station = favorite.toRadioStation();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: FluxImage(
            imageUrl: station.favicon,
            width: 52,
            height: 52,
            errorWidget: Container(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Icon(Icons.radio_rounded, color: theme.primaryColor, size: 28),
            ),
          ),
        ),
        title: Text(
          station.name,
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            '${station.country} • ${station.genre}',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(Icons.play_arrow_rounded, color: theme.primaryColor, size: 28),
                onPressed: () {
                  final messenger = ScaffoldMessenger.of(context);
                  playbackController.playStation(station).then((_) {
                    if (context.mounted) {
                      Navigator.of(context).push(NavigationHelper.slideUpRoute(const NowPlayingScreen()));
                    }
                  }).catchError((e) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Failed to play: ${station.name}'),
                        backgroundColor: theme.colorScheme.error,
                      ),
                    );
                  });
                },
              ),
            ),
            IconButton(
              icon: Icon(Icons.favorite_rounded, color: theme.primaryColor, size: 24),
              onPressed: () {
                libraryManager.toggleFavorite(station);
              },
            ),
          ],
        ),
        onTap: () {
          final messenger = ScaffoldMessenger.of(context);
          playbackController.playStation(station).then((_) {
            if (context.mounted) {
              Navigator.of(context).push(NavigationHelper.slideUpRoute(const NowPlayingScreen()));
            }
          }).catchError((e) {
            messenger.showSnackBar(
              SnackBar(
                content: Text('Failed to play: ${station.name}'),
                backgroundColor: theme.colorScheme.error,
              ),
            );
          });
        },
      ),
    );
  }
  void _showClearDialog(BuildContext context) {
    final libraryManager = context.read<LibraryManager>();
    final downloadService = context.read<DownloadService>();
    final tabIndex = _tabController.index;
    String title = "";
    String content = "";
    VoidCallback onClear = () {};

    if (tabIndex == 2) {
      title = "Clear Downloads";
      content = "Are you sure you want to delete all downloaded episodes?";
      onClear = () => downloadService.clearAllDownloads();
    } else if (tabIndex == 3) {
      title = "Clear Favorites";
      content = "Are you sure you want to remove all your favorite stations and bookmarked episodes?";
      onClear = () => libraryManager.clearFavoritesAndBookmarks();
    } else if (tabIndex == 4) {
      title = "Clear History";
      content = "Are you sure you want to clear your playback history?";
      onClear = () => libraryManager.clearRecentStations();
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              onClear();
              Navigator.pop(context);
            },
            child: const Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _getTabName(int index) {
    switch (index) {
      case 2: return "Downloads";
      case 3: return "Favorites";
      case 4: return "History";
      default: return "";
    }
  }
}

class _SearchScopeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SearchScopeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: theme.primaryColor.withValues(alpha: 0.2),
      checkmarkColor: theme.primaryColor,
      labelStyle: TextStyle(
        color: selected ? theme.primaryColor : theme.colorScheme.onSurfaceVariant,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        fontSize: 12,
      ),
      side: BorderSide(
        color: selected ? theme.primaryColor : theme.dividerColor,
        width: 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final bool isTablet;

  const _CategoryCard({
    required this.title,
    required this.icon,
    required this.onTap,
    this.color,
    this.isTablet = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = color ?? theme.primaryColor;
    final s = isTablet ? 1.2 : 1.0;
    return Container(
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16 * s),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16 * s),
        child: Padding(
          padding: EdgeInsets.all(16 * s),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40 * s, color: accentColor),
              SizedBox(height: 12 * s),
              Text(
                title,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14 * s,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
