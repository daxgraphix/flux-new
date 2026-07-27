import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../flux_engine/radio_engine.dart';
import '../flux_hardware/radio_service.dart';
import '../helpers/navigation_helper.dart';
import 'now_playing_screen.dart';
import 'library_screen.dart';
import 'countries_screen.dart';
import 'streema_browser_screen.dart';

import 'widgets/flux_image.dart';

// ─── Colors ──────────────────────────────────────────────────────────
const _kGrey = Color(0xFF9E9E9E);

// ─── Main Screen ──────────────────────────────────────────────────────────
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
    _debounce = Timer(const Duration(milliseconds: 500), () {
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
    final theme = Theme.of(context);

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Consumer<RadioEngine>(
        builder: (context, engine, _) {
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ─── Header ───────────────────────────────────────────────
              SliverToBoxAdapter(child: _buildHeader(context, engine)),

              // ─── Quick Actions ────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                sliver: SliverToBoxAdapter(
                    child: _buildQuickActions(context, engine)),
              ),

              // ─── Genres ───────────────────────────────────────────────
              SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                sliver: SliverToBoxAdapter(
                    child: _buildGenreChips(context, engine)),
              ),

              // ─── Favourites ───────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: Selector<RadioEngine, List<RadioStation>>(
                    selector: (_, e) => e.favoriteStations,
                    builder: (context, favs, _) {
                      if (favs.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionHeader(
                              title: 'My Favourites',
                              onViewAll: () => Navigator.push(
                                  context,
                                  NavigationHelper.slideUpRoute(const LibraryScreen()))),
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
                                  onTap: () => engine.playStation(favs[i]).then((_) {
                                        if (context.mounted) {
                                          Navigator.of(context).push(NavigationHelper.slideUpRoute(NowPlayingScreen(engine: engine)));
                                        }
                                      }),
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
                  child: Selector<RadioEngine, List<RadioStation>>(
                    selector: (_, e) => e.recentStations,
                    builder: (context, recent, _) {
                      if (recent.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionHeader(
                              title: 'Recently Played',
                              onViewAll: () => Navigator.push(
                                  context,
                                  NavigationHelper.slideUpRoute(const LibraryScreen()))),
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
                                  onTap: () => engine.playStation(recent[i]).then((_) {
                                        if (context.mounted) {
                                          Navigator.of(context).push(NavigationHelper.slideUpRoute(NowPlayingScreen(engine: engine)));
                                        }
                                      }),
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
                              NavigationHelper.slideUpRoute(const CountriesScreen()))),
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
                                      NavigationHelper.slideUpRoute(const LibraryScreen()));
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
  Widget _buildHeader(BuildContext context, RadioEngine engine) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

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
                    color: theme.primaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'FLUX',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'RADIO',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w300,
                    fontSize: 20,
                    letterSpacing: 3,
                  ),
                ),
                // Live indicator
                const SizedBox(width: 10),
                _LiveBadge(),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 16),
            // Search bar
            Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: textColor.withValues(alpha: 0.08), width: 1),
                boxShadow: isDark ? null : [
                   BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    style: TextStyle(color: textColor, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Search 50,000+ stations...',
                      hintStyle:
                          TextStyle(color: textColor.withValues(alpha: 0.3), fontSize: 14),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      prefixIcon: Icon(Icons.search_rounded,
                          color: theme.primaryColor, size: 22),
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
                              child: Icon(Icons.close_rounded,
                                  color: textColor.withValues(alpha: 0.4), size: 18),
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
                    _buildRecentSearches(context, engine),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentSearches(BuildContext context, RadioEngine engine) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

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
              label: Text(query, style: TextStyle(color: textColor, fontSize: 11)),
              backgroundColor: isDark ? Colors.black : Colors.grey[200],
              side: BorderSide(color: theme.primaryColor.withValues(alpha: 0.3)),
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
  Widget _buildQuickActions(BuildContext context, RadioEngine engine) {
    final actions = [
      _QA(icon: Icons.public_rounded, label: 'Countries',
          onTap: () => Navigator.push(context,
              NavigationHelper.slideUpRoute(const CountriesScreen()))),
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
  Widget _buildGenreChips(BuildContext context, RadioEngine engine) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    
    final displayGenres = engine.genres.isNotEmpty
        ? engine.genres.take(24).toList()
        : ['Pop', 'Rock', 'Jazz', 'Classical', 'Electronic', 'Hip-Hop', 'Talk', 'News', 'Dance', 'Country'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 10),
          child: Text(
            'Explore Genres',
            style: TextStyle(
                color: textColor, fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ),
        SizedBox(
          height: 38,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: displayGenres.length,
            itemBuilder: (_, i) {
              final tag = displayGenres[i];
              final label = tag.length > 1 
                  ? tag[0].toUpperCase() + tag.substring(1) 
                  : tag.toUpperCase();
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => engine.searchStations(tag: tag, limit: 50),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: theme.primaryColor.withValues(alpha: 0.4), width: 1),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                          color: textColor,
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final greyColor = isDark ? _kGrey : Colors.grey[600]!;

    if (engine.isLoading && engine.stations.isEmpty) {
      return SliverToBoxAdapter(child: _buildShimmer(context));
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
                  size: 72, color: textColor.withValues(alpha: 0.1)),
              const SizedBox(height: 16),
              Text(
                engine.errorMessage ?? 'No stations found',
                style: TextStyle(color: greyColor, fontSize: 15),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => engine.loadTopStations(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
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
    final isSearching = _searchController.text.isNotEmpty;

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
                    Text(
                      isSearching ? 'Search Results' : 'Top Stations',
                      style: TextStyle(
                          color: textColor,
                          fontSize: 17,
                          fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.primaryColor.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        '${engine.stations.length}',
                        style: TextStyle(
                            color: theme.primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            }
            
            if (index <= stations.length) {
              return _StationListItem(
                station: stations[index - 1],
                engine: engine,
              );
            }

            // Streema Footer for search
            if (isSearching) {
              return _buildStreemaFooter(context, _searchController.text);
            }
            return const SizedBox(height: 80);
          },
          childCount: stations.length + (isSearching ? 2 : 1),
        ),
      ),
    );
  }

  Widget _buildStreemaFooter(BuildContext context, String query) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final greyColor = isDark ? _kGrey : Colors.grey[600]!;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
      child: Column(
        children: [
          Text(
            "Can't find your favorite station?",
            style: TextStyle(color: greyColor.withValues(alpha: 0.7), fontSize: 13),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () {
              final radioService = context.read<RadioService>();
              final url = radioService.getStreemaSearchUrl(query);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => StreemaBrowserScreen(url: url),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: theme.primaryColor.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.travel_explore_rounded, size: 18, color: theme.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'Search Streema Global Directory',
                    style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Column(
      children: List.generate(
        8,
        (i) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Shimmer.fromColors(
            baseColor: isDark ? theme.cardColor : Colors.grey[300]!,
            highlightColor: isDark ? theme.cardColor.withValues(alpha: 0.5) : Colors.grey[100]!,
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 12),
      child: Row(
        children: [
          Text(title,
              style: TextStyle(
                  color: textColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w700)),
          const Spacer(),
          GestureDetector(
            onTap: onViewAll,
            child: Text('View All',
                style: TextStyle(
                    color: theme.primaryColor, fontSize: 13, fontWeight: FontWeight.w600)),
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
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.primaryColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.primaryColor.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.primaryColor
                      .withValues(alpha: 0.5 + 0.5 * _ctrl.value)),
            ),
            const SizedBox(width: 5),
            Text('LIVE',
                style: TextStyle(
                    color: theme.primaryColor,
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final greyColor = isDark ? theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6) ?? Colors.grey : Colors.grey[600]!;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.primaryColor.withValues(alpha: 0.3)),
              boxShadow: isDark ? [
                BoxShadow(
                    color: theme.primaryColor.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ] : [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Icon(icon, color: theme.primaryColor, size: 24),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
                color: greyColor, fontSize: 10, fontWeight: FontWeight.w500),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 110,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isPlaying ? theme.primaryColor : textColor.withValues(alpha: 0.06),
              width: isPlaying ? 1.5 : 1),
          boxShadow: isPlaying
              ? [BoxShadow(color: theme.primaryColor.withValues(alpha: 0.2), blurRadius: 12)]
              : (isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? Colors.black : Colors.white,
                  border: Border.all(
                      color: theme.primaryColor.withValues(alpha: 0.4), width: 1.5)),
              child: FluxImage(
                imageUrl: station.favicon,
                width: 52,
                height: 52,
                placeholder: Icon(Icons.radio_rounded,
                    color: theme.primaryColor, size: 22),
                errorWidget: Icon(Icons.radio_rounded,
                    color: theme.primaryColor, size: 22),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                station.name,
                style: TextStyle(
                    color: isPlaying ? theme.primaryColor : textColor,
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.primaryColor.withValues(alpha: 0.25)),
          boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.flag_rounded, color: theme.primaryColor, size: 26),
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                country,
                style: TextStyle(
                    color: textColor, fontSize: 10, fontWeight: FontWeight.w500),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? (isDark ? Colors.white : Colors.black);
    final greyColor = isDark ? theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6) ?? Colors.grey : Colors.grey[600]!;
    
    final isPlaying = engine.currentStation?.name == station.name && engine.isPlaying;
    final isLoading = engine.isLoading && engine.currentStation?.name == station.name;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isPlaying ? theme.primaryColor.withValues(alpha: 0.06) : theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPlaying ? theme.primaryColor.withValues(alpha: 0.5) : textColor.withValues(alpha: 0.05),
          width: isPlaying ? 1.5 : 1,
        ),
        boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: isLoading ? null : () async {
          final messenger = ScaffoldMessenger.of(context);
          try {
            await engine.playStation(station);
            if (context.mounted) {
              Navigator.of(context).push(NavigationHelper.slideUpRoute(NowPlayingScreen(engine: engine)));
            }
            if (engine.errorMessage != null && context.mounted) {
              messenger.showSnackBar(SnackBar(
                content: Text(engine.errorMessage!),
                backgroundColor: theme.primaryColor,
                action: (engine.errorMessage!.contains('broken') || engine.errorMessage!.contains('unavailable'))
                    ? SnackBarAction(
                        label: 'Report',
                        textColor: Colors.white,
                        onPressed: () => engine.reportBrokenStation(station.uuid ?? ''),
                      )
                    : SnackBarAction(
                        label: 'Retry',
                        textColor: Colors.white,
                        onPressed: () => engine.playStation(station)),
              ));
            }
          } catch (e) {
            if (context.mounted) {
              messenger.showSnackBar(SnackBar(
                content: const Text('We couldn\'t play this station right now.'),
                backgroundColor: theme.primaryColor,
                action: SnackBarAction(
                    label: 'Retry',
                    textColor: Colors.white,
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
                      color: isDark ? Colors.black : Colors.white,
                      border: Border.all(
                          color: isPlaying
                              ? theme.primaryColor
                              : textColor.withValues(alpha: 0.1),
                          width: 1.5),
                    ),
                    child: FluxImage(
                      imageUrl: station.favicon,
                      width: 46,
                      height: 46,
                      placeholder: Icon(Icons.radio_rounded,
                          color: theme.primaryColor, size: 18),
                      errorWidget: Icon(Icons.radio_rounded,
                          color: theme.primaryColor, size: 18),
                    ),
                  ),
                  if (isLoading)
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(theme.primaryColor)),
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
                          color: isPlaying ? theme.primaryColor : textColor,
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
                          TextStyle(color: greyColor, fontSize: 11),
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
                      ? theme.primaryColor
                      : theme.primaryColor.withValues(alpha: 0.12),
                ),
                child: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: isPlaying ? Colors.white : theme.primaryColor,
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
