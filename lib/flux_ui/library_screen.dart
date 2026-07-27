import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../flux_engine/radio_engine.dart';
import '../flux_storage/radio_storage.dart';
import '../flux_hardware/radio_service.dart';
import '../helpers/navigation_helper.dart';
import 'recent_screen.dart';
import 'widgets/flux_image.dart';
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
        engine.searchStations(tag: widget.tag, limit: 500);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: 0,
      ),
      body: Container(
        color: theme.scaffoldBackgroundColor,
        child: Consumer<RadioEngine>(
          builder: (context, engine, child) {
            if (engine.isLoading) {
              return Center(child: CircularProgressIndicator(color: theme.primaryColor));
            }
            if (engine.stations.isEmpty) {
              return Center(
                child: Text(
                  'No stations found',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                  ),
                ),
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
                      return _buildStationItem(context, station, isDark);
                    },
                  );
                }
                return ListView.builder(
                  key: const ValueKey('category_stations_list'),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: engine.stations.take(100).length,
                  itemBuilder: (context, index) {
                    final station = engine.stations[index];
                    return _buildStationItem(context, station, isDark);
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildStationItem(BuildContext context, RadioStation station, bool isDark) {
    final theme = Theme.of(context);
    final engine = context.read<RadioEngine>();
    return Card(
      key: ValueKey('category_station_${station.id}_${station.name}'),
      color: theme.cardColor,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: FluxImage(
          imageUrl: station.favicon,
          width: 40,
          height: 40,
          placeholder: CircleAvatar(
            radius: 20,
            backgroundColor: theme.dividerColor.withValues(alpha: 0.1),
            child: Icon(Icons.radio, color: theme.primaryColor, size: 16),
          ),
          errorWidget: CircleAvatar(
            radius: 20,
            backgroundColor: theme.dividerColor.withValues(alpha: 0.1),
            child: Icon(Icons.radio, color: theme.primaryColor, size: 16),
          ),
        ),
        title: Text(
          station.name,
          style: theme.textTheme.bodyLarge?.copyWith(fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${station.country} • ${station.genre}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
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
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.tabBarTheme.labelColor,
          unselectedLabelColor: theme.tabBarTheme.unselectedLabelColor,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Stations'),
            Tab(text: 'Podcasts'),
            Tab(text: 'Downloads'),
            Tab(text: 'Favorites'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: Container(
        color: theme.scaffoldBackgroundColor,
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
    final theme = Theme.of(context);
    return Consumer<RadioEngine>(
      builder: (context, engine, child) {
        return FutureBuilder<List<Episode>>(
          future: RadioStorage().getDownloadedEpisodes(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: theme.primaryColor));
            }
            
            final downloadedEpisodes = snapshot.data ?? [];
            
            if (downloadedEpisodes.isEmpty) {
              return Center(
                child: Text(
                  'No downloaded episodes yet',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                  ),
                ),
              );
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                final isTablet = constraints.maxWidth >= 600;
                if (isTablet) {
                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
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
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: downloadedEpisodes.length,
                  itemBuilder: (context, index) {
                    return _buildDownloadItem(context, downloadedEpisodes[index], engine);
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildDownloadItem(BuildContext context, Episode episode, RadioEngine engine) {
    final theme = Theme.of(context);
    return Card(
      color: theme.cardColor,
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
          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          'Downloaded • ${(episode.duration / 60).floor()} min',
          style: TextStyle(color: theme.primaryColor, fontSize: 12),
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: theme.iconTheme.color?.withValues(alpha: 0.5)),
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
                            NavigationHelper.slideUpRoute(
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
                            NavigationHelper.slideUpRoute(
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
                            NavigationHelper.slideUpRoute(
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
                            NavigationHelper.slideUpRoute(
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
                            NavigationHelper.slideUpRoute(
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
                            NavigationHelper.slideUpRoute(
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
                            NavigationHelper.slideUpRoute(
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
                            NavigationHelper.slideUpRoute(
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
                            NavigationHelper.slideUpRoute(
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
                            NavigationHelper.slideUpRoute(
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
                            NavigationHelper.slideUpRoute(
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
                            NavigationHelper.slideUpRoute(
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
                            NavigationHelper.slideUpRoute(
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
                            NavigationHelper.slideUpRoute(
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
                            NavigationHelper.slideUpRoute(
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
                            NavigationHelper.slideUpRoute(
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
                            NavigationHelper.slideUpRoute(
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
                            NavigationHelper.slideUpRoute(
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
                            NavigationHelper.slideUpRoute(
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
                            NavigationHelper.slideUpRoute(
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
                            NavigationHelper.slideUpRoute(
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
      color: theme.cardColor,
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
          style: TextStyle(color: theme.textTheme.bodyLarge?.color),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          podcast.publisher,
          style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6)),
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
    final theme = Theme.of(context);
    return Consumer<RadioEngine>(
      builder: (context, engine, child) {
        final favorites = engine.favorites;
        if (favorites.isEmpty) {
          return Center(
            child: Text(
              'No favorites yet',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
              ),
            ),
          );
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = constraints.maxWidth >= 600;
            if (isTablet) {
              return GridView.builder(
                padding: const EdgeInsets.all(16),
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
      color: theme.cardColor,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: FluxImage(
          imageUrl: station.favicon,
          width: 40,
          height: 40,
          errorWidget: CircleAvatar(
            backgroundColor: theme.primaryColor,
            child: Icon(Icons.radio, color: theme.colorScheme.onPrimary),
          ),
        ),
        title: Text(
          station.name,
          style: theme.textTheme.bodyLarge,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${station.country} • ${station.genre}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
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
      color: theme.cardColor,
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
                style: theme.textTheme.bodyLarge?.copyWith(
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
