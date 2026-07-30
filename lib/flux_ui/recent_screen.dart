import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../flux_engine/playback_controller.dart';
import '../flux_engine/library_manager.dart';
import '../flux_hardware/radio_service.dart';
import '../helpers/navigation_helper.dart';
import 'widgets/flux_image.dart';
import 'widgets/empty_state_widget.dart';
import 'now_playing_screen.dart';

class RecentScreen extends StatefulWidget {
  const RecentScreen({super.key});

  @override
  State<RecentScreen> createState() => _RecentScreenState();
}

class _RecentScreenState extends State<RecentScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LibraryManager>().loadRecentStations();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recently Played', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: 0,
      ),
      body: Consumer2<LibraryManager, PlaybackController>(
        builder: (context, library, playback, child) {
          final recent = library.recentStations;
          return Container(
            color: theme.colorScheme.surface,
            child: Column(
              children: [
                Expanded(
                  child: recent.isEmpty
                      ? EmptyStateWidget(
                          icon: Icons.history,
                          title: 'No history',
                          message: 'Your recently played stations will appear here.',
                          buttonLabel: 'Listen Now',
                          onButtonPressed: () {
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            }
                          },
                        )
                      : LayoutBuilder(
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
                                itemCount: recent.length,
                                itemBuilder: (context, index) {
                                  return _buildRecentItem(recent[index], playback);
                                },
                              );
                            }
                            return ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: recent.length,
                              itemBuilder: (context, index) {
                                return _buildRecentItem(recent[index], playback);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentItem(RadioStation item, PlaybackController playback) {
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
            imageUrl: item.favicon,
            width: 52,
            height: 52,
            errorWidget: Container(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Icon(Icons.radio_rounded, color: theme.primaryColor, size: 28),
            ),
          ),
        ),
        title: Text(
          item.name.isNotEmpty ? item.name : 'Unknown Station',
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
            "${item.country.isNotEmpty ? item.country : 'Unknown'} • ${item.genre}",
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
              playback.playStation(item).then((_) {
                if (mounted) {
                  Navigator.of(context).push(NavigationHelper.slideUpRoute(const NowPlayingScreen()));
                }
              });
            },
          ),
        ),
        onTap: () {
          playback.playStation(item).then((_) {
            if (mounted) {
              Navigator.of(context).push(NavigationHelper.slideUpRoute(const NowPlayingScreen()));
            }
          });
        },
      ),
    );
  }
}

