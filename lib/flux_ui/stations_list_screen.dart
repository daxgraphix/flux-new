import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'streema_browser_screen.dart';
import '../flux_engine/station_provider.dart';
import '../flux_engine/playback_controller.dart';
import '../flux_hardware/radio_service.dart';
import '../helpers/navigation_helper.dart';
import 'now_playing_screen.dart';
import 'widgets/flux_image.dart';
import 'widgets/empty_state_widget.dart';
import 'widgets/shimmer_list_widget.dart';

class StationsListScreen extends StatefulWidget {
  final String title;
  final String? flag;
  final List<Widget>? actions;

  const StationsListScreen({
    super.key,
    required this.title,
    this.flag,
    this.actions,
  });

  @override
  State<StationsListScreen> createState() => _StationsListScreenState();
}

class _StationsListScreenState extends State<StationsListScreen> {
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Container(
        color: theme.scaffoldBackgroundColor,
        child: SafeArea(
          child: Consumer2<StationProvider, PlaybackController>(
            builder: (context, provider, playback, child) {
              return Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back, color: theme.primaryColor),
                          onPressed: () => Navigator.pop(context),
                        ),
                        if (widget.flag != null) ...[
                          Text(
                            widget.flag!,
                            style: const TextStyle(fontSize: 28),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Text(
                            widget.title,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (widget.actions != null) ...widget.actions!,
                      ],
                    ),
                  ),
                  // Stations count
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '${provider.stations.length} stations found',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Stations list
                  Expanded(
                    child: provider.isLoading
                        ? LayoutBuilder(
                            builder: (context, constraints) {
                              return ShimmerListWidget(isGrid: constraints.maxWidth >= 600);
                            },
                          )
                        : provider.stations.isEmpty
                            ? EmptyStateWidget(
                                icon: Icons.radio,
                                title: 'No stations found',
                                message: 'We couldn\'t find any stations matching your search.',
                                buttonLabel: 'Search Directory',
                                onButtonPressed: () {
                                  final url = RadioService().getStreemaSearchUrl(widget.title);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => StreemaBrowserScreen(url: url),
                                    ),
                                  );
                                },
                              )
                            : LayoutBuilder(
                                builder: (context, constraints) {
                                  final isTablet = constraints.maxWidth >= 600;
                                  if (isTablet) {
                                    return GridView.builder(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: constraints.maxWidth > 900 ? 3 : 2,
                                        childAspectRatio: 3.5,
                                        crossAxisSpacing: 12,
                                        mainAxisSpacing: 8,
                                      ),
                                      itemCount: provider.stations.length + 1,
                                      itemBuilder: (context, index) {
                                        if (index == provider.stations.length) {
                                          return _buildStreemaFooter(widget.title);
                                        }
                                        final station = provider.stations[index];
                                        return _buildStationItem(station, playback);
                                      },
                                    );
                                  }
                                  return ListView.builder(
                                    itemCount: provider.stations.length + 1,
                                    itemBuilder: (context, index) {
                                      if (index == provider.stations.length) {
                                        return _buildStreemaFooter(widget.title);
                                      }
                                      final station = provider.stations[index];
                                      return _buildStationItem(station, playback);
                                    },
                                  );
                                },
                              ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStationItem(RadioStation station, PlaybackController playback) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: FluxImage(
            imageUrl: station.favicon,
            width: 52,
            height: 52,
            errorWidget: Container(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Icon(Icons.radio_rounded, color: theme.primaryColor, size: 28),
            ),
          ),
        ),
        title: Text(
          station.name,
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            '${station.country} • ${station.genre}',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: Container(
          decoration: BoxDecoration(
            color: theme.primaryColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(Icons.play_arrow_rounded, color: theme.primaryColor, size: 24),
            onPressed: () {
              playback.playStation(station);
              Navigator.of(context).push(NavigationHelper.slideUpRoute(const NowPlayingScreen()));
            },
          ),
        ),
        onTap: () {
          playback.playStation(station);
          Navigator.of(context).push(NavigationHelper.slideUpRoute(const NowPlayingScreen()));
        },
      ),
    );
  }

  Widget _buildStreemaFooter(String query) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      child: Column(
        children: [
          Text(
            "Can't find what you're looking for?",
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7), fontSize: 13),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () {
              final url = RadioService().getStreemaSearchUrl(query);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StreemaBrowserScreen(url: url),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: theme.primaryColor.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.travel_explore_rounded, size: 20, color: theme.primaryColor),
                  const SizedBox(width: 10),
                  Text(
                    'Search Streema Directory',
                    style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
