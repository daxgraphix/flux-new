import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../flux_engine/radio_engine.dart';
import '../../flux_hardware/radio_service.dart';

class NowPlayingScreen extends StatelessWidget {
  final RadioEngine engine;
  final bool isDark;

  const NowPlayingScreen({super.key, required this.engine, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final station = engine.currentStation!;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: Colors.transparent,
              expandedHeight: 300,
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    station.favicon.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: station.favicon,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => _buildGradientBackground(),
                            errorWidget: (context, url, error) => _buildGradientBackground(),
                          )
                        : _buildGradientBackground(),
                    Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent]))),
                  ],
                ),
              ),
              floating: true,
              pinned: false,
              leading: IconButton(icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black), onPressed: () => Navigator.pop(context)),
              actions: [
                IconButton(icon: Icon(Icons.more_vert, color: isDark ? Colors.white : Colors.black), onPressed: null),
              ],
            ),
            SliverToBoxAdapter(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF121212) : Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      station.name,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${station.country} • ${station.genre}',
                      style: TextStyle(color: isDark ? Colors.grey : Colors.grey[600], fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    _buildProgressBar(),
                    const SizedBox(height: 20),
                    _buildControlButtons(),
                    const SizedBox(height: 24),
                    _buildVolumeControl(),
                    const SizedBox(height: 24),
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.withValues(alpha: 0.8), Colors.orange.withValues(alpha: 0.6), Colors.purple.withValues(alpha: 0.4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Consumer<RadioEngine>(
      builder: (context, engine, _) {
        final position = engine.position;
        final duration = engine.duration ?? Duration.zero;
        return Column(
          children: [
            Slider(
              value: position.inSeconds.clamp(0, duration.inSeconds).toDouble(),
              min: 0,
              max: duration.inSeconds.toDouble(),
              onChanged: duration.inSeconds > 0 ? (value) => engine.seek(Duration(seconds: value.toInt())) : null,
              activeColor: Colors.red,
              inactiveColor: Colors.white24,
              thumbColor: Colors.red,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDuration(position), style: const TextStyle(color: Colors.white, fontSize: 12)),
                Text(_formatDuration(duration), style: const TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildControlButtons() {
    return Consumer<RadioEngine>(
      builder: (context, engine, _) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(icon: const Icon(Icons.skip_previous, color: Colors.red, size: 32), onPressed: () {}),
          const SizedBox(width: 16),
          IconButton(
            icon: Icon(engine.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.red, size: 56),
            onPressed: () => engine.isPlaying ? engine.pause() : engine.resume(),
          ),
          const SizedBox(width: 16),
          IconButton(icon: const Icon(Icons.skip_next, color: Colors.red, size: 32), onPressed: () {}),
          const SizedBox(width: 16),
          FutureBuilder<List<RadioStation>>(
            future: engine.favorites,
            builder: (context, snapshot) {
              final station = engine.currentStation;
              if (station == null) return const SizedBox.shrink();
              return FutureBuilder<bool>(
                future: engine.isFavorite(station.name),
                builder: (context, favSnapshot) => IconButton(
                  icon: Icon(favSnapshot.data == true ? Icons.favorite : Icons.favorite_border, color: Colors.red, size: 32),
                  onPressed: () async {
                    if (favSnapshot.data == true) {
                      await engine.removeFromFavorites(station.name);
                    } else {
                      await engine.addToFavorites(station);
                    }
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVolumeControl() {
    return Consumer<RadioEngine>(
      builder: (context, engine, _) => Column(
        children: [
          Row(
            children: [
              Icon(Icons.volume_down, color: Colors.red.withValues(alpha: 0.6), size: 20),
              Expanded(
                child: Slider(
                  value: engine.volume,
                  onChanged: engine.setVolume,
                  min: 0,
                  max: 1,
                  divisions: 20,
                  activeColor: Colors.red,
                  inactiveColor: Colors.white24,
                ),
              ),
              Icon(Icons.volume_up, color: Colors.red, size: 20),
            ],
          ),
          Text('${(engine.volume * 100).round()}%', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Consumer<RadioEngine>(
      builder: (context, engine, _) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton.icon(
            onPressed: () => _showEqualizer(context, engine),
            icon: const Icon(Icons.equalizer, color: Colors.red),
            label: Text('Equalizer', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
          ),
          const SizedBox(width: 16),
          TextButton.icon(
            onPressed: () => _showRecordingOptions(context, engine),
            icon: Icon(engine.isRecording ? Icons.stop_circle : Icons.fiber_manual_record, color: Colors.red),
            label: Text(engine.isRecording ? 'Stop' : 'Record', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _showEqualizer(BuildContext context, RadioEngine engine) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(color: isDark ? const Color(0xFF1A1A2E) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Equalizer', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          ...List.generate(5, (index) {
            return Consumer<RadioEngine>(
              builder: (context, engine, _) => Row(
                children: [
                  Text('${_getBandLabel(index)}Hz', style: TextStyle(color: isDark ? Colors.grey : Colors.grey[600], fontSize: 12)),
                  Expanded(
                    child: Slider(
                      value: engine.equalizerBands[index],
                      min: -10,
                      max: 10,
                      onChanged: (value) => engine.updateEqualizerBand(index, value),
                      activeColor: Colors.red,
                      inactiveColor: Colors.white24,
                    ),
                  ),
                  Text('${engine.equalizerBands[index].toStringAsFixed(1)}dB', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 12)),
                ],
              ),
            );
          }),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text('Close', style: TextStyle(color: isDark ? Colors.white : Colors.black))),
            ],
          ),
        ]),
      ),
    );
  }

  void _showRecordingOptions(BuildContext context, RadioEngine engine) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(color: isDark ? const Color(0xFF1A1A2E) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Recording', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (engine.isRecording)
            const Text('Recording in progress...', style: TextStyle(color: Colors.grey)),
          if (!engine.isRecording && engine.savedRecordings.isNotEmpty)
            const Text('Recordings available. Go to Settings > Library to play them.', style: TextStyle(color: Colors.grey)),
          if (!engine.isRecording && engine.savedRecordings.isEmpty)
            const Text('Start recording the current station.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text('Close', style: TextStyle(color: isDark ? Colors.white : Colors.black))),
              if (!engine.isRecording)
                TextButton(onPressed: () { engine.startRecording(); Navigator.pop(context); }, child: const Text('Start Recording', style: TextStyle(color: Colors.red))),
              if (engine.isRecording)
                TextButton(onPressed: () { engine.stopRecording(); Navigator.pop(context); }, child: const Text('Stop Recording', style: TextStyle(color: Colors.red))),
            ],
          ),
        ]),
      ),
    );
  }

  String _getBandLabel(int index) {
    final labels = ['60', '170', '310', '4k', '16k'];
    return labels[index];
  }
}