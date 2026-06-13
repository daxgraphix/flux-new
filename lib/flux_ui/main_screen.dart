import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../flux_engine/radio_engine.dart';
import '../flux_hardware/radio_service.dart';
import 'library_screen.dart';
import 'settings_screen.dart';
import 'countries_screen.dart';
import 'widgets/enhanced_mini_player.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const _HomeTab(),
    );
  }
}

class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _debouncedSearch(String value) {
    _debounce?.cancel();
    if (value.isEmpty) {
      final engine = context.read<RadioEngine>();
      engine.loadTopStations();
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        final engine = context.read<RadioEngine>();
        engine.searchStations(name: value, limit: 50);
        engine.saveRecentSearch(value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF1A1A2E), const Color(0xFF0A0A0A)]
                : [const Color(0xFFE8EAF6), const Color(0xFFD1C4E9)],
          ),
        ),
        child: Consumer<RadioEngine>(
          builder: (context, engine, child) {
            return Column(
              children: [
                // Mini player when station is playing
                if (engine.currentStation != null)
                  _buildMiniPlayer(engine, isDark),
                // Main content
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      final engine = context.read<RadioEngine>();
                      await engine.loadTopStations();
                    },
                    color: Colors.red,
                    child: ListView(
                      key: const ValueKey('home_list'),
                      padding: EdgeInsets.zero,
                      children: [
                        _buildSearchSection(isDark, engine),
                        _buildQuickActions(isDark, engine),
                        _buildCountryGenreSection(isDark, engine),
                        _buildStationList(context, engine, isDark),
                        _buildRecentSection(engine, isDark),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMiniPlayer(RadioEngine engine, bool isDark) {
    return EnhancedMiniPlayer(
      engine: engine,
      isDark: isDark,
      onExpandTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) => NowPlayingSheet(engine: engine, isDark: isDark),
        );
      },
    );
  }

  Widget _buildSearchSection(bool isDark, RadioEngine engine) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withValues(alpha: 0.3 * 255) : Colors.white.withValues(alpha: 0.8 * 255),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'Flux Radio',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.settings, color: isDark ? Colors.white : Colors.black),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              hintText: 'Search stations...',
              hintStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[500]),
              filled: true,
              fillColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
                borderSide: BorderSide(color: Colors.red.withValues(alpha: 0.3 * 255), width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
                borderSide: BorderSide(color: Colors.red, width: 2),
              ),
              prefixIcon: const Icon(Icons.search, color: Colors.red),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: isDark ? Colors.grey : Colors.black54),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                        engine.loadTopStations();
                      },
                    )
                  : IconButton(
                      icon: const Icon(Icons.filter_list, color: Colors.red),
                      onPressed: () => _showFilterDialog(context, engine, isDark),
                    ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
            onChanged: (value) {
              setState(() {});
              _debouncedSearch(value);
            },
            onSubmitted: (_) {
              FocusScope.of(context).unfocus();
              _debouncedSearch(_searchController.text);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(bool isDark, RadioEngine engine) {
    final actions = [
      ('Countries', Icons.public_rounded, () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CountriesScreen()),
        );
      }),
      ('Trending', Icons.trending_up, () => engine.loadTrendingStations()),
      ('Tanzania', Icons.flag_rounded, () => engine.loadTanzaniaStations()),
      ('Music', Icons.music_note_rounded, () => engine.loadMusicStations()),
      ('Sports', Icons.sports_soccer_rounded, () => engine.loadSportsStations()),
    ];
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: actions.length,
        itemBuilder: (ctx, i) {
          final action = actions[i];
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _QuickActionCard(
              icon: action.$2,
              label: action.$1,
              onTap: action.$3,
              isDark: isDark,
            ),
          );
        },
      ),
    );
  }

  Widget _buildCountryGenreSection(bool isDark, RadioEngine engine) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(Icons.flag_rounded, color: isDark ? Colors.red : Colors.blue, size: 20),
              const SizedBox(width: 8),
              Text(
                'Countries',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CountriesScreen()),
                  );
                },
                child: Text('Browse All', style: TextStyle(color: isDark ? Colors.red : Colors.blue)),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 100,
          child: Consumer<RadioEngine>(
            builder: (_, engine, child) => ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: math.min(engine.countries.length, 10),
              itemBuilder: (ctx, i) {
                final country = engine.countries[i];
                return _CountryCard(
                  country: country,
                  isDark: isDark,
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(Icons.music_note_rounded, color: isDark ? Colors.red : Colors.blue, size: 20),
              const SizedBox(width: 8),
              Text(
                'Genres',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LibraryScreen(),
                    ),
                  );
                },
                child: Text('Explore', style: TextStyle(color: isDark ? Colors.red : Colors.blue)),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 100,
          child: Consumer<RadioEngine>(
            builder: (_, engine, child) => ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: math.min(engine.genres.length, 10),
              itemBuilder: (ctx, i) {
                final genre = engine.genres[i];
                return _GenreCard(
                  genre: genre,
                  isDark: isDark,
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildStationList(BuildContext context, RadioEngine engine, bool isDark) {
    if (engine.isLoading && engine.stations.isEmpty) {
      return _buildShimmerList(isDark);
    }
    if (engine.stations.isEmpty && !engine.isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.radio,
                size: 64,
                color: isDark ? Colors.white24 : Colors.black26,
              ),
              const SizedBox(height: 16),
              Text(
                engine.errorMessage ?? 'No stations found',
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => engine.loadTopStations(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final displayStations = engine.stations.take(50).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Stations (${engine.stations.length})',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: displayStations.length,
          itemExtent: 84,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemBuilder: (ctx, i) {
            final station = displayStations[i];
            return _StationCard(
              key: ValueKey('station_${station.name}_${station.url.hashCode}'),
              station: station,
              isDark: isDark,
            );
          },
        ),
        if (engine.stations.length > 50)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Load more stations feature coming soon')),
                  );
                },
                child: const Text('Load More Stations'),
              ),
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildRecentSection(RadioEngine engine, bool isDark) {
    final recentStations = engine.recentStations.take(8).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Recently Played',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: recentStations.length,
            itemBuilder: (context, index) {
              final station = recentStations[index];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () => engine.playStation(station),
                  child: Container(
                    width: 140,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05 * 255),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: CircleAvatar(
                            radius: 24,
                            backgroundColor: isDark ? Colors.white.withValues(alpha: 0.1 * 255) : Colors.black.withValues(alpha: 0.08),
                            child: station.favicon.isNotEmpty
                                ? ClipOval(
                                    child: Image.network(
                                      station.favicon,
                                      fit: BoxFit.cover,
                                      width: 40,
                                      height: 40,
                                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.history, color: Colors.red, size: 20),
                                    ),
                                  )
                                : const Icon(Icons.history, color: Colors.red, size: 24),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          station.name,
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 12, fontWeight: FontWeight.w600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
  }
}

class _StationCard extends StatelessWidget {
  final RadioStation station;
  final bool isDark;

  const _StationCard({super.key, required this.station, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Consumer<RadioEngine>(
      builder: (context, engine, child) {
        final isPlaying = engine.currentStation?.name == station.name && engine.isPlaying;
        final isLoading = engine.isLoading && engine.currentStation?.name == station.name;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          constraints: const BoxConstraints(minHeight: 76, maxHeight: 76),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isPlaying ? Colors.red.withValues(alpha: 0.5) : Colors.transparent),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: Stack(
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: isDark ? Colors.white.withValues(alpha: 0.1 * 255) : Colors.black.withValues(alpha: 0.08),
                  child: station.favicon.isNotEmpty
                      ? ClipOval(
                          child: Image.network(
                            station.favicon,
                            fit: BoxFit.cover,
                            width: 44,
                            height: 44,
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.radio, color: Colors.red, size: 20),
                          ),
                        )
                      : const Icon(Icons.radio, color: Colors.red, size: 20),
                ),
                if (isLoading)
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(
              station.name,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: isPlaying ? FontWeight.bold : FontWeight.w500,
                fontSize: 15,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${station.country} • ${station.genre} • ${station.bitrate} kbps',
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black54,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Consumer<RadioEngine>(
                  builder: (context, engine, _) {
                    final isFavorite = engine.currentStation?.name == station.name;
                    return IconButton(
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: Colors.red,
                        size: 20,
                      ),
                      onPressed: () async {
                        if (isFavorite) {
                          await engine.removeFromFavorites(station.name);
                        } else {
                          await engine.addToFavorites(station);
                        }
                      },
                    );
                  },
                ),
                IconButton(
                  icon: SizedBox(
                    width: 28,
                    height: 28,
                    child: isLoading
                        ? const CircularProgressIndicator(strokeWidth: 2, color: Colors.orange)
                        : Icon(
                            isPlaying ? Icons.pause_circle : Icons.play_circle,
                            color: Colors.red,
                            size: 28,
                          ),
                  ),
                  onPressed: isLoading ? null : () async {
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
              ],
            ),
            onTap: isLoading ? null : () async {
              try {
                await engine.playStation(station);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to play: ${station.name}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
        );
      },
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDark;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05 * 255),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.red.withValues(alpha: 0.2 * 255) : Colors.blue.withValues(alpha: 0.2 * 255)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: (isDark ? Colors.red : Colors.blue).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: isDark ? Colors.red : Colors.blue, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class _CountryCard extends StatelessWidget {
  final String country;
  final bool isDark;

  const _CountryCard({required this.country, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final engine = context.read<RadioEngine>();
        engine.loadStationsByCountry(country);
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => const LibraryScreen(),
        ));
      },
      child: Container(
        width: 110,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05 * 255),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? Colors.red.withValues(alpha: 0.2 * 255) : Colors.blue.withValues(alpha: 0.2 * 255)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.flag_rounded, color: Colors.red, size: 28),
            const SizedBox(height: 6),
            Text(
              country,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _GenreCard extends StatelessWidget {
  final String genre;
  final bool isDark;

  const _GenreCard({required this.genre, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final engine = context.read<RadioEngine>();
        engine.loadStationsByGenre(genre);
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => const LibraryScreen(),
        ));
      },
      child: Container(
        width: 110,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05 * 255),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? Colors.red.withValues(alpha: 0.2 * 255) : Colors.blue.withValues(alpha: 0.2 * 255)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.music_note_rounded, color: Colors.red, size: 28),
            const SizedBox(height: 6),
            Text(
              genre,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

void _showFilterDialog(BuildContext context, RadioEngine engine, bool isDark) {
  String? selectedCountry;
  String? selectedGenre;
  String? selectedLanguage;
  String selectedOrder = 'votes';
  bool reverseOrder = true;
  int minBitrate = 0;
  int maxBitrate = 320;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Advanced Search', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedCountry,
                decoration: InputDecoration(
                  labelText: 'Country',
                  labelStyle: const TextStyle(color: Colors.red),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.2 * 255) : Colors.grey),
                  ),
                ),
                dropdownColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                items: [
                  const DropdownMenuItem<String>(value: null, child: Text('All Countries')),
                  ...engine.countries.take(50).map((c) => DropdownMenuItem<String>(
                    value: c,
                    child: Text(c, style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                  )),
                ],
                onChanged: (value) => setState(() => selectedCountry = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedGenre,
                decoration: InputDecoration(
                  labelText: 'Genre',
                  labelStyle: const TextStyle(color: Colors.red),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.2 * 255) : Colors.grey),
                  ),
                ),
                dropdownColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                items: [
                  const DropdownMenuItem<String>(value: null, child: Text('All Genres')),
                  ...engine.genres.take(50).map((g) => DropdownMenuItem<String>(
                    value: g,
                    child: Text(g, style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                  )),
                ],
                onChanged: (value) => setState(() => selectedGenre = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedLanguage,
                decoration: InputDecoration(
                  labelText: 'Language',
                  labelStyle: const TextStyle(color: Colors.red),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.2 * 255) : Colors.grey),
                  ),
                ),
                dropdownColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                items: [
                  const DropdownMenuItem<String>(value: null, child: Text('All Languages')),
                  ...engine.languages.take(50).map((lang) => DropdownMenuItem<String>(
                    value: lang,
                    child: Text(lang, style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                  )),
                ],
                onChanged: (value) => setState(() => selectedLanguage = value),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: selectedOrder,
                      decoration: InputDecoration(
                        labelText: 'Sort by',
                        labelStyle: const TextStyle(color: Colors.red),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.2 * 255) : Colors.grey),
                        ),
                      ),
                      dropdownColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                      items: const [
                        DropdownMenuItem(value: 'votes', child: Text('Popularity')),
                        DropdownMenuItem(value: 'clicktrend', child: Text('Trending')),
                        DropdownMenuItem(value: 'name', child: Text('Name')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => selectedOrder = value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Reverse'),
                      value: reverseOrder,
                      onChanged: (value) => setState(() => reverseOrder = value ?? true),
                      activeColor: Colors.red,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Bitrate Range: $minBitrate - $maxBitrate kbps',
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
              ),
              RangeSlider(
                values: RangeValues(minBitrate.toDouble(), maxBitrate.toDouble()),
                min: 0,
                max: 320,
                divisions: 32,
                labels: RangeLabels('${minBitrate}kbps', '${maxBitrate}kbps'),
                activeColor: Colors.red,
                inactiveColor: Colors.grey,
                onChanged: (values) => setState(() {
                  minBitrate = values.start.round();
                  maxBitrate = values.end.round();
                }),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (selectedCountry != null || selectedGenre != null ||
                  minBitrate > 0 || maxBitrate < 320) {
                engine.searchStations(
                  name: null,
                  country: selectedCountry,
                  tag: selectedGenre,
                  bitrateMin: minBitrate > 0 ? minBitrate : null,
                  bitrateMax: maxBitrate < 320 ? maxBitrate : null,
                  limit: 1000,
                );
              } else {
                engine.loadTopStations();
              }
              Navigator.pop(ctx);
            },
            child: const Text('Search', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ),
  );
}

