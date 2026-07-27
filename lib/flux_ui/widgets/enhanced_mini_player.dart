import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../flux_engine/radio_engine.dart';

import 'flux_image.dart';

class EnhancedMiniPlayer extends StatefulWidget {
  final RadioEngine engine;
  final VoidCallback onExpandTap;

  const EnhancedMiniPlayer({
    super.key,
    required this.engine,
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
    final theme = Theme.of(context);
    final cardColor = theme.colorScheme.surface;
    final primaryColor = theme.primaryColor;
    final textColor = theme.colorScheme.onSurface;
    final secondaryTextColor = theme.colorScheme.onSurfaceVariant;

    return Consumer<RadioEngine>(
      builder: (context, engine, _) {
        final station = engine.currentStation;
        final episode = engine.currentEpisode;
        
        if (station == null && episode == null) return const SizedBox.shrink();

        final imageUrl = station?.favicon ?? episode?.image ?? '';
        final title = engine.currentTitle;
        final subtitle = engine.currentSubtitle;

        return GestureDetector(
          onTap: widget.onExpandTap,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 6, 12, 4),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: primaryColor.withValues(alpha: 0.35),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.12),
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
                    color: primaryColor,
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
                          color: theme.colorScheme.surfaceContainerHighest,
                          border:
                              Border.all(color: primaryColor.withValues(alpha: 0.5), width: 1.5),
                        ),
                        child: ClipOval(
                          child: FluxImage(
                            imageUrl: imageUrl,
                            width: 44,
                            height: 44,
                            placeholder: Icon(
                                station != null ? Icons.radio_rounded : Icons.podcasts_rounded,
                                color: primaryColor,
                                size: 22),
                            errorWidget: Icon(
                                station != null ? Icons.radio_rounded : Icons.podcasts_rounded,
                                color: primaryColor,
                                size: 22),
                          ),
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
                              title,
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              engine.errorMessage ?? subtitle,
                              style: TextStyle(
                                  color: engine.errorMessage != null
                                      ? theme.colorScheme.error
                                      : secondaryTextColor,
                                  fontSize: 11,
                                  fontWeight: engine.errorMessage != null
                                      ? FontWeight.bold
                                      : FontWeight.normal),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (engine.errorMessage != null) ...[
                        GestureDetector(
                          onTap: () => engine.clearError(),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.error.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              color: theme.colorScheme.error,
                              size: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      // Animated waveform (when playing) OR static icon
                      if (engine.isPlaying)
                        RepaintBoundary(
                          child: _MiniWaveform(
                              controller: _waveController,
                              color: primaryColor),
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
                            color: primaryColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withValues(alpha: 0.35),
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
  final Color color;
  const _MiniWaveform({required this.controller, required this.color});

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
                    color: color.withValues(alpha: i % 2 == 0 ? 1.0 : 0.6),
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
