import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../flux_engine/radio_engine.dart';
import '../helpers/navigation_helper.dart';
import 'models/podcast.dart';
import 'widgets/flux_image.dart';
import 'widgets/empty_state_widget.dart';
import 'widgets/shimmer_list_widget.dart';
import 'now_playing_screen.dart';
import 'package:intl/intl.dart';

class PodcastDetailsScreen extends StatefulWidget {
  final Podcast podcast;

  const PodcastDetailsScreen({super.key, required this.podcast});

  @override
  State<PodcastDetailsScreen> createState() => _PodcastDetailsScreenState();
}

class _PodcastDetailsScreenState extends State<PodcastDetailsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RadioEngine>(context, listen: false).loadEpisodes(widget.podcast.rss);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
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
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
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
                  child: EmptyStateWidget(
                    icon: Icons.mic_off,
                    title: 'No episodes found',
                    message: 'We couldn\'t find any episodes for this podcast.',
                    buttonLabel: 'Go Back',
                    onButtonPressed: () => Navigator.pop(context),
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
                  style: const TextStyle(color: Colors.red, fontSize: 11),
                ),
                if (isDownloaded) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.download_done, color: Colors.green, size: 14),
                ],
              ],
            ),
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
            : IconButton(
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
