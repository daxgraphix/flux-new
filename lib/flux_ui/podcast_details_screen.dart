import 'dart:ui';
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
import 'widgets/empty_state_widget.dart';
import 'now_playing_screen.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
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
    final libraryManager = Provider.of<LibraryManager>(context);
    final isFollowing = libraryManager.isFollowingPodcast(widget.podcast.id);
    final notificationsEnabled = libraryManager.areNotificationsEnabled(widget.podcast.id);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Consumer<StationProvider>(
        builder: (context, stationProvider, _) {
          return Center(
            child: SizedBox(
              width: isTablet ? 600 : double.infinity,
              child: RefreshIndicator(
                onRefresh: _refreshEpisodes,
                displacement: 100,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverAppBar(
                      expandedHeight: 340.0,
                      pinned: true,
                      stretch: true,
                      backgroundColor: theme.scaffoldBackgroundColor,
                      leading: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ),
                      actions: [
                        if (isFollowing)
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.3),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: Icon(
                                  notificationsEnabled ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
                                  color: notificationsEnabled ? theme.colorScheme.secondary : Colors.white,
                                  size: 20,
                                ),
                                onPressed: () {
                                  libraryManager.togglePodcastNotifications(widget.podcast.id);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(notificationsEnabled ? 'Notifications disabled' : 'Notifications enabled'),
                                      duration: const Duration(seconds: 2),
                                      behavior: SnackBarBehavior.floating,
                                      backgroundColor: theme.colorScheme.primary,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(right: 12.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
                              onPressed: () {
                                Share.share(
                                  'Check out this podcast: ${widget.podcast.title} on Flux Radio!\n\n${widget.podcast.description}',
                                  subject: widget.podcast.title,
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                      flexibleSpace: FlexibleSpaceBar(
                        stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
                        background: Stack(
                          fit: StackFit.expand,
                          children: [
                            Hero(
                              tag: 'podcast_image_${widget.podcast.id}',
                              child: FluxImage(
                                imageUrl: widget.podcast.image,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                            ),
                            // Blur background slightly for better readability
                            Positioned.fill(
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4), // Suble blur for depth
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.black.withValues(alpha: 0.4),
                                        Colors.transparent,
                                        theme.scaffoldBackgroundColor.withValues(alpha: 0.85),
                                        theme.scaffoldBackgroundColor,
                                      ],
                                      stops: const [0.0, 0.4, 0.85, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.podcast.title,
                                        style: TextStyle(
                                          color: theme.colorScheme.onSurface,
                                          fontSize: 26,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        widget.podcast.publisher.toUpperCase(),
                                        style: TextStyle(
                                          color: theme.colorScheme.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                _FollowButton(
                                  isFollowing: isFollowing,
                                  onTap: () => libraryManager.toggleFollowPodcast(widget.podcast),
                                  theme: theme,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (widget.podcast.genres.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Wrap(
                                  spacing: 8,
                                  children: widget.podcast.genres.take(3).map((g) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                                    ),
                                    child: Text(
                                      g.toUpperCase(),
                                      style: TextStyle(
                                        color: theme.colorScheme.primary,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )).toList(),
                                ),
                              ),
                            Text(
                              widget.podcast.description,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 15,
                                height: 1.6,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'EPISODES'.toUpperCase(),
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                if (stationProvider.episodes.isNotEmpty)
                                  Text(
                                    '${stationProvider.episodes.length}',
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 40,
                              height: 3,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(1.5),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                    _buildEpisodesList(context, stationProvider, theme),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEpisodesList(BuildContext context, StationProvider stationProvider, ThemeData theme) {
    if (stationProvider.isLoading && stationProvider.episodes.isEmpty) {
      return const SliverToBoxAdapter(
        child: ShimmerListWidget(itemCount: 5),
      );
    }

    if (stationProvider.episodes.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyStateWidget(
          icon: Icons.wifi_off_rounded,
          title: 'Unable to load episodes',
          message: 'Check your connection and try again.',
          buttonLabel: 'RETRY',
          onButtonPressed: () {
            Provider.of<StationProvider>(context, listen: false).loadEpisodes(widget.podcast.rss);
          },
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final episode = stationProvider.episodes[index];
          return _EpisodeListItem(episode: episode, podcastTitle: widget.podcast.title);
        },
        childCount: stationProvider.episodes.length,
      ),
    );
  }
}

class _FollowButton extends StatelessWidget {
  final bool isFollowing;
  final VoidCallback onTap;
  final ThemeData theme;

  const _FollowButton({required this.isFollowing, required this.onTap, required this.theme});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isFollowing ? Colors.transparent : theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.colorScheme.primary, width: 2.5),
          boxShadow: isFollowing ? [] : [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Text(
          isFollowing ? 'FOLLOWING' : 'FOLLOW',
          style: TextStyle(
            color: isFollowing ? theme.colorScheme.primary : theme.colorScheme.onPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

class _EpisodeListItem extends StatelessWidget {
  final Episode episode;
  final String podcastTitle;

  const _EpisodeListItem({required this.episode, required this.podcastTitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playbackController = Provider.of<PlaybackController>(context);
    final downloadService = Provider.of<DownloadService>(context);
    final libraryManager = Provider.of<LibraryManager>(context);
    
    final dateStr = DateFormat('MMM d, yyyy').format(episode.pubDate);
    final durationStr = episode.duration > 0 ? '${(episode.duration / 60).floor()} min' : 'Unknown';
    
    final isDownloading = downloadService.isDownloading(episode.id);
    final downloadProgress = downloadService.getDownloadProgress(episode.id);
    final isDownloaded = episode.isDownloaded;
    final isPlaying = playbackController.currentEpisode?.id == episode.id;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isPlaying 
            ? theme.colorScheme.primary.withValues(alpha: 0.1) 
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isPlaying 
              ? theme.colorScheme.primary.withValues(alpha: 0.4) 
              : theme.colorScheme.outline.withValues(alpha: 0.1),
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: () => _playEpisode(context, episode, playbackController),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          episode.title,
                          style: TextStyle(
                            color: isPlaying ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                            height: 1.2,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          episode.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                            fontSize: 13,
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildEpisodeActions(context, theme, downloadService, libraryManager, isDownloaded, isDownloading, downloadProgress),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _PlayIndicator(isPlaying: isPlaying, theme: theme),
                  const SizedBox(width: 12),
                  Text(
                    dateStr.toUpperCase(),
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(width: 4, height: 4, decoration: BoxDecoration(shape: BoxShape.circle, color: theme.colorScheme.onSurface.withValues(alpha: 0.3))),
                  const SizedBox(width: 8),
                  Text(
                    durationStr.toUpperCase(),
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  if (isDownloaded) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.offline_pin_rounded, color: theme.colorScheme.secondary, size: 18),
                  ],
                  const Spacer(),
                  if (episode.lastPosition > 0)
                    Text(
                      '${(episode.lastPosition / 60).floor()}M LEFT',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                ],
              ),
              if (episode.lastPosition > 0 && episode.duration > 0) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: episode.lastPosition / episode.duration,
                    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                    color: theme.colorScheme.primary,
                    minHeight: 3,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEpisodeActions(
    BuildContext context, 
    ThemeData theme, 
    DownloadService downloadService, 
    LibraryManager libraryManager,
    bool isDownloaded,
    bool isDownloading,
    double downloadProgress
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BookmarkButton(episode: episode, libraryManager: libraryManager, theme: theme),
        const SizedBox(width: 8),
        if (isDownloading)
          _DownloadProgressIndicator(
            progress: downloadProgress, 
            onCancel: () => downloadService.cancelDownload(episode.id),
            theme: theme
          )
        else
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isDownloaded 
                  ? theme.colorScheme.error.withValues(alpha: 0.1) 
                  : theme.colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                isDownloaded ? Icons.delete_outline_rounded : Icons.download_for_offline_rounded,
                color: isDownloaded ? theme.colorScheme.error : theme.colorScheme.primary,
                size: 20,
              ),
              onPressed: () {
                if (isDownloaded) {
                  downloadService.deleteDownloadedEpisode(episode);
                } else {
                  downloadService.downloadEpisode(episode);
                }
              },
              padding: EdgeInsets.zero,
            ),
          ),
      ],
    );
  }

  void _playEpisode(BuildContext context, Episode episode, PlaybackController playbackController) {
    final epToPlay = episode.podcastTitle == null ? episode.copyWith(podcastTitle: podcastTitle) : episode;
    playbackController.playEpisode(epToPlay).then((_) {
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

class _PlayIndicator extends StatelessWidget {
  final bool isPlaying;
  final ThemeData theme;
  const _PlayIndicator({required this.isPlaying, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isPlaying ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(
        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
        size: 20,
        color: isPlaying ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
      ),
    );
  }
}

class _DownloadProgressIndicator extends StatelessWidget {
  final double progress;
  final VoidCallback onCancel;
  final ThemeData theme;

  const _DownloadProgressIndicator({required this.progress, required this.onCancel, required this.theme});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onCancel,
      child: SizedBox(
        width: 32,
        height: 32,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: progress > 0 ? progress : null,
              strokeWidth: 2,
              color: theme.colorScheme.primary,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            ),
            Icon(Icons.close_rounded, size: 14, color: theme.colorScheme.error),
          ],
        ),
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
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: isBookmarked ? Colors.amber.withValues(alpha: 0.15) : theme.colorScheme.onSurface.withValues(alpha: 0.05),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(
          isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          color: isBookmarked ? Colors.amber : theme.colorScheme.onSurface.withValues(alpha: 0.5),
          size: 20,
        ),
        onPressed: () => libraryManager.toggleBookmark(episode),
        padding: EdgeInsets.zero,
      ),
    );
  }
}
