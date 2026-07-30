import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../flux_engine/station_provider.dart';
import '../flux_engine/playback_controller.dart';
import 'widgets/empty_state_widget.dart';
import 'widgets/shimmer_list_widget.dart';
import 'widgets/flux_image.dart';
import 'now_playing_screen.dart';
import '../helpers/navigation_helper.dart';

class StationsScreen extends StatelessWidget {
  const StationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer2<StationProvider, PlaybackController>(
      builder: (context, stationProvider, playbackController, child) {
        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text(
                        'All Stations',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.2,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded),
                        onPressed: () => stationProvider.loadTopStations(),
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: stationProvider.isLoading
                      ? const ShimmerListWidget()
                      : stationProvider.stations.isEmpty
                          ? EmptyStateWidget(
                              icon: Icons.radio_rounded,
                              title: 'No stations',
                              message: 'We couldn\'t find any radio stations right now.',
                              buttonLabel: 'Refresh',
                              onButtonPressed: () => stationProvider.loadTopStations(),
                            )
                          : ListView.builder(
                          itemCount: stationProvider.stations.length,
                          itemBuilder: (context, index) {
                            final station = stationProvider.stations[index];
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: theme.colorScheme.outline.withValues(alpha: 0.1),
                                  width: 1.5,
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
                                      child: Icon(Icons.radio_rounded, color: theme.colorScheme.primary, size: 30),
                                    ),
                                  ),
                                ),
                                title: Text(
                                  station.name,
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    letterSpacing: -0.5,
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
                                      fontWeight: FontWeight.w900,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                trailing: Container(
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: IconButton(
                                    icon: Icon(Icons.play_arrow_rounded, color: theme.colorScheme.primary, size: 30),
                                    onPressed: () {
                                      playbackController.playStation(station).then((_) {
                                        if (context.mounted) {
                                          Navigator.of(context).push(NavigationHelper.slideUpRoute(const NowPlayingScreen()));
                                        }
                                      });
                                    },
                                  ),
                                ),
                                onTap: () {
                                  playbackController.playStation(station).then((_) {
                                    if (context.mounted) {
                                      Navigator.of(context).push(NavigationHelper.slideUpRoute(const NowPlayingScreen()));
                                    }
                                  });
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
