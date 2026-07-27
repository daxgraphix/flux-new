import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../flux_engine/radio_engine.dart';
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
      Provider.of<RadioEngine>(context, listen: false).loadRecentStations();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recently Played'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: 0,
      ),
      body: Consumer<RadioEngine>(
        builder: (context, engine, child) {
          final recent = engine.recentStations;
          return Container(
            color: theme.scaffoldBackgroundColor,
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
                            // If this is within LibraryScreen, we might want to switch tabs.
                            // However, RecentScreen is also a standalone screen in some contexts.
                            // For now, let's pop if possible or just navigate to main if we can.
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
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: constraints.maxWidth > 900 ? 3 : 2,
                                  childAspectRatio: 3.5,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 8,
                                ),
                                itemCount: recent.length,
                                itemBuilder: (context, index) {
                                  return _buildRecentItem(recent[index], engine);
                                },
                              );
                            }
                            return ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: recent.length,
                              itemBuilder: (context, index) {
                                return _buildRecentItem(recent[index], engine);
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

  Widget _buildRecentItem(RadioStation item, RadioEngine engine) {
    final theme = Theme.of(context);
    return Card(
      color: theme.cardColor,
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 4,
      ),
      child: ListTile(
        leading: FluxImage(
          imageUrl: item.favicon,
          width: 40,
          height: 40,
          errorWidget: CircleAvatar(
            backgroundColor: theme.primaryColor,
            child: const Icon(
              Icons.history,
              color: Colors.white,
            ),
          ),
        ),
        title: Text(
          item.name.isNotEmpty ? item.name : 'Unknown Station',
          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          "${item.country.isNotEmpty ? item.country : 'Unknown'} • ${item.genre}",
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: Icon(
            Icons.play_arrow,
            color: theme.primaryColor,
          ),
          onPressed: () {
            engine.playStation(item).then((_) {
              if (mounted) {
                Navigator.of(context).push(NavigationHelper.slideUpRoute(NowPlayingScreen(engine: engine)));
              }
            }).catchError((e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to play: ${item.name}'),
                    backgroundColor: theme.colorScheme.error,
                  ),
                );
              }
            });
          },
        ),
        onTap: () {
          engine.playStation(item).then((_) {
            if (mounted) {
              Navigator.of(context).push(NavigationHelper.slideUpRoute(NowPlayingScreen(engine: engine)));
            }
          }).catchError((e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to play: ${item.name}'),
                  backgroundColor: theme.colorScheme.error,
                ),
              );
            }
          });
        },
      ),
    );
  }
}
