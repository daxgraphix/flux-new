import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../flux_engine/radio_engine.dart';
import '../flux_storage/radio_storage.dart';

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<RadioEngine>(
        builder: (context, engine, child) {
          if (engine.currentStation == null) {
            return const Center(
              child: Text(
                'No station playing',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            );
          }

          return Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.red.withValues(alpha: 0.8),
                      Colors.black,
                    ],
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (engine.currentStation!.favicon.isNotEmpty)
                      CircleAvatar(
                        backgroundImage: NetworkImage(engine.currentStation!.favicon),
                        radius: 80,
                      )
                    else
                      const CircleAvatar(
                        backgroundColor: Colors.red,
                        radius: 80,
                        child: Icon(Icons.radio, color: Colors.white, size: 60),
                      ),
                    const SizedBox(height: 30),
                    Text(
                      engine.currentStation!.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${engine.currentStation!.country} • ${engine.currentStation!.genre} • ${engine.currentStation!.bitrate}kbps',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 18,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 50),
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              iconSize: 48,
                              icon: const Icon(Icons.skip_previous, color: Colors.white),
                              onPressed: () {
                                final stations = engine.stations;
                                if (stations.isNotEmpty && engine.currentStation != null) {
                                  final currentIndex = stations.indexOf(engine.currentStation!);
                                  final prevIndex = currentIndex > 0 ? currentIndex - 1 : stations.length - 1;
                                  engine.playStation(stations[prevIndex]);
                                }
                              },
                            ),
                            const SizedBox(width: 30),
                            FloatingActionButton(
                              backgroundColor: Colors.red,
                              onPressed: engine.isPlaying ? engine.pause : engine.resume,
                              child: Icon(
                                engine.isPlaying ? Icons.pause : Icons.play_arrow,
                                size: 36,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 30),
                            IconButton(
                              iconSize: 48,
                              icon: const Icon(Icons.skip_next, color: Colors.white),
                              onPressed: () {
                                final stations = engine.stations;
                                if (stations.isNotEmpty && engine.currentStation != null) {
                                  final currentIndex = stations.indexOf(engine.currentStation!);
                                  final nextIndex = currentIndex < stations.length - 1 ? currentIndex + 1 : 0;
                                  engine.playStation(stations[nextIndex]);
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.stop, color: Colors.white),
                              onPressed: engine.stop,
                            ),
                            const SizedBox(width: 20),
                            IconButton(
                              icon: Icon(engine.isRecording ? Icons.stop : Icons.mic, color: Colors.red),
                              onPressed: engine.isRecording ? engine.stopRecording : engine.startRecording,
                            ),
                            const SizedBox(width: 20),
                            IconButton(
                              icon: const Icon(Icons.equalizer, color: Colors.red),
                              onPressed: () => _showEqualizerDialog(context, engine),
                            ),
                            const SizedBox(width: 20),
                            IconButton(
                              icon: const Icon(Icons.favorite_border, color: Colors.red),
                              onPressed: () async {
                                if (engine.currentStation != null) {
                                  final storage = RadioStorage();
                                  await storage.addFavorite(engine.currentStation!);
                                  // ignore: use_build_context_synchronously
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Added to favorites')),
                                    );
                                  }
                                }
                              },
                            ),
                            const SizedBox(width: 20),
                            IconButton(
                              icon: const Icon(Icons.share, color: Colors.white),
                              onPressed: () {
                                // Share current station
                                if (engine.currentStation != null) {
                                  // Implement share
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 50),
                    if (engine.isLoading)
                      const CircularProgressIndicator(
                        color: Colors.red,
                      ),
                  ],
                ),
              ),
              Positioned(
                top: 40,
                left: 20,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEqualizerDialog(BuildContext context, RadioEngine engine) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text(
          'Equalizer',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (index) {
            return Row(
              children: [
                Text(
                  '${index + 1}',
                  style: const TextStyle(color: Colors.white),
                ),
                Expanded(
                  child: Slider(
                    value: engine.equalizerBands[index],
                    min: -10,
                    max: 10,
                    onChanged: (value) => engine.updateEqualizerBand(index, value),
                    activeColor: Colors.red,
                  ),
                ),
              ],
            );
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}