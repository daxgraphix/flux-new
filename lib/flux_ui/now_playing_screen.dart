import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:screen_brightness/screen_brightness.dart';
import '../../flux_engine/radio_engine.dart';
import '../../flux_hardware/radio_service.dart';

// ─── Color System ────────────────────────────────────────────────
import 'widgets/flux_image.dart';

const _kBlack = Color(0xFF0A0A0A);
const _kCard = Color(0xFF1C1C1C);
const _kRed = Color(0xFFE53935);
const _kWhite = Colors.white;
const _kGrey = Color(0xFF9E9E9E);

class NowPlayingScreen extends StatefulWidget {
  final RadioEngine engine;
  final bool isDark;

  const NowPlayingScreen({
    super.key,
    required this.engine,
    required this.isDark,
  });

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnim;

  bool _isFullscreen = false;
  bool _showControls = true;
  math.Point<double>? _dragStart;
  double _dragStartValue = 0;
  String _dragType = ''; // 'volume' or 'brightness'
  String _overlayText = '';
  bool _showOverlayText = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: false);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
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

    setState(() {
      if (_dragType == 'volume') {
        widget.engine.setVolume(newValue);
        _overlayText = 'Volume: ${(newValue * 100).round()}%';
      } else {
        ScreenBrightness().setScreenBrightness(newValue);
        _overlayText = 'Brightness: ${(newValue * 100).round()}%';
      }
      _showOverlayText = true;
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() => _showOverlayText = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RadioEngine>(
      builder: (context, engine, _) {
        final station = engine.currentStation;
        if (station == null) {
          return const Scaffold(
            backgroundColor: _kBlack,
            body: Center(
              child: Text('No station playing',
                  style: TextStyle(color: _kWhite)),
            ),
          );
        }

        return Scaffold(
          backgroundColor: _kBlack,
          body: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                onTap: () => setState(() => _showControls = !_showControls),
                onDoubleTap: _toggleFullscreen,
                onVerticalDragStart: (d) => _onVerticalDragStart(d, constraints),
                onVerticalDragUpdate: (d) => _onVerticalDragUpdate(d, constraints),
                onVerticalDragEnd: _onVerticalDragEnd,
                child: Stack(
                  children: [
                    // Background / Ambient effect
                    _buildBackground(station),

                    // Content
                    SafeArea(
                      child: Column(
                        children: [
                          AnimatedOpacity(
                            opacity: _showControls ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 300),
                            child: _buildTopBar(context),
                          ),
                          Expanded(
                            child: Center(
                              child: _buildArtwork(station, engine),
                            ),
                          ),
                          AnimatedOpacity(
                            opacity: _showControls ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 300),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Column(
                                children: [
                                  _buildStationInfo(station, engine),
                                  const SizedBox(height: 20),
                                  _buildWaveformBar(engine),
                                  const SizedBox(height: 20),
                                  _buildProgressBar(engine),
                                  const SizedBox(height: 24),
                                  _buildMainControls(engine),
                                  const SizedBox(height: 24),
                                  _buildSecondaryControls(engine),
                                  const SizedBox(height: 20),
                                  _buildVolumeSlider(engine),
                                  const SizedBox(height: 32),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Swipe Overlay
                    if (_showOverlayText)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            _overlayText,
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
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

  Widget _buildBackground(RadioStation station) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(color: _kBlack),
      child: Opacity(
        opacity: 0.15,
        child: FluxImage(
          imageUrl: station.favicon,
          fit: BoxFit.cover,
          errorWidget: Container(color: _kBlack),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                color: _kWhite, size: 32),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'NOW PLAYING',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _kWhite,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.5,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              _isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
              color: _kWhite,
              size: 28,
            ),
            onPressed: _toggleFullscreen,
          ),
        ],
      ),
    );
  }

  Widget _buildArtwork(RadioStation station, RadioEngine engine) {
    final size = _isFullscreen ? 280.0 : 220.0;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow ring (animated)
              if (engine.isPlaying)
                Container(
                  width: size * _pulseAnim.value + 20,
                  height: size * _pulseAnim.value + 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _kRed.withValues(alpha: 0.15 * _pulseAnim.value),
                      width: 2,
                    ),
                  ),
                ),
              // Main artwork circle
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kCard,
                  border: Border.all(color: _kRed, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: _kRed.withValues(alpha: engine.isPlaying ? 0.35 : 0.12),
                      blurRadius: 40,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: FluxImage(
                    imageUrl: station.favicon,
                    fit: BoxFit.cover,
                    placeholder: _buildFallbackArtwork(),
                    errorWidget: _buildFallbackArtwork(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFallbackArtwork() {
    return Container(
      color: _kCard,
      child: const Icon(Icons.radio_rounded, color: _kRed, size: 80),
    );
  }

  Widget _buildStationInfo(RadioStation station, RadioEngine engine) {
    return Column(
      children: [
        // Station name
        Text(
          station.name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _kWhite,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        // Country • Genre
        Text(
          [station.country, station.genre]
              .where((s) => s.isNotEmpty)
              .join(' • '),
          style: const TextStyle(color: _kGrey, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        // LIVE badge
        _buildLiveBadge(engine),
      ],
    );
  }

  Widget _buildLiveBadge(RadioEngine engine) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: _kRed.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _kRed.withValues(alpha: 0.6), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: engine.isPlaying
                      ? _kRed
                          .withValues(alpha: 0.6 + 0.4 * _pulseController.value)
                      : _kGrey,
                  boxShadow: engine.isPlaying
                      ? [
                          BoxShadow(
                            color: _kRed.withValues(alpha: 0.5),
                            blurRadius: 6,
                          )
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                engine.isPlaying ? 'LIVE' : 'PAUSED',
                style: TextStyle(
                  color: engine.isPlaying ? _kRed : _kGrey,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWaveformBar(RadioEngine engine) {
    if (!engine.isPlaying) return const SizedBox(height: 40);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _waveController,
        builder: (context, _) {
          return SizedBox(
            height: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(20, (i) {
                final phase = _waveController.value * 2 * math.pi;
                final height = 6.0 +
                    24.0 *
                        (0.5 +
                            0.5 *
                                math.sin(
                                    phase + i * math.pi / 5));
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 50),
                    width: 3,
                    height: height,
                    decoration: BoxDecoration(
                      color: i % 3 == 0
                          ? _kRed
                          : _kRed.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgressBar(RadioEngine engine) {
    final position = engine.position;
    final duration = engine.duration;
    final isLive = duration == Duration.zero;

    if (isLive) {
      return Row(
        children: [
          const Icon(Icons.fiber_manual_record, color: _kRed, size: 10),
          const SizedBox(width: 6),
          const Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(4)),
              child: LinearProgressIndicator(
                value: null,
                backgroundColor: Color(0xFF2A2A2A),
                valueColor: AlwaysStoppedAnimation<Color>(_kRed),
                minHeight: 3,
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Text('LIVE',
              style: TextStyle(
                  color: _kRed,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5)),
        ],
      );
    }

    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            thumbColor: _kRed,
            activeTrackColor: _kRed,
            inactiveTrackColor: const Color(0xFF2A2A2A),
            overlayColor: _kRed.withValues(alpha: 0.15),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(
            value: position.inSeconds
                .clamp(0, duration.inSeconds)
                .toDouble(),
            min: 0,
            max: duration.inSeconds.toDouble(),
            onChanged: duration.inSeconds > 0
                ? (v) => engine.seek(Duration(seconds: v.toInt()))
                : null,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_fmt(position),
                style: const TextStyle(color: _kGrey, fontSize: 12)),
            Text(_fmt(duration),
                style: const TextStyle(color: _kGrey, fontSize: 12)),
          ],
        ),
      ],
    );
  }

  Widget _buildMainControls(RadioEngine engine) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Skip prev
        _ControlBtn(
          icon: Icons.skip_previous_rounded,
          size: 36,
          color: Colors.white70,
          onTap: () {},
        ),
        const SizedBox(width: 24),
        // Play/Pause - BIG
        GestureDetector(
          onTap: () =>
              engine.isPlaying ? engine.pause() : engine.resume(),
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _kRed,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _kRed.withValues(alpha: 0.45),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              engine.isLoading
                  ? Icons.hourglass_top_rounded
                  : (engine.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded),
              color: _kWhite,
              size: 38,
            ),
          ),
        ),
        const SizedBox(width: 24),
        // Skip next
        _ControlBtn(
          icon: Icons.skip_next_rounded,
          size: 36,
          color: Colors.white70,
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildSecondaryControls(RadioEngine engine) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Favorite
        FutureBuilder<bool>(
          future: engine.isFavorite(
              engine.currentStation?.url ?? ''),
          builder: (context, snap) {
            final isFav = snap.data == true;
            return _ControlBtn(
              icon: isFav
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: isFav ? _kRed : Colors.white70,
              size: 26,
              onTap: () async {
                final st = engine.currentStation;
                if (st == null) return;
                if (isFav) {
                  await engine.removeFromFavorites(st.name);
                } else {
                  await engine.addToFavorites(st);
                }
                setState(() {});
              },
            );
          },
        ),
        // Record
        _ControlBtn(
          icon: engine.isRecording
              ? Icons.stop_circle_rounded
              : Icons.fiber_manual_record_rounded,
          color: engine.isRecording ? _kRed : Colors.white70,
          size: 26,
          onTap: () => _showRecordingSheet(engine),
        ),
        // Sleep Timer
        _ControlBtn(
          icon: engine.isSleepTimerActive
              ? Icons.timer_rounded
              : Icons.timer_outlined,
          color: engine.isSleepTimerActive ? _kRed : Colors.white70,
          size: 26,
          onTap: () => _showSleepTimerSheet(engine),
        ),
        // Equalizer
        _ControlBtn(
          icon: Icons.equalizer_rounded,
          color: Colors.white70,
          size: 26,
          onTap: () => _showEqualizerSheet(engine),
        ),
        // Share
        _ControlBtn(
          icon: Icons.share_rounded,
          color: Colors.white70,
          size: 26,
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildVolumeSlider(RadioEngine engine) {
    return Column(
      children: [
        Row(
          children: [
            const Icon(Icons.volume_down_rounded, color: _kGrey, size: 20),
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  thumbColor: _kWhite,
                  activeTrackColor: _kWhite,
                  inactiveTrackColor: const Color(0xFF2A2A2A),
                  overlayColor: Colors.white.withValues(alpha: 0.1),
                ),
                child: Slider(
                  value: engine.volume,
                  min: 0,
                  max: 1,
                  divisions: 20,
                  onChanged: engine.setVolume,
                ),
              ),
            ),
            const Icon(Icons.volume_up_rounded, color: _kGrey, size: 20),
          ],
        ),
        Text(
          '${(engine.volume * 100).round()}%',
          style: const TextStyle(color: _kGrey, fontSize: 11),
        ),
      ],
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _showSleepTimerSheet(RadioEngine engine) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SleepTimerSheet(engine: engine),
    );
  }

  void _showEqualizerSheet(RadioEngine engine) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _EqualizerSheet(engine: engine),
    );
  }

  void _showRecordingSheet(RadioEngine engine) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _RecordingSheet(engine: engine),
    );
  }
}

// ─── Control Button ──────────────────────────────────────────────
class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback onTap;

  const _ControlBtn({
    required this.icon,
    required this.color,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1C),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.06), width: 1),
        ),
        child: Icon(icon, color: color, size: size),
      ),
    );
  }
}

