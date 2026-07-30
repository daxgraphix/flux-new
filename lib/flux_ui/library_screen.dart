import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../flux_engine/radio_engine.dart';
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

class CategoryScreen extends StatefulWidget {
  final String title;
  final String? tag;
  final VoidCallback? loadFunction;

  const CategoryScreen({
    super.key,
    required this.title,
    this.tag,
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
      final engine = Provider.of<RadioEngine>(context, listen: false);
      if (widget.loadFunction != null) {
        widget.loadFunction!();
      } else if (widget.tag != null) {
        engine.searchStations(null, tag: widget.tag, limit: 500);
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
        child: Consumer<RadioEngine>(
          builder: (context, engine, child) {
            if (engine.isLoading) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  return ShimmerListWidget(isGrid: constraints.maxWidth >= 600);
                },
              );
            }
            if (engine.stations.isEmpty) {
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
                    itemCount: engine.stations.take(100).length,
                    itemBuilder: (context, index) {
                      final station = engine.stations[index];
                      return _buildStationItem(context, station);
                    },
                  );
                }
                return ListView.builder(
                  key: const ValueKey('category_stations_list'),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: engine.stations.take(100).length,
                  itemBuilder: (context, index) {
                    final station = engine.stations[index];
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
    final engine = context.read<RadioEngine>();
    return Card(
      key: ValueKey('category_station_${station.id}_${station.name}'),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: FluxImage(
          imageUrl: station.favicon,
          width: 40,
          height: 40,
          placeholder: CircleAvatar(
            radius: 20,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            child: Icon(Icons.radio, color: theme.primaryColor, size: 16),
          ),
          errorWidget: CircleAvatar(
            radius: 20,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            child: Icon(Icons.radio, color: theme.primaryColor, size: 16),
          ),
        ),
        title: Text(
          station.name,
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${station.country} • ${station.genre}',
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: Icon(Icons.play_arrow, color: theme.primaryColor, size: 20),
          onPressed: () async {
            try {
              await engine.playStation(station);
              if (context.mounted) {
                Navigator.of(context).push(NavigationHelper.slideUpRoute(NowPlayingScreen(engine: engine)));
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to play: ${station.name}'),
                    backgroundColor: theme.colorScheme.error,
                    action: SnackBarAction(
                      label: 'Retry',
                      textColor: Colors.white,
                      onPressed: () => engine.playStation(station),
                    ),
                  ),
                );
              }
            }
          },
        ),
        onTap: () {
          final messenger = ScaffoldMessenger.of(context);
          engine.playStation(station).then((_) {
            if (context.mounted) {
              Navigator.of(context).push(NavigationHelper.slideUpRoute(NowPlayingScreen(engine: engine)));
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
                            final engine = Provider.of<RadioEngine>(context, listen: false);
                            if (trimmed.isNotEmpty) {
                              engine.searchPodcasts(trimmed);
                            } else {
                              engine.loadTrendingPodcasts();
                            }
                          }
                        },
                        decoration: InputDecoration(
                          hintText: _searchScope == 'episodes' && _tabController.index == 1
                            ? 'Search episodes...'
                            : 'Search ${_getTabName(_tabController.index)}...',
                          hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                          prefixIcon: Icon(Icons.search, size: 20, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                          suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, size: 20, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = "");
                                },
                              )
                            : null,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        ),
                        style: TextStyle(color: theme.colorScheme.onSurface),
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
    return Consumer<RadioEngine>(
      builder: (context, engine, child) {
        final downloadedEpisodes = engine.downloadedEpisodes.where((e) => 
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
                await engine.loadDownloadedEpisodes();
                setState(() {});
              },
              child: Column(
                children: [
                  FutureBuilder<int>(
                    future: engine.getTotalDownloadSize(),
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
                                '$sizeStr * ${downloadedEpisodes.length} episodes',
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
                                  await engine.deletePlayedEpisodes();
                                  setState(() {});
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
                              return _buildDownloadItem(context, downloadedEpisodes[index], engine);
                            },
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 0),
                            itemCount: downloadedEpisodes.length,
                            itemBuilder: (context, index) {
                              return _buildDownloadItem(context, downloadedEpisodes[index], engine);
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

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    const mb = 1024 * 1024;
    final mbVal = bytes / mb;
    return '${mbVal.toStringAsFixed(1)} MB';
  }

  Widget _buildDownloadItem(BuildContext context, Episode episode, RadioEngine engine) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: FluxImage(
            imageUrl: episode.image,
            width: 50,
            height: 50,
            errorWidget: Icon(Icons.mic, color: theme.primaryColor),
          ),
        ),
        title: Text(
          episode.title,
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          'Downloaded • ${(episode.duration / 60).floor()} min',
          style: TextStyle(color: theme.primaryColor, fontSize: 12),
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: theme.colorScheme.onSurfaceVariant),
          onPressed: () => engine.deleteDownloadedEpisode(episode),
        ),
        onTap: () {
          engine.playEpisode(episode);
          if (context.mounted) {
            Navigator.of(context).push(NavigationHelper.slideUpRoute(NowPlayingScreen(engine: engine)));
          }
        },
      ),
    );
  }

