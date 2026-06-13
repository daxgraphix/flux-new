import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../flux_engine/radio_engine.dart';
import '../flux_hardware/radio_service.dart';
import 'library_screen.dart';
import 'settings_screen.dart';
import 'countries_screen.dart';
import 'now_playing_screen.dart';
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
    return const _HomeTab();
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
      engine.loadTopStationsIfNeeded();
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

  void _showAdvancedSearchDialog(BuildContext context, RadioEngine engine) {
    String selectedCountry = '';
    String selectedGenre = '';
    String selectedLanguage = '';
    String selectedOrder = 'votes';
    bool isDescending = true;
    final searchName = TextEditingController(text: _searchController.text);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Advanced Search', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: searchName,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Station Name',
                    labelStyle: TextStyle(color: Colors.red),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.red)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.red)),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: null,
                  hint: const Text('Select Country', style: TextStyle(color: Colors.white70)),
                  dropdownColor: const Color(0xFF1A1A2E),
                  style: const TextStyle(color: Colors.white),
                  onChanged: (value) => selectedCountry = value ?? '',
                  items: engine.countries.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: null,
                  hint: const Text('Select Genre', style: TextStyle(color: Colors.white70)),
                  dropdownColor: const Color(0xFF1A1A2E),
                  style: const TextStyle(color: Colors.white),
                  onChanged: (value) => selectedGenre = value ?? '',
                  items: engine.genres.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: null,
                  hint: const Text('Select Language', style: TextStyle(color: Colors.white70)),
                  dropdownColor: const Color(0xFF1A1A2E),
                  style: const TextStyle(color: Colors.white),
                  onChanged: (value) => selectedLanguage = value ?? '',
                  items: engine.languages.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedOrder,
                  dropdownColor: const Color(0xFF1A1A2E),
                  style: const TextStyle(color: Colors.white),
                  onChanged: (value) => selectedOrder = value ?? 'votes',
                  items: const [
                    DropdownMenuItem(value: 'votes', child: Text('Popularity')),
                    DropdownMenuItem(value: 'clicktrend', child: Text('Trending')),
                    DropdownMenuItem(value: 'date', child: Text('Newest')),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Descending', style: TextStyle(color: Colors.white70)),
                    Switch(
                      value: isDescending,
                      onChanged: (v) => isDescending = v,
                      activeThumbColor: Colors.red,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              final name = searchName.text.isNotEmpty ? searchName.text : null;
              engine.searchStations(
                name: name,
                country: selectedCountry.isNotEmpty ? selectedCountry : null,
                tag: selectedGenre.isNotEmpty ? selectedGenre : null,
                language: selectedLanguage.isNotEmpty ? selectedLanguage : null,
                order: selectedOrder,
                reverse: isDescending,
                limit: 50,
              );
              Navigator.pop(context);
            },
            child: const Text('Search', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
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
            return CustomScrollView(
              slivers: [
                if (engine.currentStation != null)
                  SliverToBoxAdapter(
                    child: EnhancedMiniPlayer(
                      engine: engine,
                      isDark: isDark,
                      onExpandTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => NowPlayingScreen(engine: engine, isDark: isDark)),
                        );
                      },
                    ),
                  ),
                SliverToBoxAdapter(
                  child: _buildHeader(isDark, engine),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: _buildQuickActions(isDark, engine),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: _buildCategoriesSection(isDark, engine),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: FutureBuilder<List<RadioStation>>(
                      future: engine.favorites,
                      builder: (context, snapshot) {
                        final favs = snapshot.data ?? [];
                        if (favs.isEmpty) return const SizedBox.shrink();
                        return SizedBox(
                          height: 140,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: favs.length,
                            itemBuilder: (context, index) {
                              final station = favs[index];
                              return Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: _ModernStationCard(station: station, isDark: isDark, onTap: () => engine.playStation(station)),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: _buildSectionHeader('Recently Played', isDark, () {}),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: FutureBuilder<List<RadioStation>>(
                      future: engine.getRecentSearches().then((_) => engine.recentStations),
                      builder: (context, snapshot) {
                        final recent = snapshot.data ?? [];
                        if (recent.isEmpty) return const SizedBox.shrink();
                        return SizedBox(
                          height: 140,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: recent.length,
                            itemBuilder: (context, index) {
                              final station = recent[index];
                              return Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: _ModernStationCard(station: station, isDark: isDark, onTap: () => engine.playStation(station)),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: _buildSectionHeader('Browse by Country', isDark, () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const CountriesScreen()));
                    }),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: math.min(engine.countries.length, 15),
                        itemBuilder: (context, index) {
                          final country = engine.countries[index];
                          return Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: _ModernCountryCard(
                              country: country,
                              isDark: isDark,
                              onTap: () {
                                engine.loadStationsByCountry(country);
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const LibraryScreen()));
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: _buildSectionHeader('Genres', isDark, () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const LibraryScreen()));
                    }),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: math.min(engine.genres.length, 15),
                        itemBuilder: (context, index) {
                          final genre = engine.genres[index];
                          return Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: _ModernGenreCard(
                              genre: genre,
                              isDark: isDark,
                              onTap: () {
                                engine.loadStationsByGenre(genre);
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const LibraryScreen()));
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverToBoxAdapter(
                    child: _buildStationList(context, engine, isDark),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, RadioEngine engine) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Flux Radio',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.settings, color: isDark ? Colors.white : Colors.black),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
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
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
                borderSide: BorderSide(color: Colors.red, width: 2),
              ),
              prefixIcon: const Icon(Icons.search, color: Colors.red),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.clear, color: isDark ? Colors.grey : Colors.black54),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                        engine.loadTopStationsIfNeeded();
                      },
                    ),
                  IconButton(
                    icon: Icon(Icons.filter_list, color: isDark ? Colors.grey : Colors.black54),
                    onPressed: () => _showAdvancedSearchDialog(context, engine),
                  ),
                ],
              ),
            ),
            onChanged: (value) {
              setState(() {});
              _debouncedSearch(value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(bool isDark, RadioEngine engine) {
    final actions = [
      _QuickAction(icon: Icons.public_rounded, label: 'Countries', onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const CountriesScreen()));
      }),
      _QuickAction(icon: Icons.trending_up, label: 'Trending', onTap: () => engine.loadTrendingStations()),
      _QuickAction(icon: Icons.flag_rounded, label: 'Tanzania', onTap: () => engine.loadTanzaniaStations()),
      _QuickAction(icon: Icons.music_note_rounded, label: 'Music', onTap: () => engine.loadMusicStations()),
      _QuickAction(icon: Icons.sports_soccer_rounded, label: 'Sports', onTap: () => engine.loadSportsStations()),
    ];
    return Row(
      children: [
        const SizedBox(width: 4),
        ...actions.map((a) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: _QuickActionWidget(
            icon: a.icon,
            label: a.label,
            onTap: a.onTap,
            isDark: isDark,
          ),
        )),
      ],
    );
  }

  Widget _buildCategoriesSection(bool isDark, RadioEngine engine) {
    final categories = [
      {'title': 'Pop', 'color': Colors.pink, 'action': () => engine.searchStations(tag: 'pop', limit: 20)},
      {'title': 'Rock', 'color': Colors.orange, 'action': () => engine.searchStations(tag: 'rock', limit: 20)},
      {'title': 'Jazz', 'color': Colors.purple, 'action': () => engine.searchStations(tag: 'jazz', limit: 20)},
      {'title': 'Classical', 'color': Colors.indigo, 'action': () => engine.searchStations(tag: 'classical', limit: 20)},
      {'title': 'News', 'color': Colors.blue, 'action': () => engine.searchStations(tag: 'news', limit: 20)},
      {'title': 'Talk', 'color': Colors.teal, 'action': () => engine.searchStations(tag: 'talk', limit: 20)},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'Browse by Genre',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: cat['action'] as VoidCallback,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: (cat['color'] as Color).withValues(alpha:0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: (cat['color'] as Color).withValues(alpha:0.5)),
                    ),
                    child: Center(
                      child: Text(
                        cat['title'] as String,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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

  Widget _buildSectionHeader(String title, bool isDark, VoidCallback onViewAll) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 12),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: onViewAll,
            child: Text('View All', style: TextStyle(color: isDark ? Colors.red : Colors.blue)),
          ),
        ],
      ),
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
              Icon(Icons.radio, size: 64, color: isDark ? Colors.white24 : Colors.black26),
              const SizedBox(height: 16),
              Text(engine.errorMessage ?? 'No stations found', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => engine.loadTopStations(),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
        Text(
          'All Stations (${engine.stations.length})',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: displayStations.length,
          itemExtent: 80,
          padding: EdgeInsets.zero,
          itemBuilder: (ctx, i) {
            final station = displayStations[i];
            return _ModernStationListItem(
              station: station,
              isDark: isDark,
              engine: engine,
            );
          },
        ),
      ],
    );
  }

  Widget _buildShimmerList(bool isDark) {
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[200]!;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Shimmer.fromColors(
                baseColor: baseColor,
                highlightColor: highlightColor,
                child: const CircleAvatar(radius: 24, backgroundColor: Colors.grey),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Shimmer.fromColors(
                      baseColor: baseColor,
                      highlightColor: highlightColor,
                      child: Container(width: double.infinity, height: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 6),
                    Shimmer.fromColors(
                      baseColor: baseColor,
                      highlightColor: highlightColor,
                      child: Container(width: 100, height: 12, color: Colors.grey),
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
}

class _QuickAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  _QuickAction({required this.icon, required this.label, required this.onTap});
}

class _QuickActionWidget extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDark;

  const _QuickActionWidget({required this.icon, required this.label, required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha:0.08) : Colors.black.withValues(alpha:0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.red.withValues(alpha:0.2) : Colors.blue.withValues(alpha:0.2)),
            ),
            child: Icon(icon, color: isDark ? Colors.red : Colors.blue, size: 24),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black54,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
        ),
      ],
    );
  }
}

