import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../flux_engine/radio_engine.dart';
import '../helpers/navigation_helper.dart';
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
      Provider.of<RadioEngine>(context, listen: false).loadEpisodes(widget.podcast);
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
        Provider.of<RadioEngine>(context, listen: false).loadEpisodes(widget.podcast);
      }
    });
  }

  Future<void> _refreshEpisodes() async {
    final engine = Provider.of<RadioEngine>(context, listen: false);
    await engine.loadEpisodes(widget.podcast);
    setState(() {});
  }

@override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final isTablet = width >= 600;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Consumer<RadioEngine>(
        builder: (context, engine, _) {
          if (engine.isLoading) {
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
                            Consumer<RadioEngine>(
                              builder: (context, engine, _) {
                                if (engine.episodes.isEmpty) return const SizedBox.shrink();
                                return Text(
                                  '${engine.episodes.length} Episodes',
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
                    Consumer<RadioEngine>(
                      builder: (context, engine, child) {
                        if (engine.isLoading) {
                          return const SliverToBoxAdapter(
                            child: ShimmerListWidget(itemCount: 5),
                          );
                        }

                        if (engine.episodes.isEmpty) {
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
                                            Provider.of<RadioEngine>(context, listen: false).loadEpisodes(widget.podcast);
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
                              final episode = engine.episodes[index];
                              return _EpisodeListItem(episode: episode);
                            },
                            childCount: engine.episodes.length,
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
    final engine = Provider.of<RadioEngine>(context);
    final dateStr = DateFormat('MMM d, yyyy').format(episode.pubDate);
    final durationStr = '${(episode.duration / 60).floor()} min';
    
    final isDownloading = engine.isDownloading(episode.id);
    final downloadProgress = engine.getDownloadProgress(episode.id);
    final isDownloaded = episode.isDownloaded;

    return Card(
      color: theme.cardColor,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: FluxImage(
            imageUrl: episode.image.isNotEmpty ? episode.image : '',
            width: 60,
            height: 60,
            errorWidget: Container(
              color: theme.scaffoldBackgroundColor,
              child: const Icon(Icons.mic, color: Colors.red),
            ),
          ),
        ),
        title: Text(
          episode.title,
          style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.bold),
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
              style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6), fontSize: 12),
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
                  const Icon(Icons.download_done, color: Colors.green, size: 14),
                ],
                if (episode.lastPosition > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${(episode.lastPosition / 60).floor()}m left',
                    style: TextStyle(
                      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                      fontSize: 11,
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
                   color: theme.colorScheme.primary,
                   minHeight: 2,
                 ),
               ),
             ],
          ],
        ),
        trailing: isDownloading
            ? InkWell(
                onTap: () => engine.cancelDownload(episode.id),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: downloadProgress > 0 ? downloadProgress : null,
                        strokeWidth: 2,
                        color: Colors.red,
                      ),
                      const Icon(Icons.close, size: 12, color: Colors.red),
                    ],
                  ),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _BookmarkButton(episode: episode, engine: engine, theme: theme),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(
                      isDownloaded ? Icons.delete_outline : Icons.download_for_offline,
                      color: isDownloaded ? theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5) : Colors.red,
                    ),
                    onPressed: () {
                      if (isDownloaded) {
                        engine.deleteDownloadedEpisode(episode);
                      } else {
                        engine.downloadEpisode(episode);
                      }
                    },
                  ),
                ],
              ),
        onTap: () {
          engine.playEpisode(episode);
          if (context.mounted) {
            Navigator.of(context).push(NavigationHelper.slideUpRoute(NowPlayingScreen(engine: engine)));
          }
        },
      ),
    );
  }
}

class _BookmarkButton extends StatelessWidget {
  final Episode episode;
  final RadioEngine engine;
  final ThemeData theme;

  const _BookmarkButton({
    required this.episode,
    required this.engine,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: engine.isBookmarked(episode.id),
      builder: (context, snap) {
        final isBookmarked = snap.data == true;
        return IconButton(
          icon: Icon(
            isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            color: isBookmarked ? Colors.amber : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
          ),
          onPressed: () => engine.toggleBookmark(episode),
        );
      },
    );
  }
}