  Widget _buildStationsTab() {
    final theme = Theme.of(context);
    return Consumer<RadioEngine>(
      builder: (context, engine, child) {
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
                                loadFunction: () => engine.loadTrendingStations(),
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
                                loadFunction: () => engine.loadMusicStations(),
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
                                loadFunction: () => engine.loadNewsStations(),
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
                                loadFunction: () => engine.loadSportsStations(),
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
                                loadFunction: () => engine.loadTalkStations(),
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
                                loadFunction: () => engine.loadLiveStations(),
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
                                loadFunction: () => engine.loadGlobalAmFmStations(),
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
                                loadFunction: () => engine.loadTanzaniaStations(),
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
                                loadFunction: () => engine.loadKenyaStations(),
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
                                loadFunction: () => engine.loadUgandaStations(),
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
                                loadFunction: () => engine.loadRwandaStations(),
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
                                loadFunction: () => engine.loadNearbyStations(),
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
                                loadFunction: () => engine.loadTopStations(),
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
    return Consumer<RadioEngine>(
      builder: (context, engine, child) {
        if (engine.isLoading && engine.podcasts.isEmpty) {
          return Center(child: CircularProgressIndicator(color: theme.primaryColor));
        }

        final q = _searchQuery;
        late final List<dynamic> results;
        late final bool isEmpty;

        if (q.isEmpty) {
          if (engine.podcasts.isEmpty && !engine.isLoading) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _searchQuery.isEmpty) {
                engine.loadTrendingPodcasts();
              }
            });
          }
          results = [];
          isEmpty = false;
        } else if (_searchScope == 'episodes') {
          final allEpisodes = [
            ...engine.downloadedEpisodes,
            ...engine.inProgressEpisodes,
            ...engine.episodes,
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
          final filtered = engine.podcasts.where((p) {
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
                            engine.loadTrendingPodcasts();
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
                      ? engine.podcasts.isEmpty 
                          ? _buildPodcastCategories(engine, isTablet, constraints.maxWidth)
                          : _buildPodcastList(engine, isTablet, constraints.maxWidth)
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
                        : _buildSearchResults(results, isTablet, constraints.maxWidth, theme, engine),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSearchResults(List<dynamic> results, bool isTablet, double maxWidth, ThemeData theme, RadioEngine engine) {
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
          ...episodes.map((e) => _buildEpisodeResultItem(e, theme, engine)),
        ],
      );
    } else {
      final podcasts = results.cast<Podcast>();
      return _buildPodcastListItems(podcasts, isTablet, maxWidth);
    }
  }

  Widget _buildEpisodeResultItem(Episode episode, ThemeData theme, RadioEngine engine) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: FluxImage(
            imageUrl: episode.image,
            width: 50,
            height: 50,
            errorWidget: Icon(Icons.mic, color: theme.primaryColor),
          ),
        ),
        title: Text(
          episode.title,
          style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          episode.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
        ),
        trailing: Icon(Icons.play_arrow_rounded, color: theme.primaryColor),
        onTap: () {
          engine.playEpisode(episode);
          if (context.mounted) {
            Navigator.of(context).push(NavigationHelper.slideUpRoute(NowPlayingScreen(engine: engine)));
          }
        },
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

  Widget _buildPodcastCategories(RadioEngine engine, bool isTablet, double maxWidth) {
    return GridView.count(
      crossAxisCount: isTablet ? (maxWidth > 900 ? 4 : 3) : 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _CategoryCard(
          title: 'News',
          icon: Icons.article,
          color: Colors.blue,
          onTap: () => engine.searchPodcasts('news'),
        ),
        _CategoryCard(
          title: 'Tech',
          icon: Icons.computer,
          color: Colors.purple,
          onTap: () => engine.searchPodcasts('tech'),
        ),
        _CategoryCard(
          title: 'AI',
          icon: Icons.psychology,
          color: Colors.teal,
          onTap: () => engine.searchPodcasts('ai'),
        ),
        _CategoryCard(
          title: 'Security',
          icon: Icons.security,
          color: Colors.red,
          onTap: () => engine.searchPodcasts('cyber security'),
        ),
        _CategoryCard(
          title: 'Business',
          icon: Icons.business,
          color: Colors.indigo,
          onTap: () => engine.searchPodcasts('business'),
        ),
        _CategoryCard(
          title: 'Comedy',
          icon: Icons.theater_comedy,
          color: Colors.orange,
          onTap: () => engine.searchPodcasts('comedy'),
        ),
        _CategoryCard(
          title: 'Science',
          icon: Icons.science,
          color: Colors.green,
          onTap: () => engine.searchPodcasts('science'),
        ),
        _CategoryCard(
          title: 'Health',
          icon: Icons.favorite,
          color: Colors.pink,
          onTap: () => engine.searchPodcasts('health'),
        ),
      ],
    );
  }

