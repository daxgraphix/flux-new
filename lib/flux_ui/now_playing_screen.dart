import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter_shaders/flutter_shaders.dart';
import '../../flux_engine/radio_engine.dart';
import '../../flux_hardware/radio_service.dart';
import '../flux_ui/models/podcast.dart';
import 'widgets/flux_image.dart';

extension RadioStationX on RadioStation {
  double get frequency {
    int hash = name.hashCode.abs();
    return 87.5 + (hash % 205) / 10.0;
  }
}

class NowPlayingScreen extends StatefulWidget {
  final RadioEngine engine;

  const NowPlayingScreen({
    super.key,
    required this.engine,
  });

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late AnimationController _rotationController;
  late Animation<double> _pulseAnim;

  bool _isFullscreen = false;
  bool _showControls = true;
  math.Point<double>? _dragStart;
  double _dragStartValue = 0;
  String _dragType = ''; 
  String _overlayText = '';
  bool _showOverlayText = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    );
    _pulseAnim = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.engine.isPlaying) {
      _rotationController.repeat();
    }
  }

  @override
  void didUpdateWidget(NowPlayingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.engine.isPlaying && !_rotationController.isAnimating) {
      _rotationController.repeat();
    } else if (!widget.engine.isPlaying && _rotationController.isAnimating) {
      _rotationController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _rotationController.dispose();
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
      if (_isFullscreen) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    });
  }

  void _onVerticalDragStart(DragStartDetails details, BoxConstraints constraints) {
    _dragStart = math.Point(details.globalPosition.dx, details.globalPosition.dy);
    if (details.globalPosition.dx < constraints.maxWidth / 2) {
      _dragType = 'brightness';
      ScreenBrightness().current.then((v) => _dragStartValue = v);
    } else {
      _dragType = 'volume';
      _dragStartValue = widget.engine.volume;
    }
  }

  void _onVerticalDragUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    if (_dragStart == null) return;
    final delta = (_dragStart!.y - details.globalPosition.dy) / constraints.maxHeight;
    final newValue = (_dragStartValue + delta).clamp(0.0, 1.0);

    if (_dragType == 'volume') {
      widget.engine.setVolume(newValue);
      setState(() {
        _overlayText = 'Volume: ${(newValue * 100).round()}%';
        _showOverlayText = true;
      });
    } else {
      ScreenBrightness().setScreenBrightness(newValue);
      setState(() {
        _overlayText = 'Brightness: ${(newValue * 100).round()}%';
        _showOverlayText = true;
      });
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() => _showOverlayText = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final secondaryTextColor = theme.colorScheme.onSurfaceVariant;
    final primaryColor = theme.colorScheme.primary;
    final cardColor = theme.colorScheme.surfaceContainerHighest;
    final backgroundColor = theme.colorScheme.surface;

    return Consumer<RadioEngine>(
      builder: (context, engine, _) {
        final station = engine.currentStation;
        final episode = engine.currentEpisode;

        if (station == null && episode == null) {
          return Scaffold(
            backgroundColor: backgroundColor,
            body: Center(child: Text('Nothing playing', style: TextStyle(color: textColor))),
          );
        }

        return Scaffold(
          backgroundColor: backgroundColor,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 600;
              final contentWidth = isWide ? 600.0 : constraints.maxWidth;

              return GestureDetector(
                onTap: () => setState(() => _showControls = !_showControls),
                onDoubleTap: _toggleFullscreen,
                onVerticalDragStart: (d) => _onVerticalDragStart(d, constraints),
                onVerticalDragUpdate: (d) => _onVerticalDragUpdate(d, constraints),
                onVerticalDragEnd: _onVerticalDragEnd,
                onHorizontalDragEnd: (details) {
                  if (details.primaryVelocity != null && details.primaryVelocity! > 500) {
                    Navigator.maybePop(context);
                  }
                },
                child: Stack(
                  children: [
                    _buildBackground(station, episode, backgroundColor),
                    Center(
                      child: SizedBox(
                        width: contentWidth,
                        child: SafeArea(
                          child: Column(
                            children: [
                              AnimatedOpacity(
                                opacity: _showControls ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 300),
                                child: _buildTopBar(context, textColor, primaryColor),
                              ),
                              Expanded(
                                child: Center(
                                  child: _buildArtwork(station, episode, engine, primaryColor, backgroundColor),
                                ),
                              ),
                              AnimatedOpacity(
                                opacity: _showControls ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 300),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24),
                                  child: Column(
                                    children: [
                                      _buildStationInfo(engine, textColor, secondaryTextColor, primaryColor),
                                      const SizedBox(height: 16),
                                      if (engine.errorMessage != null)
                                        _buildErrorMessage(engine, theme),
                                      if (station != null && engine.errorMessage == null)
                                        _buildSpectrumVisualizer(station, engine),
                                      const SizedBox(height: 20),
                                      _buildProgressBar(engine, primaryColor, secondaryTextColor),
                                      const SizedBox(height: 24),
                                      _buildMainControls(engine, primaryColor, textColor),
                                      const SizedBox(height: 24),
                                      _buildSecondaryControls(engine, cardColor, primaryColor, textColor),
                                      const SizedBox(height: 32),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_showOverlayText)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: primaryColor.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            _overlayText,
                            style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildBackground(RadioStation? station, Episode? episode, Color backgroundColor) {
    final imageUrl = station?.favicon ?? episode?.image ?? '';
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(color: backgroundColor),
      child: Opacity(
        opacity: 0.1,
        child: FluxImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          errorWidget: Container(color: backgroundColor),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, Color textColor, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.keyboard_arrow_down_rounded, color: textColor, size: 36),
            onPressed: () {
              Navigator.maybePop(context);
            },
          ),
          Column(
            children: [
              Text(
                'FLUX RADIO',
                style: TextStyle(color: primaryColor.withValues(alpha: 0.8), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 4),
              ),
              Text(
                'NOW PLAYING',
                style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1.5),
              ),
            ],
          ),
          IconButton(
            icon: Icon(_isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded, color: textColor, size: 28),
            onPressed: _toggleFullscreen,
          ),
        ],
      ),
    );
  }

  Widget _buildArtwork(RadioStation? station, Episode? episode, RadioEngine engine, Color primaryColor, Color backgroundColor) {
    final size = _isFullscreen ? 300.0 : 260.0;
    final theme = Theme.of(context);
    final imageUrl = station?.favicon ?? episode?.image ?? '';

    return Center(
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseAnim, _rotationController]),
        builder: (context, child) {
          return Transform.rotate(
            angle: _rotationController.value * 2 * math.pi,
            child: Container(
              width: size * _pulseAnim.value,
              height: size * _pulseAnim.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [theme.colorScheme.surfaceBright, backgroundColor],
                  stops: const [0.85, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: engine.isPlaying ? 0.25 : 0.05),
                    blurRadius: 60,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: primaryColor.withValues(alpha: 0.3), width: 1.5),
                      ),
                      child: ClipOval(
                        child: FluxImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: _buildFallbackArtwork(primaryColor, theme, station != null),
                          errorWidget: _buildFallbackArtwork(primaryColor, theme, station != null),
                        ),
                      ),
                    ),
                    // Vinyl reflection
                    Center(
                      child: Container(
                        width: size * 0.2,
                        height: size * 0.2,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                          border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.1), width: 1),
                        ),
                        child: Center(
                          child: Icon(
                            station != null ? Icons.radio_rounded : Icons.podcasts_rounded,
                            color: primaryColor,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFallbackArtwork(Color primaryColor, ThemeData theme, bool isStation) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        isStation ? Icons.radio_rounded : Icons.podcasts_rounded,
        color: primaryColor,
        size: 80,
      ),
    );
  }

  Widget _buildStationInfo(RadioEngine engine, Color textColor, Color secondaryTextColor, Color primaryColor) {
    final title = engine.currentTitle;
    final subtitle = engine.currentSubtitle;

    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: textColor, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 0.5),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle.toUpperCase(),
          style: TextStyle(color: secondaryTextColor, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.2),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        _buildLiveBadge(engine, primaryColor, secondaryTextColor),
      ],
    );
  }

  Widget _buildLiveBadge(RadioEngine engine, Color primaryColor, Color secondaryTextColor) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final isPlaying = engine.isPlaying;
        final isLoading = engine.isLoading;
        final hasError = engine.errorMessage != null;
        
        final color = hasError 
            ? Theme.of(context).colorScheme.error 
            : (isLoading ? Colors.orange : (isPlaying ? primaryColor : secondaryTextColor));
            
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(strokeWidth: 2, color: color),
                )
              else
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    boxShadow: isPlaying ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6)] : null,
                  ),
                ),
              const SizedBox(width: 8),
              Text(
                hasError ? 'ERROR' : (isLoading ? 'LOADING...' : (isPlaying ? (engine.currentEpisode != null ? 'PODCAST' : 'LIVE STREAM') : 'PAUSED')),
                style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSpectrumVisualizer(RadioStation station, RadioEngine engine) {
    return ShaderBuilder(
      (context, shader, child) {
        return CustomPaint(
          size: const Size(double.infinity, 80),
          painter: SpectrumPainter(
            shader: shader,
            currentFreq: station.frequency,
            isPlaying: engine.isPlaying,
            time: _waveController.value,
          ),
        );
      },
      assetKey: 'assets/shaders/spectrum.frag',
    );
  }

  Widget _buildProgressBar(RadioEngine engine, Color primaryColor, Color secondaryTextColor) {
    final position = engine.position;
    final duration = engine.duration;
    final isLive = duration == Duration.zero;

    if (isLive) {
      return Container(
        height: 4,
        width: double.infinity,
        decoration: BoxDecoration(color: secondaryTextColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(2)),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: engine.isPlaying ? 1.0 : 0.0,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [primaryColor, primaryColor.withValues(alpha: 0.7)]),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            thumbColor: primaryColor,
            activeTrackColor: primaryColor,
            inactiveTrackColor: secondaryTextColor.withValues(alpha: 0.1),
            overlayColor: primaryColor.withValues(alpha: 0.2),
          ),
          child: Slider(
            value: position.inSeconds.clamp(0, duration.inSeconds).toDouble(),
            min: 0,
            max: duration.inSeconds.toDouble(),
            onChanged: (v) => engine.seek(Duration(seconds: v.toInt())),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmt(position), style: TextStyle(color: secondaryTextColor, fontSize: 12, fontWeight: FontWeight.w500)),
              Text(_fmt(duration), style: TextStyle(color: secondaryTextColor, fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMainControls(RadioEngine engine, Color primaryColor, Color textColor) {
    final isPodcast = engine.currentEpisode != null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isPodcast)
          _ControlBtn(
            icon: Icons.replay_10_rounded,
            size: 30,
            color: textColor.withValues(alpha: 0.7),
            onTap: () => engine.seekBackward(seconds: 10),
          )
        else
          _ControlBtn(
            icon: Icons.skip_previous_rounded,
            size: 36,
            color: textColor.withValues(alpha: 0.7),
            onTap: () => engine.skipPrevious(),
          ),
        const SizedBox(width: 32),
        GestureDetector(
          onTap: () {
            if (engine.isLoading) return;
            if (engine.isPlaying) {
              engine.pause();
              _rotationController.stop();
            } else {
              engine.resume();
              _rotationController.repeat();
            }
          },
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: engine.isLoading ? primaryColor.withValues(alpha: 0.5) : primaryColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: primaryColor.withValues(alpha: 0.4), blurRadius: 30, offset: const Offset(0, 8)),
              ],
            ),
            child: engine.isLoading
                ? Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.onPrimary,
                      strokeWidth: 3,
                    ),
                  )
                : Icon(
                    engine.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: 42,
                  ),
          ),
        ),
        const SizedBox(width: 32),
        if (isPodcast)
          _ControlBtn(
            icon: Icons.forward_30_rounded,
            size: 30,
            color: textColor.withValues(alpha: 0.7),
            onTap: () => engine.seekForward(seconds: 30),
          )
        else
          _ControlBtn(
            icon: Icons.skip_next_rounded,
            size: 36,
            color: textColor.withValues(alpha: 0.7),
            onTap: () => engine.skipNext(),
          ),
      ],
    );
  }

  Widget _buildSecondaryControls(RadioEngine engine, Color cardColor, Color primaryColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: cardColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildFavBtn(engine, primaryColor, textColor),
          _buildRecordBtn(engine, primaryColor, textColor),
          _buildEqBtn(engine, textColor),
          _buildShareBtn(engine, textColor),
        ],
      ),
    );
  }

  Widget _buildFavBtn(RadioEngine engine, Color primaryColor, Color textColor) {
    final station = engine.currentStation;
    if (station == null) return const SizedBox.shrink();
    
    return FutureBuilder<bool>(
      future: engine.isFavorite(station.url, uuid: station.uuid),
      builder: (context, snap) {
        final isFav = snap.data == true;
        return IconButton(
          icon: Icon(isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: isFav ? primaryColor : textColor.withValues(alpha: 0.7)),
          onPressed: () async {
            await engine.toggleFavorite(station);
            setState(() {});
          },
        );
      },
    );
  }

  Widget _buildRecordBtn(RadioEngine engine, Color primaryColor, Color textColor) {
    final isRecording = engine.isRecording;
    return IconButton(
      icon: Icon(isRecording ? Icons.stop_circle_rounded : Icons.fiber_manual_record_rounded, color: isRecording ? primaryColor : textColor.withValues(alpha: 0.7)),
      onPressed: () => _showRecordingSheet(engine),
    );
  }

  Widget _buildEqBtn(RadioEngine engine, Color textColor) {
    return IconButton(
      icon: Icon(Icons.equalizer_rounded, color: textColor.withValues(alpha: 0.7)),
      onPressed: () => _showEqualizerSheet(engine),
    );
  }

  Widget _buildShareBtn(RadioEngine engine, Color textColor) {
    return IconButton(
      icon: Icon(Icons.share_rounded, color: textColor.withValues(alpha: 0.7)),
      onPressed: () {
        final station = engine.currentStation;
        if (station != null) {
          Share.share('Listening to ${station.name} on Flux Radio! 📻\n${station.url}');
        }
      },
    );
  }

  Widget _buildErrorMessage(RadioEngine engine, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.error_outline_rounded, color: theme.colorScheme.error, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  engine.errorMessage!,
                  style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (engine.currentStation != null) {
                      engine.playStation(engine.currentStation!);
                    } else if (engine.currentEpisode != null) {
                      engine.playEpisode(engine.currentEpisode!);
                    }
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('TRY AGAIN', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => engine.clearError(),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    side: BorderSide(color: theme.colorScheme.error),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _showEqualizerSheet(RadioEngine engine) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final isWide = MediaQuery.of(context).size.width > 600;
        return Center(
          child: SizedBox(
            width: isWide ? 500 : double.infinity,
            child: _GlassSheetWrapper(
              theme: Theme.of(context),
              child: _EqualizerSheet(engine: engine),
            ),
          ),
        );
      },
    );
  }

  void _showRecordingSheet(RadioEngine engine) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final isWide = MediaQuery.of(context).size.width > 600;
        return Center(
          child: SizedBox(
            width: isWide ? 500 : double.infinity,
            child: _GlassSheetWrapper(
              theme: Theme.of(context),
              child: _RecordingSheet(engine: engine),
            ),
          ),
        );
      },
    );
  }
}

