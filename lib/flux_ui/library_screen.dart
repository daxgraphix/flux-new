import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../flux_engine/radio_engine.dart';
import 'recent_screen.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: const Color(0xFF0A0A0A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        color: const Color(0xFF0A0A0A),
        child: Consumer<RadioEngine>(
          builder: (context, engine, child) {
            if (engine.isLoading) {
              return const Center(child: CircularProgressIndicator(color: Colors.red));
            }
            if (engine.stations.isEmpty) {
              return Center(
                child: Text(
                  'No stations found',
                  style: TextStyle(color: isDark ? Colors.white70 : Colors.black.withValues(alpha: 0.7)),
                ),
              );
            }
            return ListView.builder(
              key: const ValueKey('category_stations_list'),
              shrinkWrap: true,
              itemCount: engine.stations.take(100).length, // Limit for performance
              itemExtent: 80, // Fixed height for better performance
              itemBuilder: (context, index) {
                final station = engine.stations[index];
                return Card(
                  key: ValueKey('category_station_${station.name}_$index'),
                  color: const Color(0xFF1C1C1C),
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundColor: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
                      child: station.favicon.isNotEmpty
                          ? FadeInImage.assetNetwork(
                              placeholder: '',
                              image: station.favicon,
                              fit: BoxFit.cover,
                              width: 40,
                              height: 40,
                              imageErrorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.radio, color: Colors.red, size: 16),
                            )
                          : const Icon(Icons.radio, color: Colors.red, size: 16),
                    ),
                    title: Text(
                      station.name,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${station.country} • ${station.genre}',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.play_arrow, color: Colors.red, size: 20),
                      onPressed: () async {
                        try {
                          await engine.playStation(station);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to play: ${station.name}'),
                                backgroundColor: Colors.red,
                                action: SnackBarAction(
                                  label: 'Retry',
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
                      engine.playStation(station).catchError((e) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Failed to play: ${station.name}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      });
                    },
                  ),
                );
              },
            );
          },
        ),
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
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Library', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        backgroundColor: const Color(0xFF0A0A0A),
        foregroundColor: Colors.white,
        elevation: 0,
bottom: TabBar(
        controller: _tabController,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Stations'),
            Tab(text: 'Podcasts'),
            Tab(text: 'Favorites'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: Container(
        color: const Color(0xFF0A0A0A),
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildStationsTab(),
            _buildPodcastsTab(),
            _buildFavoritesTab(),
            const RecentScreen(),
          ],
        ),
      ),
    );
  }

  Widget _buildStationsTab() {
    return Consumer<RadioEngine>(
      builder: (context, engine, child) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Browse Stations',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    _CategoryCard(
                      title: 'Trending',
                      icon: Icons.trending_up,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CategoryScreen(
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
                        MaterialPageRoute(
                          builder: (context) => CategoryScreen(
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
                        MaterialPageRoute(
                          builder: (context) => CategoryScreen(
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
                        MaterialPageRoute(
                          builder: (context) => CategoryScreen(
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
                        MaterialPageRoute(
                          builder: (context) => CategoryScreen(
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
                        MaterialPageRoute(
                          builder: (context) => CategoryScreen(
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
                        MaterialPageRoute(
                          builder: (context) => CategoryScreen(
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
                        MaterialPageRoute(
                          builder: (context) => CategoryScreen(
                            title: 'Tanzania Stations',
                            loadFunction: () => engine.loadTanzaniaStations(),
                          ),
                        ),
                      ),
                    ),
                    _CategoryCard(
                      title: 'Nearby',
                      icon: Icons.my_location,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CategoryScreen(
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
                        MaterialPageRoute(
                          builder: (context) => CategoryScreen(
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
                        MaterialPageRoute(
                          builder: (context) => CategoryScreen(
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
                        MaterialPageRoute(
                          builder: (context) => CategoryScreen(
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
                        MaterialPageRoute(
                          builder: (context) => CategoryScreen(
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
                        MaterialPageRoute(
                          builder: (context) => CategoryScreen(
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
                        MaterialPageRoute(
                          builder: (context) => CategoryScreen(
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
                        MaterialPageRoute(
                          builder: (context) => CategoryScreen(
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
                        MaterialPageRoute(
                          builder: (context) => CategoryScreen(
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
                        MaterialPageRoute(
                          builder: (context) => CategoryScreen(
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
  }

  Widget _buildPodcastsTab() {
    return Consumer<RadioEngine>(
      builder: (context, engine, child) {
        if (engine.isLoading) {
          return const Center(child: CircularProgressIndicator(color: Colors.red));
        }
        
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Podcasts',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white70),
                    onPressed: () => engine.searchPodcasts(''),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: engine.podcasts.isEmpty 
                  ? _buildPodcastCategories(engine)
                  : _buildPodcastList(engine),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPodcastCategories(RadioEngine engine) {
    return GridView.count(
      crossAxisCount: 2,
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

  Widget _buildPodcastList(RadioEngine engine) {
    return ListView.builder(
      itemCount: engine.podcasts.length,
      itemBuilder: (context, index) {
        final podcast = engine.podcasts[index];
        return Card(
          color: const Color(0xFF1C1C1C),
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                podcast.image,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.podcasts, color: Colors.red),
              ),
            ),
            title: Text(podcast.title, style: const TextStyle(color: Colors.white)),
            subtitle: Text(podcast.publisher, style: const TextStyle(color: Colors.grey)),
            onTap: () {
              // TODO: Navigate to Podcast Details
            },
          ),
        );
      },
    );
  }

  Widget _buildFavoritesTab() {
    return Consumer<RadioEngine>(
      builder: (context, engine, child) {
        final favorites = engine.favorites;
        if (favorites.isEmpty) {
          return const Center(
            child: Text(
              'No favorites yet',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }
        return ListView.builder(
          itemCount: favorites.length,
          itemBuilder: (context, index) {
            final favorite = favorites[index];
            final station = favorite.toRadioStation();
            return Card(
              color: const Color(0xFF1C1C1C),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                leading: station.favicon.isNotEmpty
                    ? CircleAvatar(
                        backgroundImage: NetworkImage(station.favicon),
                      )
                    : const CircleAvatar(
                        backgroundColor: Colors.red,
                        child: Icon(Icons.radio, color: Colors.white),
                      ),
                title: Text(
                  station.name,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  '${station.country} • ${station.genre} • ${station.bitrate}kbps',
                  style: const TextStyle(color: Colors.grey),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    engine.removeFromFavorites(favorite.id);
                  },
                ),
                onTap: () {
                  final messenger = ScaffoldMessenger.of(context);
                  engine.playStation(station).catchError((e) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Failed to play: ${station.name}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  });
                },
              ),
            );
          },
        );
      },
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
    return Card(
      color: const Color(0xFF1C1C1C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
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