class NowPlayingSheet extends StatelessWidget {
  final RadioEngine engine;
  final bool isDark;

  const NowPlayingSheet({super.key, required this.engine, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[700] : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          CircleAvatar(
            radius: 48,
            backgroundColor: Colors.red.withValues(alpha: 0.2),
            child: const Icon(Icons.radio, color: Colors.red, size: 48),
          ),
          const SizedBox(height: 16),
          Text(
            engine.currentStation?.name ?? 'Unknown Station',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '${engine.currentStation?.country} • ${engine.currentStation?.genre}',
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(
                  engine.isRecording ? Icons.stop_circle : Icons.fiber_manual_record,
                  color: engine.isRecording ? Colors.red : Colors.grey,
                  size: 32,
                ),
                onPressed: () async {
                  if (engine.isRecording) {
                    await engine.stopRecording();
                  } else {
                    await engine.startRecording();
                  }
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: Icon(
                  engine.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                  color: Colors.red,
                  size: 48,
                ),
                onPressed: () {
                  if (engine.isPlaying) {
                    engine.pause();
                  } else {
                    engine.resume();
                  }
                },
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.stop_circle, color: Colors.red, size: 32),
                onPressed: () => engine.stop(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Slider(
            value: engine.volume,
            min: 0.0,
            max: 1.0,
            onChanged: engine.setVolume,
            activeColor: Colors.red,
          ),
          Text('${(engine.volume * 100).round()}%', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
        ],
      ),
    );
  }
}

Widget _buildShimmerList(bool isDark) {
  final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
  final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[200]!;

  return ListView.builder(
    padding: const EdgeInsets.all(16),
    itemBuilder: (context, index) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          children: [
            Shimmer.fromColors(
              baseColor: baseColor,
              highlightColor: highlightColor,
              child: const CircleAvatar(
                radius: 32,
                backgroundColor: Colors.grey,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Shimmer.fromColors(
                    baseColor: baseColor,
                    highlightColor: highlightColor,
                    child: Container(
                      width: double.infinity,
                      height: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Shimmer.fromColors(
                    baseColor: baseColor,
                    highlightColor: highlightColor,
                    child: Container(
                      width: 100,
                      height: 12,
                      color: Colors.grey,
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