  Widget _buildPodcastList(RadioEngine engine, bool isTablet, double maxWidth) {
    if (isTablet) {
      return GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: maxWidth > 900 ? 3 : 2,
          childAspectRatio: 3.5,
          crossAxisSpacing: 12,
          mainAxisSpacing: 8,
        ),
        itemCount: engine.podcasts.length,
        itemBuilder: (context, index) {
          return _buildPodcastItem(engine.podcasts[index]);
        },
      );
    }
    return ListView.builder(
      itemCount: engine.podcasts.length,
      itemBuilder: (context, index) {
        return _buildPodcastItem(engine.podcasts[index]);
      },
    );
  }

  Widget _buildPodcastItem(Podcast podcast) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: FluxImage(
            imageUrl: podcast.image,
            width: 50,
            height: 50,
            errorWidget: Icon(Icons.podcasts, color: theme.primaryColor),
          ),
        ),
        title: Text(
          podcast.title,
          style: TextStyle(color: theme.colorScheme.onSurface),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          podcast.publisher,
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
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
    return Consumer<RadioEngine>(
      builder: (context, engine, child) {
        final favoriteStations = engine.favorites.where((f) => 
          f.name.toLowerCase().contains(_searchQuery) || 
          f.genre.toLowerCase().contains(_searchQuery) ||
          f.country.toLowerCase().contains(_searchQuery)
        ).toList();
        
        final bookmarkedEpisodes = engine.bookmarkedEpisodes.where((e) => 
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
                  ...favoriteStations.map((f) => _buildFavoriteItem(context, f, engine)),
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
                  ...bookmarkedEpisodes.map((e) => _buildBookmarkedEpisodeItem(context, e, engine)),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBookmarkedEpisodeItem(BuildContext context, Episode episode, RadioEngine engine) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: FluxImage(
            imageUrl: episode.image,
            width: 48,
            height: 48,
            errorWidget: Icon(Icons.podcasts_rounded, color: theme.primaryColor),
          ),
        ),
        title: Text(
          episode.title,
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          episode.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.play_arrow_rounded, color: theme.primaryColor),
              onPressed: () {
                engine.playEpisode(episode);
                if (context.mounted) {
                  Navigator.of(context).push(NavigationHelper.slideUpRoute(NowPlayingScreen(engine: engine)));
                }
              },
            ),
            IconButton(
              icon: Icon(Icons.bookmark_remove_rounded, color: theme.primaryColor),
              onPressed: () => engine.toggleBookmark(episode),
            ),
          ],
        ),
        onTap: () {
          engine.playEpisode(episode);
          if (context.mounted) {
            Navigator.of(context).push(NavigationHelper.slideUpRoute(NowPlayingScreen(engine: engine)));
          }
        },
      ),
    );
  }

  Widget _buildFavoriteItem(BuildContext context, FavoriteStation favorite, RadioEngine engine) {
    final theme = Theme.of(context);
    final station = favorite.toRadioStation();
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: FluxImage(
          imageUrl: station.favicon,
          width: 40,
          height: 40,
          errorWidget: CircleAvatar(
            backgroundColor: theme.primaryColor,
            child: const Icon(Icons.radio, color: Colors.white),
          ),
        ),
        title: Text(
          station.name,
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${station.country} • ${station.genre}',
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete, color: theme.primaryColor),
          onPressed: () {
            engine.removeFromFavorites(station);
          },
        ),
        onTap: () {
          final messenger = ScaffoldMessenger.of(context);
          engine.playStation(station).then((_) {
            if (context.mounted) {
              Navigator.of(context).push(NavigationHelper.slideUpRoute(NowPlayingScreen(engine: engine)));
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
    final engine = context.read<RadioEngine>();
    final tabIndex = _tabController.index;
    String title = "";
    String content = "";
    VoidCallback onClear = () {};

    if (tabIndex == 2) {
      title = "Clear Downloads";
      content = "Are you sure you want to delete all downloaded episodes?";
      onClear = () => engine.clearAllDownloads();
    } else if (tabIndex == 3) {
      title = "Clear Favorites";
      content = "Are you sure you want to remove all your favorite stations and bookmarked episodes?";
      onClear = () => engine.clearFavoritesAndBookmarks();
    } else if (tabIndex == 4) {
      title = "Clear History";
      content = "Are you sure you want to clear your playback history?";
      onClear = () => engine.clearRecentStations();
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
    return Card(
      elevation: 0,
      color: accentColor.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16 * s)),
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
