import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter_shaders/flutter_shaders.dart';
import '../../flux_engine/radio_engine.dart';
import '../../flux_hardware/radio_service.dart';
import 'widgets/flux_image.dart';

const _kBlack = Color(0xFF0A0A0A);
const _kCard = Color(0xFF1C1C1C);
const _kRed = Color(0xFFE53935);
const _kWhite = Colors.white;
const _kGrey = Color(0xFF9E9E9E);

extension RadioStationX on RadioStation {
  double get frequency {
    int hash = name.hashCode.abs();
    return 87.5 + (hash % 205) / 10.0;
  }
}

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
            body: Center(child: Text('No station playing', style: TextStyle(color: _kWhite))),
          );
        }

        return Scaffold(
          backgroundColor: _kBlack,
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
                child: Stack(
                  children: [
                    _buildBackground(station),
                    Center(
                      child: SizedBox(
                        width: contentWidth,
                        child: SafeArea(
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
                                      const SizedBox(height: 16),
                                      _buildSpectrumVisualizer(station, engine),
                                      const SizedBox(height: 20),
                                      _buildProgressBar(engine),
                                      const SizedBox(height: 24),
                                      _buildMainControls(engine),
                                      const SizedBox(height: 24),
                                      _buildSecondaryControls(engine),
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
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: _kRed.withValues(alpha: 0.5)),
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
        opacity: 0.1,
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _kWhite, size: 36),
            onPressed: () => Navigator.pop(context),
          ),
          Column(
            children: [
              Text(
                'FLUX RADIO',
                style: TextStyle(color: _kRed.withValues(alpha: 0.8), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 4),
              ),
              const Text(
                'NOW PLAYING',
                style: TextStyle(color: _kWhite, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1.5),
              ),
            ],
          ),
          IconButton(
            icon: Icon(_isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded, color: _kWhite, size: 28),
            onPressed: _toggleFullscreen,
          ),
        ],
      ),
    );
  }

  Widget _buildArtwork(RadioStation station, RadioEngine engine) {
    final size = _isFullscreen ? 300.0 : 260.0;
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
                gradient: const RadialGradient(
                  colors: [Color(0xFF2A2A2A), _kBlack],
                  stops: [0.85, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _kRed.withValues(alpha: engine.isPlaying ? 0.25 : 0.05),
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
                        border: Border.all(color: _kRed.withValues(alpha: 0.3), width: 1.5),
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
                    // Vinyl reflection
                    Center(
                      child: Container(
                        width: size * 0.2,
                        height: size * 0.2,
                        decoration: BoxDecoration(
                          color: _kBlack.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                          border: Border.all(color: _kWhite.withValues(alpha: 0.1), width: 1),
                        ),
                        child: const Center(
                          child: Icon(Icons.radio_rounded, color: _kRed, size: 20),
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

  Widget _buildFallbackArtwork() {
    return Container(color: _kCard, child: const Icon(Icons.radio_rounded, color: _kRed, size: 80));
  }

  Widget _buildStationInfo(RadioStation station, RadioEngine engine) {
    return Column(
      children: [
        Text(
          station.name,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _kWhite, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 0.5),
        ),
        const SizedBox(height: 4),
        Text(
          [station.country, station.genre].where((s) => s.isNotEmpty).join(' • ').toUpperCase(),
          style: const TextStyle(color: _kGrey, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.2),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        _buildLiveBadge(engine),
      ],
    );
  }

  Widget _buildLiveBadge(RadioEngine engine) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final isPlaying = engine.isPlaying;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: isPlaying ? _kRed.withValues(alpha: 0.1) : _kGrey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: (isPlaying ? _kRed : _kGrey).withValues(alpha: 0.5), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isPlaying ? _kRed : _kGrey,
                  boxShadow: isPlaying ? [BoxShadow(color: _kRed.withValues(alpha: 0.6), blurRadius: 6)] : null,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isPlaying ? 'LIVE STREAM' : 'PAUSED',
                style: TextStyle(color: isPlaying ? _kRed : _kGrey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2),
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

  Widget _buildProgressBar(RadioEngine engine) {
    final position = engine.position;
    final duration = engine.duration;
    final isLive = duration == Duration.zero;

    if (isLive) {
      return Container(
        height: 4,
        width: double.infinity,
        decoration: BoxDecoration(color: const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(2)),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: engine.isPlaying ? 1.0 : 0.0,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_kRed, Color(0xFFFF5252)]),
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
            thumbColor: _kRed,
            activeTrackColor: _kRed,
            inactiveTrackColor: const Color(0xFF2A2A2A),
            overlayColor: _kRed.withValues(alpha: 0.2),
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
              Text(_fmt(position), style: const TextStyle(color: _kGrey, fontSize: 12, fontWeight: FontWeight.w500)),
              Text(_fmt(duration), style: const TextStyle(color: _kGrey, fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMainControls(RadioEngine engine) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ControlBtn(
          icon: Icons.skip_previous_rounded,
          size: 36,
          color: Colors.white70,
          onTap: () => engine.skipPrevious(),
        ),
        const SizedBox(width: 32),
        GestureDetector(
          onTap: () {
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
              color: _kRed,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: _kRed.withValues(alpha: 0.4), blurRadius: 30, offset: const Offset(0, 8)),
              ],
            ),
            child: Icon(
              engine.isLoading
                  ? Icons.hourglass_top_rounded
                  : (engine.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
              color: _kWhite,
              size: 42,
            ),
          ),
        ),
        const SizedBox(width: 32),
        _ControlBtn(
          icon: Icons.skip_next_rounded,
          size: 36,
          color: Colors.white70,
          onTap: () => engine.skipNext(),
        ),
      ],
    );
  }

  Widget _buildSecondaryControls(RadioEngine engine) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: _kCard.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildFavBtn(engine),
          _buildRecordBtn(engine),
          _buildTimerBtn(engine),
          _buildEqBtn(engine),
          _buildShareBtn(engine),
        ],
      ),
    );
  }

  Widget _buildFavBtn(RadioEngine engine) {
    final station = engine.currentStation;
    if (station == null) return const SizedBox.shrink();
    
    return FutureBuilder<bool>(
      future: engine.isFavorite(station.url, uuid: station.uuid),
      builder: (context, snap) {
        final isFav = snap.data == true;
        return IconButton(
          icon: Icon(isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: isFav ? _kRed : Colors.white70),
          onPressed: () async {
            await engine.toggleFavorite(station);
            setState(() {});
          },
        );
      },
    );
  }

  Widget _buildRecordBtn(RadioEngine engine) {
    return IconButton(
      icon: Icon(engine.isRecording ? Icons.stop_circle_rounded : Icons.fiber_manual_record_rounded, color: engine.isRecording ? _kRed : Colors.white70),
      onPressed: () => _showRecordingSheet(engine),
    );
  }

  Widget _buildTimerBtn(RadioEngine engine) {
    return IconButton(
      icon: Icon(engine.isSleepTimerActive ? Icons.timer_rounded : Icons.timer_outlined, color: engine.isSleepTimerActive ? _kRed : Colors.white70),
      onPressed: () => _showSleepTimerSheet(engine),
    );
  }

  Widget _buildEqBtn(RadioEngine engine) {
    return IconButton(
      icon: const Icon(Icons.equalizer_rounded, color: Colors.white70),
      onPressed: () => _showEqualizerSheet(engine),
    );
  }

  Widget _buildShareBtn(RadioEngine engine) {
    return IconButton(
      icon: const Icon(Icons.share_rounded, color: Colors.white70),
      onPressed: () {
        final station = engine.currentStation;
        if (station != null) {
          Share.share('Listening to ${station.name} on Flux Radio! 📻\n${station.url}');
        }
      },
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
      isScrollControlled: true,
      builder: (context) {
        final isWide = MediaQuery.of(context).size.width > 600;
        return Center(
          child: SizedBox(
            width: isWide ? 500 : double.infinity,
            child: _SleepTimerSheet(engine: engine),
          ),
        );
      },
    );
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
            child: _EqualizerSheet(engine: engine),
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
            child: _RecordingSheet(engine: engine),
          ),
        );
      },
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
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
    return Container(
      decoration: const BoxDecoration(color: Color(0xFF141414), borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const Text('AUDIO EQUALIZER', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 3)),
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
                _PresetChip(label: 'Bass Boost', onTap: () => _applyPreset(engine, [8, 5, 0, -1, -2])),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Consumer<RadioEngine>(
            builder: (context, eng, _) => Column(
              children: [
                SizedBox(
                  height: 200,
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
                                  trackHeight: 4,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                ),
                                child: Slider(
                                  value: eng.equalizerBands[i],
                                  min: -15,
                                  max: 15,
                                  onChanged: (v) => eng.updateEqualizerBand(i, v),
                                  activeColor: _kRed,
                                  inactiveColor: Colors.white10,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                          Text('${eng.equalizerBands[i].toInt()}dB', style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Icon(Icons.volume_up, color: Colors.white38, size: 16),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('LOUDNESS ENHANCER', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                    Text('${(eng.loudnessGain / 100).toStringAsFixed(1)}x', style: const TextStyle(color: _kRed, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                Slider(
                  value: eng.loudnessGain,
                  min: 0,
                  max: 1000,
                  divisions: 20,
                  onChanged: (v) => eng.setLoudnessGain(v),
                  activeColor: _kRed,
                  inactiveColor: Colors.white10,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('DONE', style: TextStyle(color: _kRed, fontWeight: FontWeight.bold, letterSpacing: 1.5))),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(color: _kRed.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: _kRed.withValues(alpha: 0.5))),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _RecordingSheet extends StatelessWidget {
  final RadioEngine engine;
  const _RecordingSheet({required this.engine});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      decoration: const BoxDecoration(color: Color(0xFF141414), borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const Text('STREAM RECORDING', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 2)),
          const SizedBox(height: 20),
          Consumer<RadioEngine>(
            builder: (context, eng, _) {
              if (eng.isRecording) {
                return Column(
                  children: [
                    const Icon(Icons.mic_rounded, color: _kRed, size: 48),
                    const SizedBox(height: 8),
                    Text(_fmtDuration(eng.recordingDuration), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    const Text('RECORDING...', style: TextStyle(color: _kRed, fontSize: 10, fontWeight: FontWeight.w900)),
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
                  return const Center(child: Text('No recordings found', style: TextStyle(color: Colors.white38)));
                }
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: eng.savedRecordings.length,
                  itemBuilder: (context, i) {
                    final path = eng.savedRecordings[eng.savedRecordings.length - 1 - i];
                    final name = path.split('/').last;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.audiotrack_rounded, color: Colors.white38),
                      title: Text(name, style: const TextStyle(color: Colors.white70, fontSize: 13), overflow: TextOverflow.ellipsis),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.share, color: Colors.white38, size: 20), onPressed: () => Share.shareXFiles([XFile(path)])),
                          IconButton(icon: const Icon(Icons.open_in_new, color: _kRed, size: 20), onPressed: () => OpenFilex.open(path)),
                          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.white24, size: 20), onPressed: () => eng.deleteRecording(path)),
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
                  style: ElevatedButton.styleFrom(backgroundColor: engine.isRecording ? Colors.white : _kRed, foregroundColor: engine.isRecording ? Colors.black : Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
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

class _SleepTimerSheet extends StatelessWidget {
  final RadioEngine engine;
  const _SleepTimerSheet({required this.engine});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Color(0xFF141414), borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const Text('SLEEP TIMER', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 3)),
          const SizedBox(height: 24),
          if (engine.isSleepTimerActive)
            Column(
              children: [
                Text(_fmtDuration(engine.sleepRemainingTime), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                ElevatedButton(onPressed: () => engine.cancelSleepTimer(), style: ElevatedButton.styleFrom(backgroundColor: _kRed), child: const Text('CANCEL TIMER')),
              ],
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [15, 30, 45, 60].map((m) => _TimerBtn(label: '${m}m', minutes: m, engine: engine)).toList(),
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

class _TimerBtn extends StatelessWidget {
  final String label;
  final int minutes;
  final RadioEngine engine;

  const _TimerBtn({required this.label, required this.minutes, required this.engine});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        engine.startSleepTimer(Duration(minutes: minutes));
        Navigator.pop(context);
      },
      child: Container(
        width: 70,
        height: 50,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
        child: Center(child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
      ),
    );
  }
}
