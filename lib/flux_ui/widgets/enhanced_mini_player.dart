import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../flux_engine/radio_engine.dart';

const _kBlack = Color(0xFF0A0A0A);
const _kCard = Color(0xFF1C1C1C);
const _kRed = Color(0xFFE53935);
const _kGrey = Color(0xFF9E9E9E);

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
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RadioEngine>(
      builder: (context, engine, _) {
        final station = engine.currentStation;
        if (station == null) return const SizedBox.shrink();
        return GestureDetector(
          onTap: widget.onExpandTap,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 6, 12, 4),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _kRed.withValues(alpha: 0.35),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _kRed.withValues(alpha: 0.12),
                  blurRadius: 16,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Red top accent line
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: _kRed,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      // Artwork
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _kBlack,
                          border:
                              Border.all(color: _kRed.withValues(alpha: 0.5), width: 1.5),
                        ),
                        child: ClipOval(
                          child: station.favicon.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: station.favicon,
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const Icon(
                                      Icons.radio_rounded,
                                      color: _kRed,
                                      size: 22),
                                  errorWidget: (context, url, error) => const Icon(
                                      Icons.radio_rounded,
                                      color: _kRed,
                                      size: 22),
                                )
                              : const Icon(Icons.radio_rounded,
                                  color: _kRed, size: 22),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              station.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              [
                                station.country,
                                station.genre,
                              ]
                                  .where((s) => s.isNotEmpty)
                                  .join(' • '),
                              style: const TextStyle(
                                  color: _kGrey, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Animated waveform (when playing) OR static icon
                      if (engine.isPlaying)
                        RepaintBoundary(
                          child: _MiniWaveform(
                              controller: _waveController),
                        ),
                      const SizedBox(width: 8),
                      // Play / Pause button
                      GestureDetector(
                        onTap: () => engine.isPlaying
                            ? engine.pause()
                            : engine.resume(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _kRed,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _kRed.withValues(alpha: 0.35),
                                blurRadius: 10,
                              )
                            ],
                          ),
                          child: Icon(
                            engine.isLoading
                                ? Icons.hourglass_top_rounded
                                : (engine.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded),
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
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
}

class _MiniWaveform extends StatelessWidget {
  final AnimationController controller;
  const _MiniWaveform({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return SizedBox(
          width: 24,
          height: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(4, (i) {
              final phase = controller.value * 2 * math.pi;
              final h = 4.0 +
                  12.0 *
                      (0.5 +
                          0.5 *
                              math.sin(phase + i * math.pi / 3));
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Container(
                  width: 3,
                  height: h,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935)
                        .withValues(alpha: i % 2 == 0 ? 1.0 : 0.6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}