// ─── Equalizer Bottom Sheet ──────────────────────────────────────
class _EqualizerSheet extends StatelessWidget {
  final RadioEngine engine;
  const _EqualizerSheet({required this.engine});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF141414),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(color: Colors.black54, blurRadius: 20, spreadRadius: 5)
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text('AUDIO EQUALIZER',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3)),
          const SizedBox(height: 24),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _PresetChip(label: 'Flat', onTap: () => engine.resetEqualizer()),
                const SizedBox(width: 8),
                _PresetChip(label: 'Pop', onTap: () => _applyPreset(engine, [2, 1, 0, 1, 2])),
                const SizedBox(width: 8),
                _PresetChip(label: 'Rock', onTap: () => _applyPreset(engine, [4, 2, 0, 2, 4])),
                const SizedBox(width: 8),
                _PresetChip(label: 'Bass', onTap: () => _applyPreset(engine, [6, 3, 0, -2, -4])),
                const SizedBox(width: 8),
                _PresetChip(label: 'Vocal', onTap: () => _applyPreset(engine, [-2, 0, 4, 2, 0])),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Equalizer Bands
          SizedBox(
            height: 200,
            child: Consumer<RadioEngine>(
              builder: (context, eng, _) => Row(
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
                            data: SliderThemeData(
                              trackHeight: 4,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                              thumbColor: _kRed,
                              activeTrackColor: _kRed,
                              inactiveTrackColor: Colors.white10,
                            ),
                            child: Slider(
                              value: eng.equalizerBands[i],
                              min: -10,
                              max: 10,
                              onChanged: (v) => eng.updateEqualizerBand(i, v),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(label,
                          style: const TextStyle(color: Colors.white38, fontSize: 10)),
                      Text('${eng.equalizerBands[i].toInt()}dB',
                          style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Loudness Enhancer
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('LOUDNESS ENHANCER',
                style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          ),
          const SizedBox(height: 8),
          Consumer<RadioEngine>(
            builder: (context, eng, _) => Row(
              children: [
                const Icon(Icons.volume_mute, color: Colors.white38, size: 20),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                      thumbColor: _kWhite,
                      activeTrackColor: _kWhite,
                      inactiveTrackColor: Colors.white10,
                    ),
                    child: Slider(
                      value: eng.loudnessGain,
                      min: 0,
                      max: 1,
                      onChanged: eng.setLoudnessGain,
                    ),
                  ),
                ),
                const Icon(Icons.volume_up, color: Colors.white38, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('DONE',
                style: TextStyle(color: _kRed, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          ),
        ],
      ),
    );
  }

  void _applyPreset(RadioEngine engine, List<double> values) {
    for (int i = 0; i < values.length && i < engine.equalizerBands.length; i++) {
      engine.updateEqualizerBand(i, values[i]);
    }
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PresetChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFE53935).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: const Color(0xFFE53935).withValues(alpha: 0.5)),
        ),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// ─── Recording Bottom Sheet ──────────────────────────────────────
class _RecordingSheet extends StatelessWidget {
  final RadioEngine engine;
  const _RecordingSheet({required this.engine});

  @override
  Widget build(BuildContext context) {
    return Consumer<RadioEngine>(
      builder: (context, eng, _) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF141414),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text('STREAM RECORDING',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2)),
            const SizedBox(height: 28),
            if (eng.isRecording)
              _buildActiveRecordingUI(eng)
            else
              _buildInactiveRecordingUI(context, eng),
            const SizedBox(height: 24),
            if (eng.savedRecordings.isNotEmpty && !eng.isRecording) ...[
              const Divider(color: Colors.white10),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('RECENT RECORDINGS',
                    style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 150,
                child: ListView.builder(
                  itemCount: math.min(eng.savedRecordings.length, 3),
                  itemBuilder: (context, i) {
                    final path = eng.savedRecordings[eng.savedRecordings.length - 1 - i];
                    final name = path.split('/').last;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.audiotrack_rounded, color: Colors.white38),
                      title: Text(name, style: const TextStyle(color: Colors.white70, fontSize: 13), overflow: TextOverflow.ellipsis),
                      trailing: IconButton(
                        icon: const Icon(Icons.play_circle_fill_rounded, color: _kRed),
                        onPressed: () {
                          // Play recording logic could go here
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white10),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('CANCEL'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (eng.isRecording) {
                        eng.stopRecording();
                      } else {
                        eng.startRecording();
                      }
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: eng.isRecording ? Colors.white : _kRed,
                      foregroundColor: eng.isRecording ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text(eng.isRecording ? 'STOP' : 'START'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveRecordingUI(RadioEngine eng) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                value: null,
                strokeWidth: 2,
                color: _kRed.withValues(alpha: 0.3),
              ),
            ),
            const Icon(Icons.mic_rounded, color: _kRed, size: 32),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          _fmtDuration(eng.recordingDuration),
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
        ),
        const Text('RECORDING...', style: TextStyle(color: _kRed, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
      ],
    );
  }

  Widget _buildInactiveRecordingUI(BuildContext context, RadioEngine eng) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.fiber_manual_record_rounded, color: Colors.white24, size: 40),
        ),
        const SizedBox(height: 16),
        const Text('Ready to Record', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          'Capture high-quality audio from ${eng.currentStation?.name ?? "this station"}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ],
    );
  }

  String _fmtDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h == '00' ? '$m:$s' : '$h:$m:$s';
  }
}

