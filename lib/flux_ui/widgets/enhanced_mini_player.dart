import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../flux_engine/radio_engine.dart';

class EnhancedMiniPlayer extends StatefulWidget {
  final RadioEngine engine;
  final bool isDark;
  final VoidCallback onExpandTap;

  const EnhancedMiniPlayer({super.key, required this.engine, required this.isDark, required this.onExpandTap});

  @override
  State<EnhancedMiniPlayer> createState() => _EnhancedMiniPlayerState();
}

class _EnhancedMiniPlayerState extends State<EnhancedMiniPlayer> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(duration: const Duration(milliseconds: 1500), vsync: this)..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final station = widget.engine.currentStation!;

    return Consumer<RadioEngine>(
      builder: (context, engine, _) {
        return AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red.withValues(alpha: 0.25), Colors.orange.withValues(alpha: 0.15)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                boxShadow: [BoxShadow(color: Colors.red.withValues(alpha: 0.15), blurRadius: 12, spreadRadius: 1)],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: widget.onExpandTap,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: Colors.red.withValues(alpha: 0.2),
                                child: station.favicon.isNotEmpty
                                    ? ClipOval(child: Image.network(station.favicon, fit: BoxFit.cover, width: 40, height: 40, errorBuilder: (context, error, stackTrace) => const Icon(Icons.radio, color: Colors.red, size: 20)))
                                    : const Icon(Icons.radio, color: Colors.red, size: 20),
                              ),
                              if (engine.isPlaying)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                    child: const Icon(Icons.audiotrack, color: Colors.white, size: 12),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(station.name, style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text('${station.country} • ${station.genre}', style: TextStyle(color: widget.isDark ? Colors.grey : Colors.grey[600], fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          Consumer<RadioEngine>(
                            builder: (context, engine, _) => Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (engine.savedRecordings.isNotEmpty)
                                  IconButton(icon: const Icon(Icons.save, color: Colors.grey, size: 20), onPressed: () {}),
                                Icon(engine.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.red, size: 28),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}