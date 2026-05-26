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

class _EnhancedMiniPlayerState extends State<EnhancedMiniPlayer> {
  @override
  Widget build(BuildContext context) {
    final station = widget.engine.currentStation!;

    return Consumer<RadioEngine>(
      builder: (context, _, _) {
        return Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.red.withValues(alpha: 0.1),
                Colors.red.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withValues(alpha: 0.1),
                blurRadius: 8,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top bar with station info
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: GestureDetector(
                    onTap: widget.onExpandTap,
                    child: Row(
                      children: [
                        // Station icon
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
                        const SizedBox(width: 12),
                        // Station info
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
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Timer badge
                        if (widget.engine.isSleepTimerActive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _formatDuration(widget.engine.sleepRemainingTime),
                              style: const TextStyle(
                                color: Colors.blue,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Progress bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _ProgressBar(
                    position: widget.engine.position,
                    duration: widget.engine.duration,
                    isDark: widget.isDark,
                  ),
                ),
                // Control buttons and volume
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      // Play/Pause
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
                      // Stop
                      IconButton(
                        icon: const Icon(Icons.stop_circle,
                            color: Colors.red, size: 24),
                        onPressed: () => widget.engine.stop(),
                      ),
                      const Spacer(),
                      // Recording button
                      IconButton(
                        icon: Icon(
                          widget.engine.isRecording
                              ? Icons.stop_circle
                              : Icons.fiber_manual_record,
                          color: widget.engine.isRecording ? Colors.red : Colors.grey,
                          size: 22,
                        ),
                        onPressed: () async {
                          if (widget.engine.isRecording) {
                            await widget.engine.stopRecording();
                          } else {
                            await widget.engine.startRecording();
                          }
                        },
                      ),
                      // Recording duration
                      if (widget.engine.isRecording)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            _formatDuration(widget.engine.recordingDuration),
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      // Volume control
                      IconButton(
                        icon: Icon(
                          _getVolumeIcon(widget.engine.volume),
                          color: Colors.red,
                          size: 22,
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
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  IconData _getVolumeIcon(double volume) {
    if (volume == 0) return Icons.volume_mute;
    if (volume < 0.5) return Icons.volume_down;
    return Icons.volume_up;
  }

  void _showVolumeDialog(BuildContext context, RadioEngine engine, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        title: const Text('Volume Control'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Slider(
                value: engine.volume,
                onChanged: (value) {
                  setState(() {});
                  engine.setVolume(value);
                },
                min: 0,
                max: 1,
                divisions: 20,
                label: '${(engine.volume * 100).toStringAsFixed(0)}%',
                activeColor: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                '${(engine.volume * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
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

class _ProgressBar extends StatelessWidget {
  final Duration position;
  final Duration? duration;
  final bool isDark;

  const _ProgressBar({
    required this.position,
    required this.duration,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final totalSeconds = duration?.inSeconds ?? 0;
    final currentSeconds = position.inSeconds;
    final progress =
        totalSeconds > 0 ? currentSeconds / totalSeconds : 0.0;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 4,
            backgroundColor: Colors.red.withValues(alpha: 0.1),
            valueColor:
                const AlwaysStoppedAnimation<Color>(Colors.red),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatDuration(position),
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            Text(
              _formatDuration(duration ?? Duration.zero),
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
