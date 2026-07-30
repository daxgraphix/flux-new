import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../flux_engine/playback_controller.dart';
import 'flux_image.dart';

class EnhancedMiniPlayer extends StatefulWidget {
  final VoidCallback onExpandTap;

  const EnhancedMiniPlayer({
    super.key,
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
    final primaryColor = theme.primaryColor;
    final textColor = theme.colorScheme.onSurface;

    return Consumer<PlaybackController>(
      builder: (context, controller, _) {
        final station = controller.currentStation;
        final episode = controller.currentEpisode;

        if (station == null && episode == null) return const SizedBox.shrink();

        final imageUrl = station?.favicon ?? episode?.image ?? '';
        final title = controller.currentTitle;
        final subtitle = controller.currentSubtitle;
        final isPodcast = episode != null;

        return GestureDetector(
          onTap: widget.onExpandTap,
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          child: AnimatedScale(
            scale: _isPressed ? 0.98 : 1.0,
            duration: const Duration(milliseconds: 120),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.fromLTRB(16, 8, 16, _isPressed ? 10 : 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: primaryColor.withValues(alpha: 0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isPodcast && controller.duration.inSeconds > 0)
                      _MiniProgressBar(
                        controller: controller,
                        color: primaryColor,
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withValues(alpha: 0.2),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: FluxImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                placeholder: Container(
                                  color: theme.colorScheme.surfaceContainerHighest,
                                  child: Icon(
                                    station != null ? Icons.radio_rounded : Icons.podcasts_rounded,
                                    color: primaryColor,
                                    size: 24),
                                ),
                                errorWidget: Container(
                                  color: theme.colorScheme.surfaceContainerHighest,
                                  child: Icon(
                                    station != null ? Icons.radio_rounded : Icons.podcasts_rounded,
                                    color: primaryColor,
                                    size: 24),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
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
                                    letterSpacing: 0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    if (controller.isPlaying)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 6.0),
                                        child: _MiniWaveform(
                                          controller: _waveController,
                                          color: primaryColor,
                                        ),
                                      ),
                                    Expanded(
                                      child: Text(
                                        controller.errorMessage ?? subtitle,
                                        style: TextStyle(
                                            color: controller.errorMessage != null
                                                ? theme.colorScheme.error
                                                : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                                            fontSize: 11,
                                            fontWeight: controller.errorMessage != null
                                                ? FontWeight.bold
                                                : FontWeight.w500),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          _MiniControlButton(
                            icon: controller.isLoading
                                ? Icons.hourglass_top_rounded
                                : (controller.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded),
                            color: primaryColor,
                            onTap: () => controller.isPlaying ? controller.pause() : controller.resume(),
                          ),
                          const SizedBox(width: 4),
                          _MiniControlButton(
                            icon: Icons.stop_rounded,
                            color: textColor.withValues(alpha: 0.4),
                            onTap: () => controller.stop(),
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MiniProgressBar extends StatelessWidget {
  final PlaybackController controller;
  final Color color;

  const _MiniProgressBar({
    required this.controller,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final episode = controller.currentEpisode;
    if (episode == null || controller.duration.inSeconds <= 0) return const SizedBox.shrink();

    final progress = controller.duration.inSeconds > 0
        ? (controller.position.inSeconds / controller.duration.inSeconds).clamp(0.0, 1.0)
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
