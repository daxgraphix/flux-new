import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../flux_engine/radio_engine.dart';

class EnhancedMiniPlayer extends StatefulWidget {
  final RadioEngine engine;
  final bool isDark;
  final VoidCallback onExpandTap;

  const EnhancedMiniPlayer({
    super.key,
    required this.engine,
    required this.isDark,
    required this.onExpandTap,
  });

  @override
  State<EnhancedMiniPlayer> createState() => _EnhancedMiniPlayerState();
}

class _EnhancedMiniPlayerState extends State<EnhancedMiniPlayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
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
      builder: (context, _, _) {
        return AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.red.withValues(alpha: 0.15),
                    Colors.red.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.15),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.engine.isPlaying)
                      Container(
                        height: 3,
                        color: Colors.red.withValues(alpha: 0.5),
                      ),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: GestureDetector(
                        onTap: widget.onExpandTap,
                        child: Row(
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.red.withValues(alpha: 0.2),
                                  child: station.favicon.isNotEmpty
                                      ? ClipOval(
                                          child: Image.network(
                                            station.favicon,
                                            fit: BoxFit.cover,
                                            width: 40,
                                            height: 40,
                                            errorBuilder: (context, error, stackTrace) =>
                                                const Icon(Icons.radio,
                                                    color: Colors.red, size: 16),
                                          ),
                                        )
                                      : const Icon(Icons.radio,
                                          color: Colors.red, size: 16),
                                ),
                                if (widget.engine.isPlaying)
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Icon(Icons.volume_up,
                                        color: Colors.red, size: 10),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    station.name,
                                    style: TextStyle(
                                      color: widget.isDark
                                          ? Colors.white
                                          : Colors.black87,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${station.country} • ${station.genre}',
                                    style: TextStyle(
                                      color: widget.isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                      fontSize: 11,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              widget.engine.isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              color: Colors.red,
                              size: 24,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (widget.engine.isPlaying)
                      Builder(
                        builder: (context) {
                          final position = widget.engine.position;
                          final duration = widget.engine.duration ?? Duration.zero;
                          final progress = duration.inSeconds > 0
                              ? (position.inSeconds / duration.inSeconds).clamp(0.0, 1.0)
                              : 0.0;
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 2,
                              backgroundColor: Colors.red.withValues(alpha: 0.1),
                              valueColor:
                                  const AlwaysStoppedAnimation<Color>(Colors.red),
                            ),
                          );
                        },
                      ),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              widget.engine.isRecording
                                  ? Icons.stop_circle
                                  : Icons.fiber_manual_record,
                              color:
                                  widget.engine.isRecording ? Colors.red : Colors.grey,
                              size: 20,
                            ),
                            onPressed: () async {
                              if (widget.engine.isRecording) {
                                await widget.engine.stopRecording();
                              } else {
                                await widget.engine.startRecording();
                              }
                            },
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(
                              widget.engine.isPlaying
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_filled,
                              color: Colors.red,
                              size: 28,
                            ),
                            onPressed: () {
                              if (widget.engine.isPlaying) {
                                widget.engine.pause();
                              } else {
                                widget.engine.resume();
                              }
                            },
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.stop_circle,
                                color: Colors.red, size: 24),
                            onPressed: () => widget.engine.stop(),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(
                              _getVolumeIcon(widget.engine.volume),
                              color: Colors.red,
                              size: 20,
                            ),
                            onPressed: () =>
                                _showVolumeDialog(context, widget.engine, widget.isDark),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  IconData _getVolumeIcon(double volume) {
    if (volume == 0) return Icons.volume_mute;
    if (volume < 0.5) return Icons.volume_down;
    return Icons.volume_up;
  }

  void _showVolumeDialog(
      BuildContext context, RadioEngine engine, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        title: const Text('Volume Control'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.volume_down, color: Colors.red),
                Expanded(
                  child: Slider(
                    value: engine.volume,
                    onChanged: engine.setVolume,
                    min: 0,
                    max: 1,
                    divisions: 20,
                    label: '${(engine.volume * 100).toStringAsFixed(0)}%',
                    activeColor: Colors.red,
                    inactiveColor: Colors.white24,
                  ),
                ),
                const Icon(Icons.volume_up, color: Colors.red),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${(engine.volume * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}