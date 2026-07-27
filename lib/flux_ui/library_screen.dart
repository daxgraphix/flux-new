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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _searchQuery = "";
          _searchController.clear();
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
              if (_tabController.index >= 2 && _tabController.index <= 4)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Search ${_getTabName(_tabController.index)}...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty 
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
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
            return Column(
              children: [
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
            );
          },
        );
      },
    );
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
        if (engine.isLoading) {
          return Center(child: CircularProgressIndicator(color: theme.primaryColor));
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
                        onPressed: () => engine.searchPodcasts(''),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: engine.podcasts.isEmpty 
                      ? _buildPodcastCategories(engine, isTablet, constraints.maxWidth)
                      : _buildPodcastList(engine, isTablet, constraints.maxWidth),
                  ),
                ],
              ),
            );
          },
        );
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
          onTap: () => engine.searchPodcasts('news'),
        ),
        _CategoryCard(
          title: 'Tech',
          icon: Icons.computer,
          onTap: () => engine.searchPodcasts('tech'),
        ),
        _CategoryCard(
          title: 'Business',
          icon: Icons.business,
          onTap: () => engine.searchPodcasts('business'),
        ),
        _CategoryCard(
          title: 'Comedy',
          icon: Icons.theater_comedy,
          onTap: () => engine.searchPodcasts('comedy'),
        ),
        _CategoryCard(
          title: 'Science',
          icon: Icons.science,
          onTap: () => engine.searchPodcasts('science'),
        ),
        _CategoryCard(
          title: 'Health',
          icon: Icons.health_and_safety,
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
        final favorites = engine.favorites.where((f) => 
          f.name.toLowerCase().contains(_searchQuery) || 
          f.genre.toLowerCase().contains(_searchQuery) ||
          f.country.toLowerCase().contains(_searchQuery)
        ).toList();
        
        if (favorites.isEmpty) {
          return EmptyStateWidget(
            icon: Icons.favorite_border,
            title: _searchQuery.isEmpty ? 'Your favorites are empty' : 'No results found',
            message: _searchQuery.isEmpty 
              ? 'Save your favorite stations to access them quickly here.'
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
            final isTablet = constraints.maxWidth >= 600;
            if (isTablet) {
              return GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: constraints.maxWidth > 900 ? 3 : 2,
                  childAspectRatio: 3.5,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 8,
                ),
                itemCount: favorites.length,
                itemBuilder: (context, index) {
                  return _buildFavoriteItem(context, favorites[index], engine);
                },
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                return _buildFavoriteItem(context, favorites[index], engine);
              },
            );
          },
        );
      },
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
      content = "Are you sure you want to remove all your favorite stations?";
      onClear = () => engine.clearFavorites();
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

class _CategoryCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: theme.primaryColor),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
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
