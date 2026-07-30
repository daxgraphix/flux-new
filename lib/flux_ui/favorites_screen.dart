import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../flux_engine/playback_controller.dart';
import '../flux_engine/library_manager.dart';
import '../helpers/navigation_helper.dart';
import 'widgets/flux_image.dart';
import 'widgets/empty_state_widget.dart';
import 'now_playing_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LibraryManager>().loadFavorites();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Favorites',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: -1.2,
            fontSize: 24,
            color: theme.colorScheme.onSurface,
          ),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      body: Consumer2<LibraryManager, PlaybackController>(
        builder: (context, library, playback, child) {
          final favorites = library.favorites;
          return Container(
            color: theme.colorScheme.surface,
            child: Column(
              children: [
                Expanded(
                  child: favorites.isEmpty
                      ? EmptyStateWidget(
                          icon: Icons.favorite_border,
                          title: 'No favorites',
                          message: 'Your favorite stations will appear here.',
                          buttonLabel: 'Explore Stations',
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
                                itemCount: favorites.length,
                                itemBuilder: (context, index) {
                                  return _buildFavoriteItem(context, favorites[index], playback, library);
                                },
                              );
                            }
                            return ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: favorites.length,
                              itemBuilder: (context, index) {
                                return _buildFavoriteItem(context, favorites[index], playback, library);
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

  Widget _buildFavoriteItem(BuildContext context, dynamic favorite, PlaybackController playback, LibraryManager library) {
    final theme = Theme.of(context);
    final station = favorite.toRadioStation();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
          width: 1.5,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(16),
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
          station.name.isNotEmpty ? station.name : 'Unknown Station',
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
            "${station.country.isNotEmpty ? station.country : 'Unknown'} • ${station.genre}",
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  width: 1.5,
                ),
              ),
              child: IconButton(
                icon: Icon(Icons.play_arrow_rounded, color: theme.colorScheme.primary, size: 28),
                onPressed: () async {
                  await playback.playStation(station);
                  if (context.mounted) {
                    Navigator.of(context).push(NavigationHelper.slideUpRoute(const NowPlayingScreen()));
                  }
                },
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.favorite, color: theme.colorScheme.primary, size: 24),
              onPressed: () {
                library.toggleFavorite(station);
              },
            ),
          ],
        ),
        onTap: () async {
          await playback.playStation(station);
          if (context.mounted) {
            Navigator.of(context).push(NavigationHelper.slideUpRoute(const NowPlayingScreen()));
          }
        },
      ),
    );
  }
}
