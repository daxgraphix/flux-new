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
import 'now_playing_screen.dart';
import 'widgets/enhanced_mini_player.dart';

import 'widgets/flux_image.dart';

// ─── Color System ──────────────────────────────────────────────────────────
const _kBlack = Color(0xFF0A0A0A);
const _kCard = Color(0xFF1C1C1C);
const _kRed = Color(0xFFE53935);
const _kWhite = Colors.white;
const _kGrey = Color(0xFF9E9E9E);

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
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

class _HomeTabState extends State<_HomeTab>
    with AutomaticKeepAliveClientMixin {
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
      context.read<RadioEngine>().loadTopStationsIfNeeded();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () {
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
    return Container(
      color: _kBlack,
      child: Consumer<RadioEngine>(
        builder: (context, engine, _) {
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ─── Mini Player ──────────────────────────────────────────
              if (engine.currentStation != null)
                SliverToBoxAdapter(
                  child: EnhancedMiniPlayer(
                    engine: engine,
                    isDark: true,
                    onExpandTap: () => Navigator.of(context).push(
                      _slideRoute(NowPlayingScreen(engine: engine, isDark: true)),
                    ),
                  ),
                ),

              // ─── Header ───────────────────────────────────────────────
              SliverToBoxAdapter(child: _buildHeader(engine)),

              // ─── Quick Actions ────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                sliver: SliverToBoxAdapter(
                    child: _buildQuickActions(engine)),
              ),

              // ─── Genres ───────────────────────────────────────────────
              SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                sliver: SliverToBoxAdapter(
                    child: _buildGenreChips(engine)),
              ),

              // ─── Favourites ───────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: FutureBuilder<List<RadioStation>>(
                    future: Future.value(engine.favoriteStations),
                    builder: (context, snapshot) {
                      final favs = snapshot.data ?? [];
                      if (favs.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionHeader(
                              title: 'My Favourites',
                              onViewAll: () => Navigator.push(context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const LibraryScreen()))),
                          SizedBox(
                            height: 130,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: favs.length,
                              itemExtent: 120,
                              itemBuilder: (_, i) => Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: _StationCard(
                                  station: favs[i],
                                  onTap: () =>
                                      engine.playStation(favs[i]),
                                  isPlaying:
                                      engine.currentStation?.name ==
                                              favs[i].name &&
                                          engine.isPlaying,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              // ─── Recently Played ──────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: FutureBuilder<List<RadioStation>>(
                    future: engine
                        .getRecentSearches()
                        .then((_) => engine.recentStations),
                    builder: (context, snapshot) {
                      final recent = snapshot.data ?? [];
                      if (recent.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionHeader(
                              title: 'Recently Played',
                              onViewAll: () => Navigator.push(context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const LibraryScreen()))),
                          SizedBox(
                            height: 130,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: recent.length,
                              itemExtent: 120,
                              itemBuilder: (_, i) => Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: _StationCard(
                                  station: recent[i],
                                  onTap: () =>
                                      engine.playStation(recent[i]),
                                  isPlaying:
                                      engine.currentStation?.name ==
                                              recent[i].name &&
                                          engine.isPlaying,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              // ─── Countries ────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader(
                          title: 'Browse by Country',
                          onViewAll: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const CountriesScreen()))),
                      SizedBox(
                        height: 112,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount:
                              math.min(engine.countries.length, 15),
                          itemExtent: 90,
                          itemBuilder: (_, i) {
                            final c = engine.countries[i];
                            return Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: _CountryCard(
                                country: c,
                                onTap: () {
                                  engine.loadStationsByCountry(c);
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const LibraryScreen()));
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ─── Station List ─────────────────────────────────────────
              _buildStationList(context, engine),
            ],
          );
        },
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────
  Widget _buildHeader(RadioEngine engine) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo row
            Row(
              children: [
                // Logo badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _kRed,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'FLUX',
                    style: TextStyle(
                      color: _kWhite,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'RADIO',
                  style: TextStyle(
                    color: _kWhite,
                    fontWeight: FontWeight.w300,
                    fontSize: 20,
                    letterSpacing: 3,
                  ),
                ),
                // Live indicator
                const SizedBox(width: 10),
                _LiveBadge(),
                const Spacer(),
                // Settings
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SettingsScreen()),
                  ),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _kCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: const Icon(Icons.settings_outlined,
                        color: _kWhite, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Search bar
            Container(
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08), width: 1),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    style: const TextStyle(color: _kWhite, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Search 50,000+ stations...',
                      hintStyle:
                          TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: _kRed, size: 22),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_searchController.text.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                setState(() {});
                                context
                                    .read<RadioEngine>()
                                    .loadTopStationsIfNeeded();
                              },
                              child: const Icon(Icons.close_rounded,
                                  color: _kGrey, size: 18),
                            ),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                    onChanged: (v) {
                      setState(() {});
                      _debouncedSearch(v);
                    },
                  ),
                  if (_searchController.text.isEmpty && engine.recentSearches.isNotEmpty)
                    _buildRecentSearches(engine),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentSearches(RadioEngine engine) {
    return Container(
      height: 40,
      padding: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: engine.recentSearches.length,
        itemBuilder: (context, index) {
          final query = engine.recentSearches[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(query, style: const TextStyle(color: _kWhite, fontSize: 11)),
              backgroundColor: _kBlack,
              side: BorderSide(color: _kRed.withValues(alpha: 0.3)),
              padding: EdgeInsets.zero,
              onPressed: () {
                _searchController.text = query;
                setState(() {});
                engine.searchStations(name: query);
              },
            ),
          );
        },
      ),
    );
  }

  // ─── Quick Actions ────────────────────────────────────────────────────────
  Widget _buildQuickActions(RadioEngine engine) {
    final actions = [
      _QA(icon: Icons.public_rounded, label: 'Countries',
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const CountriesScreen()))),
      _QA(icon: Icons.trending_up_rounded, label: 'Trending',
          onTap: () => engine.loadTrendingStations()),
      _QA(icon: Icons.flag_rounded, label: 'Tanzania',
          onTap: () => engine.loadTanzaniaStations()),
      _QA(icon: Icons.music_note_rounded, label: 'Music',
          onTap: () => engine.loadMusicStations()),
      _QA(icon: Icons.sports_soccer_rounded, label: 'Sports',
          onTap: () => engine.loadSportsStations()),
      _QA(icon: Icons.newspaper_rounded, label: 'News',
          onTap: () => engine.loadNewsStations()),
    ];
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        itemExtent: 72,
        itemBuilder: (_, i) {
          final a = actions[i];
          return _QuickActionBtn(
            icon: a.icon,
            label: a.label,
            onTap: a.onTap,
          );
        },
      ),
    );
  }

  // ─── Genre Chips ──────────────────────────────────────────────────────────
  Widget _buildGenreChips(RadioEngine engine) {
    final genres = [
      ('Pop', 'pop'),
      ('Rock', 'rock'),
      ('Jazz', 'jazz'),
      ('Classical', 'classical'),
      ('Electronic', 'electronic'),
      ('Hip-Hop', 'hip-hop'),
      ('R&B', 'rnb'),
      ('Talk', 'talk'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 8, bottom: 10),
          child: Text(
            'Browse Genres',
            style: TextStyle(
                color: _kWhite, fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ),
        SizedBox(
          height: 38,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: genres.length,
            itemBuilder: (_, i) {
              final (label, tag) = genres[i];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => engine.searchStations(tag: tag, limit: 30),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      color: _kCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: _kRed.withValues(alpha: 0.4), width: 1),
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(
                          color: _kWhite,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ─── Station List ─────────────────────────────────────────────────────────
  Widget _buildStationList(BuildContext context, RadioEngine engine) {
    if (engine.isLoading && engine.stations.isEmpty) {
      return SliverToBoxAdapter(child: _buildShimmer());
    }
    if (engine.stations.isEmpty && !engine.isLoading) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.radio_rounded,
                  size: 72, color: Colors.white.withValues(alpha: 0.1)),
              const SizedBox(height: 16),
              Text(
                engine.errorMessage ?? 'No stations found',
                style: const TextStyle(color: _kGrey, fontSize: 15),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => engine.loadTopStations(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kRed,
                  foregroundColor: _kWhite,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final stations = engine.stations.take(50).toList();
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 12),
                child: Row(
                  children: [
                    const Text(
                      'Top Stations',
                      style: TextStyle(
                          color: _kWhite,
                          fontSize: 17,
                          fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _kRed.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kRed.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        '${engine.stations.length}',
                        style: const TextStyle(
                            color: _kRed, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            }
            return _StationListItem(
              station: stations[index - 1],
              engine: engine,
            );
          },
          childCount: stations.length + 1,
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return Column(
      children: List.generate(
        8,
        (i) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Shimmer.fromColors(
            baseColor: const Color(0xFF1C1C1C),
            highlightColor: const Color(0xFF2C2C2C),
            child: Row(
              children: [
                Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          width: double.infinity,
                          height: 14,
                          color: Colors.white),
                      const SizedBox(height: 8),
                      Container(width: 120, height: 10, color: Colors.white),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle)),
              ],
            ),
          ),
        ),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 12),
      child: Row(
        children: [
          Text(title,
              style: const TextStyle(
                  color: _kWhite,
                  fontSize: 17,
                  fontWeight: FontWeight.w700)),
          const Spacer(),
          GestureDetector(
            onTap: onViewAll,
            child: const Text('View All',
                style: TextStyle(
                    color: _kRed, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ─── Live Badge ───────────────────────────────────────────────────────────
class _LiveBadge extends StatefulWidget {
  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 900), vsync: this)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _kRed.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kRed.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kRed
                      .withValues(alpha: 0.5 + 0.5 * _ctrl.value)),
            ),
            const SizedBox(width: 5),
            const Text('LIVE',
                style: TextStyle(
                    color: _kRed,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5)),
          ],
        ),
      ),
    );
  }
}

// ─── Quick Action ─────────────────────────────────────────────────────────
class _QA {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QA({required this.icon, required this.label, required this.onTap});
}

class _QuickActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionBtn(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kRed.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                    color: _kRed.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Icon(icon, color: _kRed, size: 24),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(
                color: _kGrey, fontSize: 10, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Station Card (horizontal list) ──────────────────────────────────────
class _StationCard extends StatelessWidget {
  final RadioStation station;
  final VoidCallback onTap;
  final bool isPlaying;

  const _StationCard(
      {required this.station, required this.onTap, required this.isPlaying});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 110,
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isPlaying ? _kRed : Colors.white.withValues(alpha: 0.06),
              width: isPlaying ? 1.5 : 1),
          boxShadow: isPlaying
              ? [BoxShadow(color: _kRed.withValues(alpha: 0.2), blurRadius: 12)]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kBlack,
                  border: Border.all(
                      color: _kRed.withValues(alpha: 0.4), width: 1.5)),
              child: FluxImage(
                imageUrl: station.favicon,
                width: 52,
                height: 52,
                placeholder: const Icon(Icons.radio_rounded,
                    color: _kRed, size: 22),
                errorWidget: const Icon(Icons.radio_rounded,
                    color: _kRed, size: 22),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                station.name,
                style: TextStyle(
                    color: isPlaying ? _kRed : _kWhite,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Country Card ─────────────────────────────────────────────────────────
class _CountryCard extends StatelessWidget {
  final String country;
  final VoidCallback onTap;

  const _CountryCard({required this.country, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kRed.withValues(alpha: 0.25)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.flag_rounded, color: _kRed, size: 26),
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                country,
                style: const TextStyle(
                    color: _kWhite, fontSize: 10, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Station List Item ────────────────────────────────────────────────────
class _StationListItem extends StatelessWidget {
  final RadioStation station;
  final RadioEngine engine;

  const _StationListItem({required this.station, required this.engine});

  @override
  Widget build(BuildContext context) {
    final isPlaying = engine.currentStation?.name == station.name && engine.isPlaying;
    final isLoading = engine.isLoading && engine.currentStation?.name == station.name;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isPlaying ? _kRed.withValues(alpha: 0.06) : _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPlaying ? _kRed.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.05),
          width: isPlaying ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: isLoading ? null : () async {
          try {
            await engine.playStation(station);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Failed to play: ${station.name}'),
                backgroundColor: _kRed,
                action: SnackBarAction(
                    label: 'Retry',
                    textColor: _kWhite,
                    onPressed: () => engine.playStation(station)),
              ));
            }
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Avatar
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _kBlack,
                      border: Border.all(
                          color: isPlaying
                              ? _kRed
                              : Colors.white.withValues(alpha: 0.1),
                          width: 1.5),
                    ),
                    child: FluxImage(
                      imageUrl: station.favicon,
                      width: 46,
                      height: 46,
                      placeholder: const Icon(Icons.radio_rounded,
                          color: _kRed, size: 18),
                      errorWidget: const Icon(Icons.radio_rounded,
                          color: _kRed, size: 18),
                    ),
                  ),
                  if (isLoading)
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle),
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(_kRed)),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      station.name,
                      style: TextStyle(
                          color: isPlaying ? _kRed : _kWhite,
                          fontWeight: isPlaying
                              ? FontWeight.bold
                              : FontWeight.w600,
                          fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (station.country.isNotEmpty) station.country,
                        if (station.genre.isNotEmpty) station.genre,
                        if (station.bitrate > 0) '${station.bitrate}kbps',
                      ].join(' \u2022 '),
                      style:
                          const TextStyle(color: _kGrey, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Play button
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isPlaying
                      ? _kRed
                      : _kRed.withValues(alpha: 0.12),
                ),
                child: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: _kWhite,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Page transition helper ───────────────────────────────────────────────
PageRoute _slideRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, anim, secondaryAnim, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      );
    },
    transitionDuration: const Duration(milliseconds: 380),
  );
}