class _GlassSheetWrapper extends StatelessWidget {
  final Widget child;
  final ThemeData theme;
  const _GlassSheetWrapper({required this.child, required this.theme});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.8),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
              width: 0.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class SpectrumPainter extends CustomPainter {
  final FragmentShader shader;
  final double currentFreq;
  final bool isPlaying;
  final double time;

  SpectrumPainter({required this.shader, required this.currentFreq, required this.isPlaying, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, currentFreq + (isPlaying ? math.sin(time * math.pi * 2) * 0.05 : 0));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant SpectrumPainter oldDelegate) => 
      oldDelegate.time != time || oldDelegate.currentFreq != currentFreq || oldDelegate.isPlaying != isPlaying;
}

class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback onTap;

  const _ControlBtn({required this.icon, required this.color, required this.size, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: size),
      ),
    );
  }
}

class _EqualizerSheet extends StatelessWidget {
  final RadioEngine engine;
  const _EqualizerSheet({required this.engine});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final primaryColor = theme.primaryColor;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: textColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2))),
          Text('AUDIO EQUALIZER', style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 3)),
          const SizedBox(height: 24),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _PresetChip(label: 'Flat', onTap: () => engine.resetEqualizer(), primaryColor: primaryColor, textColor: textColor),
                const SizedBox(width: 8),
                _PresetChip(label: 'Pop', onTap: () => _applyPreset(engine, [3, 2, 0, 1, 3], bass: 200), primaryColor: primaryColor, textColor: textColor),
                const SizedBox(width: 8),
                _PresetChip(label: 'Rock', onTap: () => _applyPreset(engine, [5, 3, -1, 3, 5], bass: 400), primaryColor: primaryColor, textColor: textColor),
                const SizedBox(width: 8),
                _PresetChip(label: 'Jazz', onTap: () => _applyPreset(engine, [4, 2, 1, 2, 4], bass: 150), primaryColor: primaryColor, textColor: textColor),
                const SizedBox(width: 8),
                _PresetChip(label: 'Classical', onTap: () => _applyPreset(engine, [5, 3, -2, 4, 4], bass: 100), primaryColor: primaryColor, textColor: textColor),
                const SizedBox(width: 8),
                _PresetChip(label: 'Dance', onTap: () => _applyPreset(engine, [6, 0, 2, 4, 1], bass: 600), primaryColor: primaryColor, textColor: textColor),
                const SizedBox(width: 8),
                _PresetChip(label: 'Bass Boost', onTap: () => _applyPreset(engine, [8, 5, 0, 0, 0], bass: 900), primaryColor: primaryColor, textColor: textColor),
                const SizedBox(width: 8),
                _PresetChip(label: 'Hi-Fi', onTap: () => _applyPreset(engine, [2, 1, 0, 2, 4], bass: 250), primaryColor: primaryColor, textColor: textColor),
                const SizedBox(width: 8),
                _PresetChip(label: 'Vocal', onTap: () => _applyPreset(engine, [-2, -1, 3, 4, 2], bass: 0), primaryColor: primaryColor, textColor: textColor),
                const SizedBox(width: 8),
                _PresetChip(label: 'Electronic', onTap: () => _applyPreset(engine, [5, 2, 0, 3, 6], bass: 500), primaryColor: primaryColor, textColor: textColor),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Consumer<RadioEngine>(
            builder: (context, eng, _) => Column(
              children: [
                SizedBox(
                  height: 180,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(eng.equalizerBands.length, (i) {
                      final freq = eng.equalizerCenterFrequencies[i];
                      final label = freq >= 1000 ? '${(freq / 1000).toStringAsFixed(1)}k' : '${freq}Hz';
                      return Column(
                        children: [
                          Expanded(
                            child: RotatedBox(
                              quarterTurns: 3,
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 3,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                ),
                                child: Slider(
                                  value: eng.equalizerBands[i],
                                  min: -15,
                                  max: 15,
                                  onChanged: (v) => eng.updateEqualizerBand(i, v),
                                  activeColor: primaryColor,
                                  inactiveColor: textColor.withValues(alpha: 0.1),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(label, style: TextStyle(color: textColor.withValues(alpha: 0.4), fontSize: 10)),
                          Text('${eng.equalizerBands[i].toInt()}dB', style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 20),
                _EffectSlider(
                  label: 'BASS BOOST',
                  value: eng.bassBoostStrength,
                  max: 1000,
                  icon: Icons.speaker_group_outlined,
                  onChanged: (v) => eng.setBassBoostStrength(v),
                  primaryColor: primaryColor,
                  textColor: textColor,
                  valueLabel: '${(eng.bassBoostStrength / 10).toInt()}%',
                ),
                _EffectSlider(
                  label: 'LOUDNESS',
                  value: eng.loudnessGain,
                  max: 1000,
                  icon: Icons.volume_up_outlined,
                  onChanged: (v) => eng.setLoudnessGain(v),
                  primaryColor: primaryColor,
                  textColor: textColor,
                  valueLabel: '${(eng.loudnessGain / 100).toStringAsFixed(1)}x',
                ),
                _EffectSlider(
                  label: 'SPEED',
                  value: eng.speed,
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
                  icon: Icons.speed,
                  onChanged: (v) => eng.setPlaybackSpeed(v),
                  primaryColor: primaryColor,
                  textColor: textColor,
                  valueLabel: '${eng.speed.toStringAsFixed(2)}x',
                ),
                _EffectSlider(
                  label: 'PITCH',
                  value: eng.pitch,
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
                  icon: Icons.height,
                  onChanged: (v) => eng.setPlaybackPitch(v),
                  primaryColor: primaryColor,
                  textColor: textColor,
                  valueLabel: '${eng.pitch.toStringAsFixed(2)}x',
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: () => Navigator.pop(context), child: Text('DONE', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, letterSpacing: 1.5))),
        ],
      ),
    );
  }

  void _applyPreset(RadioEngine engine, List<double> values, {double bass = 0.0, double speed = 1.0, double pitch = 1.0}) {
    for (int i = 0; i < values.length && i < engine.equalizerBands.length; i++) {
      engine.updateEqualizerBand(i, values[i]);
    }
    engine.setBassBoostStrength(bass);
    engine.setPlaybackSpeed(speed);
    engine.setPlaybackPitch(pitch);
  }
}

class _EffectSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final IconData icon;
  final Function(double) onChanged;
  final Color primaryColor;
  final Color? textColor;
  final String valueLabel;

  const _EffectSlider({
    required this.label,
    required this.value,
    this.min = 0.0,
    required this.max,
    this.divisions,
    required this.icon,
    required this.onChanged,
    required this.primaryColor,
    required this.textColor,
    required this.valueLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: textColor?.withValues(alpha: 0.4), size: 14),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label, style: TextStyle(color: textColor?.withValues(alpha: 0.4), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
            Text(valueLabel, style: TextStyle(color: primaryColor, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
            activeColor: primaryColor,
            inactiveColor: textColor?.withValues(alpha: 0.1),
          ),
        ),
      ],
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color primaryColor;
  final Color textColor;
  const _PresetChip({required this.label, required this.onTap, required this.primaryColor, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(color: primaryColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: primaryColor.withValues(alpha: 0.5))),
        child: Text(label, style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _RecordingSheet extends StatelessWidget {
  final RadioEngine engine;
  const _RecordingSheet({required this.engine});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final primaryColor = theme.primaryColor;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: textColor?.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2))),
          Text('STREAM RECORDING', style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 2)),
          const SizedBox(height: 20),
          Consumer<RadioEngine>(
            builder: (context, eng, _) {
              if (eng.isRecording) {
                return Column(
                  children: [
                    Icon(Icons.mic_rounded, color: primaryColor, size: 48),
                    const SizedBox(height: 8),
                    Text(_fmtDuration(eng.recordingDuration), style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold)),
                    Text('RECORDING...', style: TextStyle(color: primaryColor, fontSize: 10, fontWeight: FontWeight.w900)),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Consumer<RadioEngine>(
              builder: (context, eng, _) {
                if (eng.savedRecordings.isEmpty && !eng.isRecording) {
                  return Center(child: Text('No recordings found', style: TextStyle(color: textColor?.withValues(alpha: 0.4))));
                }
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: eng.savedRecordings.length,
                  itemBuilder: (context, i) {
                    final path = eng.savedRecordings[eng.savedRecordings.length - 1 - i];
                    final name = path.split('/').last;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.audiotrack_rounded, color: textColor?.withValues(alpha: 0.4)),
                      title: Text(name, style: TextStyle(color: textColor?.withValues(alpha: 0.7), fontSize: 13), overflow: TextOverflow.ellipsis),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: Icon(Icons.share, color: textColor?.withValues(alpha: 0.4), size: 20), onPressed: () => Share.shareXFiles([XFile(path)])),
                          IconButton(icon: Icon(Icons.open_in_new, color: primaryColor, size: 20), onPressed: () => OpenFilex.open(path)),
                          IconButton(icon: Icon(Icons.delete_outline, color: textColor?.withValues(alpha: 0.2), size: 20), onPressed: () => eng.deleteRecording(path)),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    if (engine.isRecording) {
                      engine.stopRecording();
                    } else {
                      engine.startRecording();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: engine.isRecording ? (theme.colorScheme.error) : primaryColor,
                      foregroundColor: engine.isRecording ? theme.colorScheme.onError : theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: Text(engine.isRecording ? 'STOP RECORDING' : 'START RECORDING'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmtDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