class _ModernStationCard extends StatelessWidget {
  final RadioStation station;
  final bool isDark;
  final VoidCallback onTap;

  const _ModernStationCard({required this.station, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        width: 110,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha:0.06) : Colors.black.withValues(alpha:0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.red.withValues(alpha:0.15) : Colors.blue.withValues(alpha:0.15)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: isDark ? Colors.white.withValues(alpha:0.1) : Colors.black.withValues(alpha:0.08),
              child: station.favicon.isNotEmpty
                  ? ClipOval(child: CachedNetworkImage(
                      imageUrl: station.favicon,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Icon(Icons.radio, color: Colors.red, size: 20),
                      errorWidget: (context, url, error) => const Icon(Icons.radio, color: Colors.red, size: 20),
                    ))
                  : const Icon(Icons.radio, color: Colors.red, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              station.name,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 12, fontWeight: FontWeight.w600),
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

class _ModernCountryCard extends StatelessWidget {
  final String country;
  final bool isDark;
  final VoidCallback onTap;

  const _ModernCountryCard({required this.country, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        width: 80,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha:0.06) : Colors.black.withValues(alpha:0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? Colors.red.withValues(alpha:0.15) : Colors.blue.withValues(alpha:0.15)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.flag_rounded, color: Colors.red, size: 24),
            const SizedBox(height: 4),
            Text(
              country,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 10, fontWeight: FontWeight.w500),
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

class _ModernGenreCard extends StatelessWidget {
  final String genre;
  final bool isDark;
  final VoidCallback onTap;

  const _ModernGenreCard({required this.genre, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        width: 80,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha:0.06) : Colors.black.withValues(alpha:0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? Colors.red.withValues(alpha:0.15) : Colors.blue.withValues(alpha:0.15)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.music_note_rounded, color: Colors.red, size: 24),
            const SizedBox(height: 4),
            Text(
              genre,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 10, fontWeight: FontWeight.w500),
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

class _ModernStationListItem extends StatelessWidget {
  final RadioStation station;
  final bool isDark;
  final RadioEngine engine;

  const _ModernStationListItem({required this.station, required this.isDark, required this.engine});

  @override
  Widget build(BuildContext context) {
    final isPlaying = engine.currentStation?.name == station.name && engine.isPlaying;
    final isLoading = engine.isLoading && engine.currentStation?.name == station.name;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha:0.06) : Colors.black.withValues(alpha:0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isPlaying ? Colors.red.withValues(alpha:0.5) : Colors.transparent),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: Stack(
          alignment: Alignment.center,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: isDark ? Colors.white.withValues(alpha:0.1) : Colors.black.withValues(alpha:0.08),
              child: station.favicon.isNotEmpty
                  ? ClipOval(child: CachedNetworkImage(
                      imageUrl: station.favicon,
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Icon(Icons.radio, color: Colors.red, size: 16),
                      errorWidget: (context, url, error) => const Icon(Icons.radio, color: Colors.red, size: 16),
                    ))
                  : const Icon(Icons.radio, color: Colors.red, size: 16),
            ),
            if (isLoading)
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: Colors.black.withValues(alpha:0.5), shape: BoxShape.circle),
                child: const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.red))),
              ),
            if (isPlaying)
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: Colors.red.withValues(alpha:0.3), shape: BoxShape.circle),
                child: const Icon(Icons.audiotrack, color: Colors.red, size: 16),
              ),
          ],
        ),
        title: Text(
          station.name,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: isPlaying ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${station.country} • ${station.genre} • ${station.bitrate}kbps',
          style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 11),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.red, size: 28),
        onTap: isLoading ? null : () async {
          try {
            await engine.playStation(station);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to play: ${station.name}'), backgroundColor: Colors.red, action: SnackBarAction(label: 'Retry', onPressed: () => engine.playStation(station))));
            }
          }
        },
      ),
    );
  }
}