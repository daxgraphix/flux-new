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
  bool _isPressed = false;

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

    return Consumer<RadioEngine>(
      builder: (context, engine, _) {
        final station = engine.currentStation;
        final episode = engine.currentEpisode;

        if (station == null && episode == null) return const SizedBox.shrink();

        final imageUrl = station?.favicon ?? episode?.image ?? '';
        final title = engine.currentTitle;
        final subtitle = engine.currentSubtitle;
        final isPodcast = episode != null;

        return GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: widget.onExpandTap,
          child: AnimatedScale(
            scale: _isPressed ? 0.98 : 1.0,
            duration: const Duration(milliseconds: 120),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.fromLTRB(12, 6, 12, _isPressed ? 2 : 4),
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
                    blurRadius: _isPressed ? 12 : 16,
                    spreadRadius: 0,
                    offset: Offset(0, _isPressed ? 2 : 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Progress bar
                  if (isPodcast && episode.duration > 0)
                    _MiniProgressBar(
                      engine: engine,
                      color: primaryColor,
                    ),
                  // Top accent line
                  Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        // Artwork
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.surfaceContainerHighest,
                            border: Border.all(color: primaryColor.withValues(alpha: 0.5), width: 1.5),
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
                              Row(
                                children: [
                                  if (engine.isPlaying)
                                    _MiniWaveform(
                                      controller: _waveController,
                                      color: primaryColor,
                                    ),
                                  Expanded(
                                    child: Text(
                                      engine.errorMessage ?? subtitle,
                                      style: TextStyle(
                                          color: engine.errorMessage != null
                                              ? theme.colorScheme.error
                                              : theme.colorScheme.onSurfaceVariant,
                                          fontSize: 11,
                                          fontWeight: engine.errorMessage != null
                                              ? FontWeight.bold
                                              : FontWeight.normal),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
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
                        // Play / Pause button
                        _MiniControlButton(
                          icon: engine.isLoading
                              ? Icons.hourglass_top_rounded
                              : (engine.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded),
                          color: primaryColor,
                          onTap: () => engine.isPlaying ? engine.pause() : engine.resume(),
                        ),
                        const SizedBox(width: 6),
                        // Stop button
                        _MiniControlButton(
                          icon: Icons.stop_rounded,
                          color: textColor.withValues(alpha: 0.6),
                          onTap: () => engine.stop(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MiniProgressBar extends StatelessWidget {
  final RadioEngine engine;
  final Color color;

  const _MiniProgressBar({
    required this.engine,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final episode = engine.currentEpisode;
    if (episode == null || episode.duration <= 0) return const SizedBox.shrink();

    final progress = episode.duration > 0
        ? (episode.lastPosition / episode.duration).clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      onTap: () {
        // Could implement seek on mini player in the future
      },
      child: Container(
        height: 3,
        width: double.infinity,
        color: color.withValues(alpha: 0.15),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: progress,
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniControlButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MiniControlButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: color,
          size: 20,
        ),
      ),
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
          width: 20,
          height: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(3, (i) {
              final phase = controller.value * 2 * math.pi;
              final h = 3.0 + 8.0 * (0.5 + 0.5 * math.sin(phase + i * math.pi / 2.5));
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0.8),
                child: Container(
                  width: 2.5,
                  height: h,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: i % 2 == 0 ? 1.0 : 0.5),
                    borderRadius: BorderRadius.circular(1.5),
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
