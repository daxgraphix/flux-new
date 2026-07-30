import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_shaders/flutter_shaders.dart';
import '../../flux_engine/station_provider.dart';
import '../../flux_engine/playback_controller.dart';
import '../../flux_engine/audio_effects_service.dart';
import '../../flux_engine/library_manager.dart';
import '../../flux_engine/settings_service.dart';
import '../../flux_engine/recording_service.dart';
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
  const NowPlayingScreen({
    super.key,
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

    final playbackController = Provider.of<PlaybackController>(context, listen: false);
    if (playbackController.isPlaying) {
      _rotationController.repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final playbackController = Provider.of<PlaybackController>(context);
    if (playbackController.isPlaying && !_rotationController.isAnimating) {
      _rotationController.repeat();
    } else if (!playbackController.isPlaying && _rotationController.isAnimating) {
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
      _dragStartValue = Provider.of<SettingsService>(context, listen: false).volume;
    }
  }

  void _onVerticalDragUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    if (_dragStart == null) return;
    final delta = (_dragStart!.y - details.globalPosition.dy) / constraints.maxHeight;
    final newValue = (_dragStartValue + delta).clamp(0.0, 1.0);

    if (_dragType == 'volume') {
      Provider.of<SettingsService>(context, listen: false).setVolume(newValue);
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

    return Consumer<PlaybackController>(
      builder: (context, controller, _) {
        final effectsService = Provider.of<AudioEffectsService>(context);
        final libraryManager = Provider.of<LibraryManager>(context);
        final stationProvider = Provider.of<StationProvider>(context);

        final station = controller.currentStation;
        final episode = controller.currentEpisode;

        if (station == null && episode == null) {
          return Scaffold(
            backgroundColor: backgroundColor,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.music_note_rounded, size: 64, color: secondaryTextColor.withValues(alpha: 0.2)),
                  const SizedBox(height: 16),
                  Text('Nothing playing', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('GO BACK')),
                ],
              ),
            ),
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
                onVerticalDragEnd: (details) {
                  _onVerticalDragEnd(details);
                  if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
                    Navigator.pop(context);
                  }
                },
                onHorizontalDragEnd: (details) {
                  if (details.primaryVelocity != null && details.primaryVelocity! > 800) {
                    Navigator.pop(context);
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
                                  child: _buildArtwork(station, episode, controller, primaryColor, backgroundColor),
                                ),
                              ),
                              AnimatedOpacity(
                                opacity: _showControls ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 300),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      _buildStationInfo(controller, textColor, secondaryTextColor, primaryColor),
                                      SizedBox(height: isWide ? 32 : 16),
                                      if (controller.errorMessage != null)
                                        _buildErrorMessage(controller, stationProvider, theme),
                                      _buildSpectrumVisualizer(station, episode, controller),
                                      SizedBox(height: isWide ? 24 : 20),
                                      _buildProgressBar(controller, primaryColor, secondaryTextColor),
                                      SizedBox(height: isWide ? 40 : 24),
                                      _buildMainControls(controller, stationProvider, primaryColor, textColor),
                                      SizedBox(height: isWide ? 40 : 24),
                                      _buildSecondaryControls(controller, effectsService, libraryManager, cardColor, primaryColor, textColor),
                                      SizedBox(height: isWide ? 48 : 32),
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
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: double.infinity,
          color: backgroundColor,
        ),
        if (imageUrl.isNotEmpty)
          Positioned.fill(
            child: Opacity(
              opacity: 0.2,
              child: FluxImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
              ),
            ),
          ),
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(
              color: backgroundColor.withValues(alpha: 0.4),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context, Color textColor, Color primaryColor) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.keyboard_arrow_down_rounded, color: textColor, size: 40), // Larger
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'FLUX RADIO',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: primaryColor,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4.0,
                  ),
                ),
                Text(
                  'NOW PLAYING',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(_isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded, color: textColor, size: 32),
            onPressed: _toggleFullscreen,
          ),
        ],
      ),
    );
  }

  Widget _buildArtwork(RadioStation? station, Episode? episode, PlaybackController controller, Color primaryColor, Color backgroundColor) {
    final size = _isFullscreen ? 320.0 : 280.0;
    final theme = Theme.of(context);
    final imageUrl = station?.favicon ?? episode?.image ?? '';

    return Center(
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseAnim, _rotationController]),
        builder: (context, child) {
          return Container(
            width: size * _pulseAnim.value,
            height: size * _pulseAnim.value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: controller.isPlaying ? 0.25 : 0.05),
                  blurRadius: 100,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Transform.rotate(
                angle: _rotationController.value * 2 * math.pi,
                child: Hero(
                  tag: 'player_artwork',
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: primaryColor.withValues(alpha: 0.3), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 30,
                          spreadRadius: 2,
                          offset: const Offset(0, 10),
                        ),
                      ],
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

  Widget _buildStationInfo(PlaybackController controller, Color textColor, Color secondaryTextColor, Color primaryColor) {
    final theme = Theme.of(context);
    final title = controller.currentTitle;
    final subtitle = (controller.currentEpisode?.podcastTitle ?? controller.currentSubtitle);

    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: textColor,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.0,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle.toUpperCase(),
          style: theme.textTheme.labelMedium?.copyWith(
            color: secondaryTextColor,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        _buildLiveBadge(controller, primaryColor, secondaryTextColor),
      ],
    );
  }

  Widget _buildLiveBadge(PlaybackController controller, Color primaryColor, Color secondaryTextColor) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final isPlaying = controller.isPlaying;
        final isLoading = controller.isLoading;
        final hasError = controller.errorMessage != null;
        
        final color = hasError 
            ? Colors.redAccent 
            : (isLoading ? Colors.orangeAccent : (isPlaying ? primaryColor : secondaryTextColor));
            
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withValues(alpha: 0.6), width: 2), // Thicker border
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 3, color: color),
                )
              else
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    boxShadow: isPlaying ? [BoxShadow(color: color.withValues(alpha: 0.8), blurRadius: 10)] : null,
                  ),
                ),
              const SizedBox(width: 10),
              Text(
                hasError ? 'ERROR' : (isLoading ? 'LOADING...' : (isPlaying ? (controller.currentEpisode != null ? 'PODCAST' : 'LIVE STREAM') : 'PAUSED')),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSpectrumVisualizer(RadioStation? station, Episode? episode, PlaybackController controller) {
    if (controller.errorMessage != null) return const SizedBox.shrink();
    
    return ShaderBuilder(
      (context, shader, child) {
        return CustomPaint(
          size: const Size(double.infinity, 80),
          painter: SpectrumPainter(
            shader: shader,
            currentFreq: station?.frequency ?? 98.0,
            isPlaying: controller.isPlaying,
            time: _waveController.value,
          ),
        );
      },
      assetKey: 'assets/shaders/spectrum.frag',
    );
  }

  Widget _buildProgressBar(PlaybackController controller, Color primaryColor, Color secondaryTextColor) {
    final theme = Theme.of(context);
    return StreamBuilder<Duration?>(
      stream: controller.durationStream,
      builder: (context, durationSnap) {
        final duration = durationSnap.data ?? controller.duration;
        final isLive = duration == Duration.zero;

        return StreamBuilder<Duration>(
          stream: controller.positionStream,
          initialData: controller.position,
          builder: (context, positionSnap) {
            final position = positionSnap.data ?? Duration.zero;

            if (isLive) {
              return Container(
                height: 4,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: secondaryTextColor.withValues(alpha: 0.1), 
                  borderRadius: BorderRadius.circular(2)
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: controller.isPlaying ? 1.0 : 0.0,
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
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    thumbColor: primaryColor,
                    activeTrackColor: primaryColor,
                    inactiveTrackColor: theme.colorScheme.outlineVariant,
                    overlayColor: primaryColor.withValues(alpha: 0.15),
                    trackShape: const RoundedRectSliderTrackShape(),
                  ),
                  child: Slider(
                    value: position.inSeconds.clamp(0, duration.inSeconds).toDouble(),
                    min: 0,
                    max: duration.inSeconds.toDouble(),
                    onChanged: (v) => controller.seek(Duration(seconds: v.toInt())),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_fmt(position), style: theme.textTheme.bodySmall?.copyWith(color: secondaryTextColor, fontWeight: FontWeight.w600)),
                      Text(_fmt(duration), style: theme.textTheme.bodySmall?.copyWith(color: secondaryTextColor, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMainControls(PlaybackController controller, StationProvider stationProvider, Color primaryColor, Color textColor) {
    final isPodcast = controller.currentEpisode != null;
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ControlBtn(
          icon: Icons.skip_previous_rounded,
          size: isPodcast ? 32 : 36,
          color: textColor.withValues(alpha: 0.8),
          onTap: () => controller.skipPrevious(stationProvider.stations, stationProvider.episodes),
        ),
        const SizedBox(width: 24),
        if (isPodcast)
          _ControlBtn(
            icon: Icons.replay_10_rounded,
            size: 28,
            color: textColor.withValues(alpha: 0.7),
            onTap: () => controller.seekBackward(seconds: 10),
          )
        else
          _ControlBtn(
            icon: Icons.replay_30_rounded,
            size: 28,
            color: textColor.withValues(alpha: 0.7),
            onTap: () => controller.seekBackward(seconds: 30),
          ),
        const SizedBox(width: 24),
        GestureDetector(
          onTap: () {
            if (controller.isLoading) return;
            if (controller.isPlaying) {
              controller.pause();
              _rotationController.stop();
            } else {
              controller.resume();
              _rotationController.repeat();
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [primaryColor, primaryColor.withBlue(255)], 
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.4),
                  blurRadius: 25,
                  spreadRadius: 1,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: controller.isLoading
                ? Padding(
                    padding: const EdgeInsets.all(26.0),
                    child: CircularProgressIndicator(
                      color: theme.colorScheme.onPrimary,
                      strokeWidth: 4,
                    ),
                  )
                : Icon(
                    controller.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: theme.colorScheme.onPrimary,
                    size: 48,
                  ),
          ),
        ),
        const SizedBox(width: 24),
        if (isPodcast)
          _ControlBtn(
            icon: Icons.forward_30_rounded,
            size: 28,
            color: textColor.withValues(alpha: 0.7),
            onTap: () => controller.seekForward(seconds: 30),
          )
        else
          _ControlBtn(
            icon: Icons.forward_30_rounded,
            size: 28,
            color: textColor.withValues(alpha: 0.7),
            onTap: () => controller.seekForward(seconds: 30),
          ),
        const SizedBox(width: 24),
        _ControlBtn(
          icon: Icons.skip_next_rounded,
          size: isPodcast ? 32 : 36,
          color: textColor.withValues(alpha: 0.8),
          onTap: () => controller.skipNext(stationProvider.stations, stationProvider.episodes),
        ),
      ],
    );
  }

  Widget _buildSecondaryControls(PlaybackController controller, AudioEffectsService effectsService, LibraryManager libraryManager, Color cardColor, Color primaryColor, Color textColor) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outline, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildFavBtn(controller, libraryManager, primaryColor, textColor),
          _buildRecordBtn(controller, primaryColor, textColor),
          _buildSleepTimerBtn(controller, textColor),
          _buildEqBtn(effectsService, textColor),
          _buildShareBtn(controller, textColor),
        ],
      ),
    );
  }

  Widget _buildSleepTimerBtn(PlaybackController controller, Color textColor) {
    return StreamBuilder<Duration?>(
      stream: controller.sleepTimerStream,
      initialData: controller.sleepTimerDuration,
      builder: (context, snapshot) {
        final remaining = snapshot.data;
        final hasTimer = remaining != null && remaining.inSeconds > 0;
        
        return IconButton(
          icon: Icon(
            hasTimer ? Icons.hourglass_full_rounded : Icons.hourglass_empty_rounded,
            color: hasTimer ? Colors.amber : textColor.withValues(alpha: 0.7),
          ),
          onPressed: () => _showSleepTimerSheet(controller),
        );
      },
    );
  }

  Widget _buildFavBtn(PlaybackController controller, LibraryManager libraryManager, Color primaryColor, Color textColor) {
    final station = controller.currentStation;
    if (station == null) return const SizedBox.shrink();
    
    return FutureBuilder<bool>(
      future: libraryManager.isFavorite(station.url, uuid: station.uuid),
      builder: (context, snap) {
        final isFav = snap.data == true;
        return IconButton(
          icon: Icon(isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: isFav ? primaryColor : textColor.withValues(alpha: 0.7)),
          onPressed: () async {
            await libraryManager.toggleFavorite(station);
            setState(() {});
          },
        );
      },
    );
  }

  Widget _buildRecordBtn(PlaybackController controller, Color primaryColor, Color textColor) {
    final recordingService = Provider.of<RecordingService>(context);
    final isRecording = recordingService.isRecording;
    return IconButton(
      icon: Icon(isRecording ? Icons.stop_circle_rounded : Icons.fiber_manual_record_rounded, color: isRecording ? primaryColor : textColor.withValues(alpha: 0.7)),
      onPressed: () => _showRecordingSheet(controller),
    );
  }

  Widget _buildEqBtn(AudioEffectsService effectsService, Color textColor) {
    return IconButton(
      icon: Icon(Icons.equalizer_rounded, color: textColor.withValues(alpha: 0.7)),
      onPressed: () => _showEqualizerSheet(effectsService),
    );
  }

  Widget _buildShareBtn(PlaybackController controller, Color textColor) {
    return IconButton(
      icon: Icon(Icons.share_rounded, color: textColor.withValues(alpha: 0.7)),
      onPressed: () {
        final station = controller.currentStation;
        if (station != null) {
          Share.share('Listening to ${station.name} on Flux Radio! 📻\n${station.url}');
        }
      },
    );
  }

  Widget _buildErrorMessage(PlaybackController controller, StationProvider stationProvider, ThemeData theme) {
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
                  controller.errorMessage!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
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
                    if (controller.currentStation != null) {
                      controller.playStation(controller.currentStation!);
                    } else if (controller.currentEpisode != null) {
                      controller.playEpisode(controller.currentEpisode!);
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
                  onPressed: () => controller.clearError(),
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

  void _showEqualizerSheet(AudioEffectsService effectsService) {
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
              child: _EqualizerSheet(effectsService: effectsService),
            ),
          ),
        );
      },
    );
  }

  void _showRecordingSheet(PlaybackController controller) {
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
              child: _RecordingSheet(controller: controller),
            ),
          ),
        );
      },
    );
  }

  void _showSleepTimerSheet(PlaybackController controller) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final isWide = MediaQuery.of(context).size.width > 600;
        final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
        final primaryColor = Theme.of(context).primaryColor;
        
        return Center(
          child: SizedBox(
            width: isWide ? 400 : double.infinity,
            child: _GlassSheetWrapper(
              theme: Theme.of(context),
              child: _SleepTimerSheet(
                controller: controller,
                textColor: textColor,
                primaryColor: primaryColor,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SleepTimerSheet extends StatelessWidget {
  final PlaybackController controller;
  final Color textColor;
  final Color primaryColor;

  const _SleepTimerSheet({
    required this.controller,
    required this.textColor,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final options = [
      const Duration(minutes: 5),
      const Duration(minutes: 15),
      const Duration(minutes: 30),
      const Duration(minutes: 45),
      const Duration(hours: 1),
      const Duration(hours: 2),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: textColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2))),
          Text('SLEEP TIMER', style: theme.textTheme.labelLarge?.copyWith(color: textColor, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
          const SizedBox(height: 16),
          StreamBuilder<Duration?>(
            stream: controller.sleepTimerStream,
            initialData: controller.sleepTimerDuration,
            builder: (context, snapshot) {
              final remaining = snapshot.data;
              return Column(
                children: [
                  if (remaining != null && remaining.inSeconds > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Remaining: ${remaining.inMinutes} min',
                        style: TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final opt in options)
                        ChoiceChip(
                          label: Text(opt.inHours > 0 ? '${opt.inHours}h' : '${opt.inMinutes}m'),
                          selected: remaining?.inMinutes == opt.inMinutes,
                          onSelected: (_) {
                            controller.setSleepTimer(opt);
                            if (context.mounted) Navigator.pop(context);
                          },
                          selectedColor: primaryColor,
                          labelStyle: TextStyle(color: remaining?.inMinutes == opt.inMinutes ? Colors.white : textColor),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              controller.cancelSleepTimer();
              if (context.mounted) Navigator.pop(context);
            },
            child: Text('CANCEL TIMER', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: () => Navigator.pop(context), child: Text('DONE', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, letterSpacing: 1.5))),
        ],
      ),
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
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.1), width: 1.5),
        ),
        child: Icon(icon, color: color, size: size),
      ),
    );
  }
}

class _EqualizerSheet extends StatelessWidget {
  final AudioEffectsService effectsService;
  const _EqualizerSheet({required this.effectsService});

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
          Text('AUDIO EQUALIZER', style: theme.textTheme.labelLarge?.copyWith(color: textColor, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
          const SizedBox(height: 24),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _PresetChip(label: 'Flat', onTap: () => effectsService.resetEqualizer(), primaryColor: primaryColor, textColor: textColor),
                const SizedBox(width: 8),
                _PresetChip(label: 'Pop', onTap: () => _applyPreset(effectsService, [3, 2, 0, 1, 3], bass: 200), primaryColor: primaryColor, textColor: textColor),
                const SizedBox(width: 8),
                _PresetChip(label: 'Rock', onTap: () => _applyPreset(effectsService, [5, 3, -1, 3, 5], bass: 400), primaryColor: primaryColor, textColor: textColor),
                const SizedBox(width: 8),
                _PresetChip(label: 'Jazz', onTap: () => _applyPreset(effectsService, [4, 2, 1, 2, 4], bass: 150), primaryColor: primaryColor, textColor: textColor),
                const SizedBox(width: 8),
                _PresetChip(label: 'Classical', onTap: () => _applyPreset(effectsService, [5, 3, -2, 4, 4], bass: 100), primaryColor: primaryColor, textColor: textColor),
                const SizedBox(width: 8),
                _PresetChip(label: 'Dance', onTap: () => _applyPreset(effectsService, [6, 0, 2, 4, 1], bass: 600), primaryColor: primaryColor, textColor: textColor),
                const SizedBox(width: 8),
                _PresetChip(label: 'Bass Boost', onTap: () => _applyPreset(effectsService, [8, 5, 0, 0, 0], bass: 900), primaryColor: primaryColor, textColor: textColor),
                const SizedBox(width: 8),
                _PresetChip(label: 'Hi-Fi', onTap: () => _applyPreset(effectsService, [2, 1, 0, 2, 4], bass: 250), primaryColor: primaryColor, textColor: textColor),
                const SizedBox(width: 8),
                _PresetChip(label: 'Vocal', onTap: () => _applyPreset(effectsService, [-2, -1, 3, 4, 2], bass: 0), primaryColor: primaryColor, textColor: textColor),
                const SizedBox(width: 8),
                _PresetChip(label: 'Electronic', onTap: () => _applyPreset(effectsService, [5, 2, 0, 3, 6], bass: 500), primaryColor: primaryColor, textColor: textColor),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Consumer<AudioEffectsService>(
            builder: (context, effects, _) => Column(
              children: [
                SizedBox(
                  height: 180,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(effects.equalizerBands.length, (i) {
                      final freq = effects.equalizerCenterFrequencies[i];
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
                                  value: effects.equalizerBands[i],
                                  min: -15,
                                  max: 15,
                                  onChanged: (v) => effects.updateEqualizerBand(i, v),
                                  activeColor: primaryColor,
                                  inactiveColor: textColor.withValues(alpha: 0.1),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(label, style: TextStyle(color: textColor.withValues(alpha: 0.4), fontSize: 10)),
                          Text('${effects.equalizerBands[i].toInt()}dB', style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 20),
                _EffectSlider(
                  label: 'BASS BOOST',
                  value: effects.bassBoostStrength,
                  max: 1000,
                  icon: Icons.speaker_group_outlined,
                  onChanged: (v) => effects.setBassBoostStrength(v),
                  primaryColor: primaryColor,
                  textColor: textColor,
                  valueLabel: '${(effects.bassBoostStrength / 10).toInt()}%',
                ),
                _EffectSlider(
                  label: 'LOUDNESS',
                  value: effects.loudnessGain,
                  max: 1000,
                  icon: Icons.volume_up_outlined,
                  onChanged: (v) => effects.setLoudness(v),
                  primaryColor: primaryColor,
                  textColor: textColor,
                  valueLabel: '${(effects.loudnessGain / 100).toStringAsFixed(1)}x',
                ),
                _EffectSlider(
                  label: 'SPEED',
                  value: effects.speed,
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
                  icon: Icons.speed,
                  onChanged: (v) => effects.setSpeed(v),
                  primaryColor: primaryColor,
                  textColor: textColor,
                  valueLabel: '${effects.speed.toStringAsFixed(2)}x',
                ),
                _EffectSlider(
                  label: 'PITCH',
                  value: effects.pitch,
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
                  icon: Icons.height,
                  onChanged: (v) => effects.setPitch(v),
                  primaryColor: primaryColor,
                  textColor: textColor,
                  valueLabel: '${effects.pitch.toStringAsFixed(2)}x',
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

  void _applyPreset(AudioEffectsService effects, List<double> values, {double bass = 0.0, double speed = 1.0, double pitch = 1.0}) {
    for (int i = 0; i < values.length && i < effects.equalizerBands.length; i++) {
      effects.updateEqualizerBand(i, values[i]);
    }
    effects.setBassBoostStrength(bass);
    effects.setSpeed(speed);
    effects.setPitch(pitch);
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

class _RecordingSheet extends StatefulWidget {
  final PlaybackController controller;
  const _RecordingSheet({required this.controller});

  @override
  State<_RecordingSheet> createState() => _RecordingSheetState();
}

class _RecordingSheetState extends State<_RecordingSheet> {
  List<String> _recordings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecordings();
  }

  Future<void> _loadRecordings() async {
    final recordingService = Provider.of<RecordingService>(context, listen: false);
    final list = await recordingService.getSavedRecordings();
    if (mounted) {
      setState(() {
        _recordings = list;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final primaryColor = theme.primaryColor;
    final recordingService = Provider.of<RecordingService>(context);

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: textColor?.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2))),
          Text('STREAM RECORDING', style: theme.textTheme.labelLarge?.copyWith(color: textColor, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
          const SizedBox(height: 20),
          if (recordingService.isRecording)
            Column(
              children: [
                Icon(Icons.mic_rounded, color: primaryColor, size: 48),
                const SizedBox(height: 8),
                Text(_fmtDuration(recordingService.recordingDuration), style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold)),
                Text('RECORDING...', style: TextStyle(color: primaryColor, fontSize: 10, fontWeight: FontWeight.w900)),
              ],
            ),
          const SizedBox(height: 20),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _recordings.isEmpty && !recordingService.isRecording
                ? Center(child: Text('No recordings found', style: TextStyle(color: textColor?.withValues(alpha: 0.4))))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _recordings.length,
                    itemBuilder: (context, i) {
                      final path = _recordings[i];
                      final name = path.split('/').last;
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          leading: Icon(Icons.audiotrack_rounded, color: textColor?.withValues(alpha: 0.6)),
                          title: Text(name, style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.share, color: textColor?.withValues(alpha: 0.5), size: 18), 
                                onPressed: () => Share.shareXFiles([XFile(path)])
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_outline, color: theme.colorScheme.error.withValues(alpha: 0.7), size: 18), 
                                onPressed: () async {
                                  await recordingService.deleteRecording(path);
                                  _loadRecordings();
                                }
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    if (recordingService.isRecording) {
                      await recordingService.stopRecording();
                      _loadRecordings();
                    } else if (widget.controller.currentStation != null) {
                      await recordingService.startRecording(widget.controller.currentStation!);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: recordingService.isRecording ? (theme.colorScheme.error) : primaryColor,
                      foregroundColor: recordingService.isRecording ? theme.colorScheme.onError : theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: Text(recordingService.isRecording ? 'STOP RECORDING' : 'START RECORDING'),
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

