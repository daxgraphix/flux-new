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
import 'podcast_details_screen.dart';
import 'models/podcast.dart';

import 'widgets/flux_image.dart';
import 'widgets/empty_state_widget.dart';

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
      final engine = context.read<RadioEngine>();
      if (engine.searchType == SearchType.station) {
        engine.loadTopStationsIfNeeded();
      }
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        final engine = context.read<RadioEngine>();
        engine.search(value);
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
                                  onTap: () {
                                    engine.playStation(favs[i]);
                                    Navigator.of(context).push(NavigationHelper.slideUpRoute(NowPlayingScreen(engine: engine)));
                                  },
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
                                  onTap: () {
                                    engine.playStation(recent[i]);
                                    Navigator.of(context).push(NavigationHelper.slideUpRoute(NowPlayingScreen(engine: engine)));
                                  },
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
                              NavigationHelper.slideRightRoute(const CountriesScreen()))),
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
                                      NavigationHelper.slideRightRoute(const LibraryScreen()));
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
    final textColor = theme.colorScheme.onSurface;

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
                  child: Text(
                    'FLUX',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary,
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
                boxShadow: [
                   BoxShadow(
                    color: theme.shadowColor.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 8, right: 8),
                    child: Row(
                      children: [
                        _SearchTypeTab(
                          label: 'Stations',
                          isSelected: engine.searchType == SearchType.station,
                          onTap: () {
                            engine.setSearchType(SearchType.station);
                            if (_searchController.text.isNotEmpty) {
                              _debouncedSearch(_searchController.text);
                            } else {
                              engine.loadTopStationsIfNeeded();
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        _SearchTypeTab(
                          label: 'Podcasts',
                          isSelected: engine.searchType == SearchType.podcast,
                          onTap: () {
                            engine.setSearchType(SearchType.podcast);
                            if (_searchController.text.isNotEmpty) {
                              _debouncedSearch(_searchController.text);
                            } else {
                              engine.loadTrendingPodcasts();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 12, thickness: 0.5, indent: 12, endIndent: 12),
                  TextField(
                    controller: _searchController,
                    style: TextStyle(color: textColor, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: engine.searchType == SearchType.station 
                          ? 'Search 50,000+ stations...' 
                          : 'Search millions of podcasts...',
                      hintStyle:
                          TextStyle(color: textColor.withValues(alpha: 0.3), fontSize: 14),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
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
                                if (engine.searchType == SearchType.station) {
                                  engine.loadTopStationsIfNeeded();
                                }
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
            if (_searchController.text.isEmpty && engine.recentSearches.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12, right: 4),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => engine.clearRecentSearches(),
                    icon: Icon(Icons.delete_sweep_outlined, size: 16, color: theme.primaryColor),
                    label: Text('Clear History', style: TextStyle(color: theme.primaryColor, fontSize: 12, fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentSearches(BuildContext context, RadioEngine engine) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;

    return Container(
      height: 48,
      padding: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: engine.recentSearches.length,
        itemBuilder: (context, index) {
          final query = engine.recentSearches[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Chip(
              label: Text(query, style: TextStyle(color: textColor, fontSize: 11)),
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              side: BorderSide(color: theme.primaryColor.withValues(alpha: 0.3)),
              padding: EdgeInsets.zero,
              onDeleted: () => engine.removeRecentSearch(query),
              deleteIcon: const Icon(Icons.close, size: 14),
              deleteIconColor: theme.primaryColor.withValues(alpha: 0.6),
              deleteButtonTooltipMessage: 'Remove',
              clipBehavior: Clip.antiAlias,
              labelPadding: const EdgeInsets.only(left: 8, right: 0),
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
              NavigationHelper.slideRightRoute(const CountriesScreen()))),
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
    final textColor = theme.colorScheme.onSurface;
    
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
                  onTap: () => engine.searchStations(null, tag: tag, limit: 50),
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
    final textColor = theme.colorScheme.onSurface;

    if (engine.isLoading && engine.stations.isEmpty && engine.podcasts.isEmpty) {
      return SliverToBoxAdapter(child: _buildShimmer(context));
    }

    final isPodcast = engine.searchType == SearchType.podcast;
    final resultsCount = isPodcast ? engine.podcasts.length : engine.stations.length;

    if (resultsCount == 0 && !engine.isLoading) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: EmptyStateWidget(
            icon: isPodcast ? Icons.podcasts_rounded : Icons.radio_rounded,
            title: isPodcast ? 'No podcasts found' : 'No stations found',
            message: engine.errorMessage ?? 'Try adjusting your search or explore other categories.',
            buttonLabel: 'Reset Search',
            onButtonPressed: () {
              _searchController.clear();
              setState(() {});
              if (isPodcast) {
                // podcasts don't have a "top" list currently in this view
              } else {
                engine.loadTopStations();
              }
            },
          ),
        ),
      );
    }

    final isSearching = _searchController.text.isNotEmpty;
    final stations = engine.stations.take(50).toList();
    final podcasts = engine.podcasts.take(50).toList();

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
                      isSearching 
                          ? (isPodcast ? 'Podcast Results' : 'Search Results') 
                          : (isPodcast ? 'Recent Podcasts' : 'Top Stations'),
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
                        '$resultsCount',
                        style: TextStyle(
                            color: theme.primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            }
            
            if (isPodcast) {
              if (index <= podcasts.length) {
                return _PodcastListItem(
                  podcast: podcasts[index - 1],
                  onTap: () {
                    Navigator.push(
                      context,
                      NavigationHelper.slideRightRoute(
                        PodcastDetailsScreen(podcast: podcasts[index - 1]),
                      ),
                    );
                  },
                );
              }
            } else {
              if (index <= stations.length) {
                return _StationListItem(
                  station: stations[index - 1],
                  engine: engine,
                );
              }
            }

            // Streema Footer for radio search
            if (isSearching && !isPodcast) {
              return _buildStreemaFooter(context, _searchController.text);
            }
            return const SizedBox(height: 80);
          },
          childCount: (isPodcast ? podcasts.length : stations.length) + (isSearching && !isPodcast ? 2 : 1),
        ),
      ),
    );
  }

  Widget _buildStreemaFooter(BuildContext context, String query) {
    final theme = Theme.of(context);
    final greyColor = theme.colorScheme.onSurfaceVariant;

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
    final baseColor = theme.colorScheme.surfaceContainerHighest;
    final highlightColor = theme.colorScheme.surface;
    
    return Column(
      children: List.generate(
        8,
        (i) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            child: Row(
              children: [
                Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                        color: highlightColor, shape: BoxShape.circle)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          width: double.infinity,
                          height: 14,
                          color: highlightColor),
                      const SizedBox(height: 8),
                      Container(width: 120, height: 10, color: highlightColor),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: highlightColor, shape: BoxShape.circle)),
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
    final textColor = theme.colorScheme.onSurface;

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
    final greyColor = theme.colorScheme.onSurfaceVariant;

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
              boxShadow: [
                BoxShadow(
                    color: theme.shadowColor.withValues(alpha: 0.1),
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
    final textColor = theme.colorScheme.onSurface;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 110,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isPlaying ? theme.primaryColor : textColor.withValues(alpha: 0.1),
              width: isPlaying ? 1.5 : 1),
          boxShadow: isPlaying
              ? [BoxShadow(color: theme.primaryColor.withValues(alpha: 0.2), blurRadius: 12)]
              : [BoxShadow(color: theme.shadowColor.withValues(alpha: 0.1), blurRadius: 4)],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.surface,
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
    final textColor = theme.colorScheme.onSurface;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.primaryColor.withValues(alpha: 0.25)),
          boxShadow: [BoxShadow(color: theme.shadowColor.withValues(alpha: 0.1), blurRadius: 4)],
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
    final textColor = theme.colorScheme.onSurface;
    final greyColor = theme.colorScheme.onSurfaceVariant;
    
    final isPlaying = engine.currentStation?.name == station.name && engine.isPlaying;
    final isLoading = engine.isLoading && engine.currentStation?.name == station.name;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isPlaying ? theme.primaryColor.withValues(alpha: 0.06) : theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPlaying ? theme.primaryColor.withValues(alpha: 0.5) : textColor.withValues(alpha: 0.1),
          width: isPlaying ? 1.5 : 1,
        ),
        boxShadow: [BoxShadow(color: theme.shadowColor.withValues(alpha: 0.1), blurRadius: 4)],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: isLoading ? null : () {
          engine.playStation(station);
          Navigator.of(context).push(NavigationHelper.slideUpRoute(NowPlayingScreen(engine: engine)));
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
                      color: theme.colorScheme.surface,
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
                          color: theme.colorScheme.surface.withValues(alpha: 0.7),
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
                  color: isPlaying ? theme.colorScheme.onPrimary : theme.primaryColor,
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

class _SearchTypeTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SearchTypeTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? theme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
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
    final textColor = theme.colorScheme.onSurface;
    final greyColor = theme.colorScheme.onSurfaceVariant;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: textColor.withValues(alpha: 0.1)),
        boxShadow: [BoxShadow(color: theme.shadowColor.withValues(alpha: 0.1), blurRadius: 4)],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: FluxImage(
                  imageUrl: podcast.image,
                  width: 52,
                  height: 52,
                  placeholder: Icon(Icons.podcasts_rounded, color: theme.primaryColor, size: 24),
                  errorWidget: Icon(Icons.podcasts_rounded, color: theme.primaryColor, size: 24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      podcast.title,
                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      podcast.publisher,
                      style: TextStyle(color: greyColor, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: greyColor.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}
