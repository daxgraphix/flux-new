import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../flux_engine/playback_controller.dart';
import '../flux_engine/station_provider.dart';
import '../flux_engine/download_service.dart';
import '../flux_engine/library_manager.dart';
import '../helpers/navigation_helper.dart';
import '../flux_engine/app_exception.dart';
import 'models/podcast.dart';
import 'widgets/flux_image.dart';
import 'widgets/shimmer_list_widget.dart';
import 'now_playing_screen.dart';
import 'package:intl/intl.dart';
import 'route_observer.dart';

class PodcastDetailsScreen extends StatefulWidget {
  final Podcast podcast;

  const PodcastDetailsScreen({super.key, required this.podcast});

  @override
  State<PodcastDetailsScreen> createState() => _PodcastDetailsScreenState();
}

class _PodcastDetailsScreenState extends State<PodcastDetailsScreen> with RouteAware {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<StationProvider>(context, listen: false).loadEpisodes(widget.podcast.rss);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<StationProvider>(context, listen: false).loadEpisodes(widget.podcast.rss);
      }
    });
  }

  Future<void> _refreshEpisodes() async {
    final stationProvider = Provider.of<StationProvider>(context, listen: false);
    await stationProvider.loadEpisodes(widget.podcast.rss);
  }

@override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final isTablet = width >= 600;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Consumer<StationProvider>(
        builder: (context, stationProvider, _) {
          if (stationProvider.isLoading && stationProvider.episodes.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return Center(
            child: SizedBox(
              width: isTablet ? 600 : double.infinity,
              child: RefreshIndicator(
                onRefresh: _refreshEpisodes,
                child: CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      expandedHeight: 300.0,
                      pinned: true,
                      backgroundColor: theme.scaffoldBackgroundColor,
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      flexibleSpace: FlexibleSpaceBar(
                        background: Stack(
                          fit: StackFit.expand,
                          children: [
                            FluxImage(
                              imageUrl: widget.podcast.image,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    theme.scaffoldBackgroundColor,
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.podcast.title,
                              style: TextStyle(
                                color: theme.textTheme.titleLarge?.color,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.podcast.publisher,
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Consumer<StationProvider>(
                              builder: (context, stationProvider, _) {
                                if (stationProvider.episodes.isEmpty) return const SizedBox.shrink();
                                return Text(
                                  '${stationProvider.episodes.length} Episodes',
                                  style: TextStyle(
                                    color: theme.textTheme.bodySmall?.color,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            Text(
                              widget.podcast.description,
                              style: TextStyle(
                                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Episodes',
                              style: TextStyle(
                                color: theme.textTheme.titleLarge?.color,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                    Consumer<StationProvider>(
                      builder: (context, stationProvider, child) {
                        if (stationProvider.isLoading && stationProvider.episodes.isEmpty) {
                          return const SliverToBoxAdapter(
                            child: ShimmerListWidget(itemCount: 5),
                          );
                        }

                        if (stationProvider.episodes.isEmpty) {
                          return SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        color: theme.primaryColor.withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.wifi_off_rounded,
                                        size: 64,
                                        color: theme.primaryColor,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      'Unable to load episodes',
                                      style: theme.textTheme.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Check your connection and try again.',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 32),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            Provider.of<StationProvider>(context, listen: false).loadEpisodes(widget.podcast.rss);
                                          },
                                          icon: const Icon(Icons.refresh_rounded, size: 18),
                                          label: const Text('RETRY', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: theme.primaryColor,
                                            foregroundColor: theme.colorScheme.onPrimary,
                                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(30),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        OutlinedButton.icon(
                                          onPressed: () => Navigator.pop(context),
                                          icon: const Icon(Icons.arrow_back_rounded, size: 18),
                                          label: const Text('BACK', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: theme.primaryColor,
                                            side: BorderSide(color: theme.primaryColor),
                                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(30),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }

                        return SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final episode = stationProvider.episodes[index];
                              return _EpisodeListItem(episode: episode);
                            },
                            childCount: stationProvider.episodes.length,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EpisodeListItem extends StatelessWidget {
  final Episode episode;

  const _EpisodeListItem({required this.episode});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playbackController = Provider.of<PlaybackController>(context);
    final downloadService = Provider.of<DownloadService>(context);
    final libraryManager = Provider.of<LibraryManager>(context);
    
    final dateStr = DateFormat('MMM d, yyyy').format(episode.pubDate);
    final durationStr = '${(episode.duration / 60).floor()} min';
    
    final isDownloading = downloadService.isDownloading(episode.id);
    final downloadProgress = downloadService.getDownloadProgress(episode.id);
    final isDownloaded = episode.isDownloaded;

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
        contentPadding: const EdgeInsets.all(12),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: FluxImage(
            imageUrl: episode.image.isNotEmpty ? episode.image : '',
            width: 52,
            height: 52,
            errorWidget: Container(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Icon(Icons.mic_rounded, color: theme.primaryColor, size: 28),
            ),
          ),
        ),
        title: Text(
          episode.title,
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              episode.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '$dateStr • $durationStr',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (isDownloaded) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.offline_pin_rounded, color: Colors.green, size: 16),
                ],
                if (episode.lastPosition > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${(episode.lastPosition / 60).floor()}m left',
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
            if (episode.lastPosition > 0 && episode.duration > 0) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: episode.lastPosition / episode.duration,
                  backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
                  color: theme.primaryColor,
                  minHeight: 2,
                ),
              ),
            ],
          ],
        ),
        trailing: isDownloading
            ? InkWell(
                onTap: () => downloadService.cancelDownload(episode.id),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: downloadProgress > 0 ? downloadProgress : null,
                        strokeWidth: 2,
                        color: theme.colorScheme.error,
                      ),
                      Icon(Icons.close_rounded, size: 12, color: theme.colorScheme.error),
                    ],
                  ),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _BookmarkButton(episode: episode, libraryManager: libraryManager, theme: theme),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(
                      isDownloaded ? Icons.delete_outline_rounded : Icons.download_for_offline_rounded,
                      color: isDownloaded ? theme.colorScheme.onSurfaceVariant : theme.primaryColor,
                    ),
                    onPressed: () {
                      if (isDownloaded) {
                        downloadService.deleteDownloadedEpisode(episode);
                      } else {
                        downloadService.downloadEpisode(episode);
                      }
                    },
                  ),
                ],
              ),
        onTap: () => _playEpisode(context, episode, playbackController),
      ),
    );
  }

  void _playEpisode(BuildContext context, Episode episode, PlaybackController playbackController) {
    playbackController.playEpisode(episode).then((_) {
      if (context.mounted) {
        if (playbackController.error != null) {
          _showErrorSnackBar(context, playbackController.error!, () => _playEpisode(context, episode, playbackController));
        } else {
          Navigator.of(context).push(NavigationHelper.slideUpRoute(const NowPlayingScreen()));
        }
      }
    });
  }

  void _showErrorSnackBar(BuildContext context, AppException error, VoidCallback onRetry) {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.localizedMessage),
        backgroundColor: theme.colorScheme.error,
        behavior: SnackBarBehavior.floating,
        action: error.canRetry 
          ? SnackBarAction(
              label: 'RETRY',
              textColor: Colors.white,
              onPressed: onRetry,
            )
          : null,
      ),
    );
  }
}

class _BookmarkButton extends StatelessWidget {
  final Episode episode;
  final LibraryManager libraryManager;
  final ThemeData theme;

  const _BookmarkButton({
    required this.episode,
    required this.libraryManager,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final isBookmarked = libraryManager.bookmarkedEpisodes.any((e) => e.id == episode.id);
    return IconButton(
      icon: Icon(
        isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
        color: isBookmarked ? Colors.amber : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
      ),
      onPressed: () => libraryManager.toggleBookmark(episode),
    );
  }
}
