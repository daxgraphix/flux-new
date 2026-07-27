import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../flux_engine/radio_engine.dart';
import 'models/podcast.dart';
import 'widgets/flux_image.dart';
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
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: const Color(0xFF0A0A0A),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  FluxImage(
                    imageUrl: widget.podcast.image,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Color(0xFF0A0A0A),
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
                    style: const TextStyle(
                      color: Colors.white,
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
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Episodes',
                    style: TextStyle(
                      color: Colors.white,
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
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: Colors.red)),
                );
              }
              
              if (engine.episodes.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(
                    child: Text('No episodes found', style: TextStyle(color: Colors.white70)),
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
    final engine = Provider.of<RadioEngine>(context);
    final dateStr = DateFormat('MMM d, yyyy').format(episode.pubDate);
    final durationStr = '${(episode.duration / 60).floor()} min';
    
    final isDownloading = engine.isDownloading(episode.id);
    final downloadProgress = engine.getDownloadProgress(episode.id);
    final isDownloaded = episode.isDownloaded;

    return Card(
      color: const Color(0xFF1C1C1C),
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
              color: Colors.grey[900],
              child: const Icon(Icons.mic, color: Colors.red),
            ),
          ),
        ),
        title: Text(
          episode.title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
              style: const TextStyle(color: Colors.white54, fontSize: 12),
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
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  value: downloadProgress > 0 ? downloadProgress : null,
                  strokeWidth: 2,
                  color: Colors.red,
                ),
              )
            : IconButton(
                icon: Icon(
                  isDownloaded ? Icons.delete_outline : Icons.download_for_offline,
                  color: isDownloaded ? Colors.white54 : Colors.red,
                ),
                onPressed: () {
                  if (isDownloaded) {
                    engine.deleteDownloadedEpisode(episode);
                  } else {
                    engine.downloadEpisode(episode);
                  }
                },
              ),
        onTap: () => engine.playEpisode(episode),
      ),
    );
  }
}
