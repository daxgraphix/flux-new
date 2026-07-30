import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../flux_engine/station_provider.dart';
import 'widgets/search_result_items.dart';
import 'widgets/empty_state_widget.dart';
import 'widgets/shimmer_list_widget.dart';
import 'library_screen.dart';

class FluxSearchDelegate extends SearchDelegate {
  @override
  String get searchFieldLabel => 'Search stations and podcasts';

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      scaffoldBackgroundColor: theme.scaffoldBackgroundColor,
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          fontWeight: FontWeight.w900,
          fontSize: 18,
          letterSpacing: -0.5,
        ),
        border: InputBorder.none,
      ),
      textTheme: theme.textTheme.copyWith(
        titleLarge: TextStyle(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w900,
          fontSize: 18,
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: IconButton(
            icon: const Icon(Icons.clear_rounded),
            onPressed: () {
              query = '';
              showSuggestions(context);
            },
          ),
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    if (query.trim().isEmpty) return const SizedBox.shrink();
    
    // Trigger search
    final stationProvider = Provider.of<StationProvider>(context, listen: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      stationProvider.searchGlobal(query);
    });

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _buildSearchResults(context),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final theme = Theme.of(context);
    if (query.isEmpty) {
      return Container(
        color: theme.scaffoldBackgroundColor,
        child: _buildInitialState(context),
      );
    }
    
    final stationProvider = Provider.of<StationProvider>(context, listen: false);
    
    // Filter categories that match the query
    final matchingCategories = stationProvider.categories.where((cat) => 
      (cat['title'] as String).toLowerCase().contains(query.toLowerCase())
    ).toList();

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          if (matchingCategories.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'CATEGORIES'.toUpperCase(),
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            ...matchingCategories.map((cat) => _buildSuggestionItem(
              context,
              icon: cat['icon'] as IconData,
              color: cat['color'] as Color,
              title: cat['title'],
              onTap: () {
                query = cat['title'];
                showResults(context);
              },
            )),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Divider(height: 1),
            ),
          ],
          _buildSuggestionItem(
            context,
            icon: Icons.search_rounded,
            color: theme.colorScheme.primary,
            title: 'Search for "$query"',
            onTap: () => showResults(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionItem(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: color.withValues(alpha: 0.1),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              Icon(
                Icons.north_west_rounded,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context) {
    return Consumer<StationProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const ShimmerListWidget();
        }

        if (provider.errorMessage != null && provider.stations.isEmpty && provider.podcasts.isEmpty) {
          return EmptyStateWidget(
            icon: Icons.search_off_rounded,
            title: 'No results',
            message: provider.errorMessage!,
            buttonLabel: 'Try Again',
            onButtonPressed: () => provider.searchGlobal(query),
          );
        }

        final stations = provider.stations;
        final podcasts = provider.podcasts;

        if (stations.isEmpty && podcasts.isEmpty) {
          return EmptyStateWidget(
            icon: Icons.search_rounded,
            title: 'No matches found',
            message: 'We couldn\'t find any stations or podcasts for "$query".',
          );
        }

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            if (stations.isNotEmpty) ...[
              _buildSectionHeader(
                context, 
                'STATIONS', 
                stations.length,
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (ctx) => CategoryScreen(
                      title: 'Stations: $query',
                      loadFunction: () => provider.searchStations(query),
                      searchType: SearchType.station,
                    ),
                  ));
                },
              ),
              ...stations.take(10).map((s) => StationResultItem(station: s)),
            ],
            if (podcasts.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildSectionHeader(
                context, 
                'PODCASTS', 
                podcasts.length,
                onTap: () {
                   Navigator.of(context).push(MaterialPageRoute(
                    builder: (ctx) => CategoryScreen(
                      title: 'Podcasts: $query',
                      loadFunction: () => provider.searchPodcasts(query),
                      searchType: SearchType.podcast,
                    ),
                  ));
                },
              ),
              ...podcasts.take(10).map((p) => PodcastResultItem(podcast: p)),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, int count, {VoidCallback? onTap}) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title.toUpperCase(),
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            Row(
              children: [
                Text(
                  '$count found'.toUpperCase(),
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialState(BuildContext context) {
    final theme = Theme.of(context);
    final stationProvider = Provider.of<StationProvider>(context, listen: false);
    final categories = stationProvider.categories;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Text(
            'QUICK BROWSE',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              return InkWell(
                onTap: () {
                  query = cat['title'];
                  showResults(context);
                },
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  decoration: BoxDecoration(
                    color: (cat['color'] as Color).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: (cat['color'] as Color).withValues(alpha: 0.15),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(cat['icon'] as IconData, size: 20, color: cat['color'] as Color),
                      const SizedBox(width: 8),
                      Text(
                        cat['title'],
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
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