// ─── Sleep Timer Bottom Sheet ────────────────────────────────────
class _SleepTimerSheet extends StatelessWidget {
  final RadioEngine engine;
  const _SleepTimerSheet({required this.engine});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF141414),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text('SLEEP TIMER',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3)),
          const SizedBox(height: 24),
          if (engine.isSleepTimerActive)
            Column(
              children: [
                Text(
                  _fmtDuration(engine.sleepRemainingTime),
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                ),
                const Text('REMAINING', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    engine.cancelSleepTimer();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kRed,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('CANCEL TIMER', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                _TimerOption(label: '15m', minutes: 15, engine: engine),
                _TimerOption(label: '30m', minutes: 30, engine: engine),
                _TimerOption(label: '45m', minutes: 45, engine: engine),
                _TimerOption(label: '1h', minutes: 60, engine: engine),
                _TimerOption(label: '2h', minutes: 120, engine: engine),
                _TimerOption(label: 'Custom', minutes: 0, engine: engine, isCustom: true),
              ],
            ),
          const SizedBox(height: 24),
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

class _TimerOption extends StatelessWidget {
  final String label;
  final int minutes;
  final RadioEngine engine;
  final bool isCustom;

  const _TimerOption({required this.label, required this.minutes, required this.engine, this.isCustom = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        if (isCustom) {
          // Could show a picker
          engine.startSleepTimer(const Duration(minutes: 90));
        } else {
          engine.startSleepTimer(Duration(minutes: minutes));
        }
        Navigator.pop(context);
      },
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Center(
          child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      ),
    );
  }
}
