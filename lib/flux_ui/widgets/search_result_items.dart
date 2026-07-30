import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../flux_engine/playback_controller.dart';
import '../../flux_hardware/radio_service.dart';
import '../models/podcast.dart';
import '../now_playing_screen.dart';
import '../podcast_details_screen.dart';
import '../../flux_engine/library_manager.dart';
import '../../helpers/navigation_helper.dart';
import 'flux_image.dart';

class StationResultItem extends StatelessWidget {
  final RadioStation station;
  const StationResultItem({super.key, required this.station});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playbackController = context.read<PlaybackController>();
    final libraryManager = context.read<LibraryManager>();
    
    final primaryColor = theme.colorScheme.primary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outline,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.15),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: FluxImage(
              imageUrl: station.favicon,
              width: 54,
              height: 54,
              placeholder: Container(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Icon(Icons.radio_rounded, color: primaryColor, size: 30),
              ),
              errorWidget: Container(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Icon(Icons.radio_rounded, color: primaryColor, size: 30),
              ),
            ),
          ),
        ),
        title: Text(
          station.name.toUpperCase(),
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w900,
            fontSize: 13,
            letterSpacing: -0.5,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            '${station.country} • ${station.genre}'.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FutureBuilder<bool>(
              future: libraryManager.isFavorite(station.url, uuid: station.uuid),
              builder: (context, snapshot) {
                final isFav = snapshot.data ?? false;
                return IconButton(
                  icon: Icon(
                    isFav ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                    color: isFav ? primaryColor : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    size: 24,
                  ),
                  onPressed: () => libraryManager.toggleFavorite(station),
                );
              },
            ),
            const SizedBox(width: 4),
            Container(
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: primaryColor.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: IconButton(
                icon: Icon(Icons.play_arrow_rounded, color: primaryColor, size: 28),
                onPressed: () => _playStation(context, station, playbackController),
              ),
            ),
          ],
        ),
        onTap: () => _playStation(context, station, playbackController),
        onLongPress: () => _showContextMenu(context, libraryManager),
      ),
    );
  }

  void _showContextMenu(BuildContext context, LibraryManager libraryManager) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.favorite_rounded),
              title: const Text('Add to Favorites'),
              onTap: () {
                libraryManager.toggleFavorite(station);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_rounded),
              title: const Text('Share'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _playStation(BuildContext context, RadioStation station, PlaybackController playbackController) {
    playbackController.playStation(station).then((_) {
      if (context.mounted) {
        Navigator.of(context).push(NavigationHelper.slideUpRoute(const NowPlayingScreen()));
      }
    });
  }
}

class PodcastResultItem extends StatelessWidget {
  final Podcast podcast;
  const PodcastResultItem({super.key, required this.podcast});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outline,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: FluxImage(
            imageUrl: podcast.image,
            width: 52,
            height: 52,
            errorWidget: Container(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Icon(Icons.podcasts_rounded, color: theme.colorScheme.primary, size: 28),
            ),
          ),
        ),
        title: Text(
          podcast.title.toUpperCase(),
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w900,
            fontSize: 14,
            letterSpacing: -0.5,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            podcast.publisher.toUpperCase(),
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: theme.colorScheme.primary),
        onTap: () {
          Navigator.push(
            context,
            NavigationHelper.slideUpRoute(PodcastDetailsScreen(podcast: podcast)),
          );
        },
      ),
    );
  }
}
