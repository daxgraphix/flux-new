import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../flux_engine/radio_engine.dart';
import '../../flux_hardware/radio_service.dart';

// ─── Color System ────────────────────────────────────────────────
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
    super.dispose();
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
          body: SafeArea(
            child: Column(
              children: [
                _buildTopBar(context),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          _buildArtwork(station, engine),
                          const SizedBox(height: 28),
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
                ),
              ],
            ),
          ),
        );
      },
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
            icon: const Icon(Icons.more_vert_rounded, color: _kWhite, size: 24),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildArtwork(RadioStation station, RadioEngine engine) {
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
                  width: 220 * _pulseAnim.value + 20,
                  height: 220 * _pulseAnim.value + 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _kRed.withValues(alpha: 0.15 * _pulseAnim.value),
                      width: 2,
                    ),
                  ),
                ),
              if (engine.isPlaying)
                Container(
                  width: 220 * _pulseAnim.value + 8,
                  height: 220 * _pulseAnim.value + 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _kRed.withValues(alpha: 0.30 * _pulseAnim.value),
                      width: 2,
                    ),
                  ),
                ),
              // Main artwork circle
              Container(
                width: 220,
                height: 220,
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
                  child: station.favicon.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: station.favicon,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => _buildFallbackArtwork(),
                          errorWidget: (context, url, error) => _buildFallbackArtwork(),
                        )
                      : _buildFallbackArtwork(),
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
    final duration = engine.duration ?? Duration.zero;
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
              engine.currentStation?.name ?? ''),
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

  static const _bands = ['60Hz', '170Hz', '310Hz', '4kHz', '16kHz'];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF141414),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text('EQUALIZER',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PresetChip(
                  label: 'Flat',
                  onTap: () => engine.resetEqualizer()),
              const SizedBox(width: 8),
              _PresetChip(
                  label: 'Pop',
                  onTap: () {
                    for (int i = 0; i < 5; i++) {
                      engine.updateEqualizerBand(i,
                          [2.0, 1.0, 0.0, -1.0, -2.0][i]);
                    }
                  }),
              const SizedBox(width: 8),
              _PresetChip(
                  label: 'Rock',
                  onTap: () {
                    for (int i = 0; i < 5; i++) {
                      engine.updateEqualizerBand(i,
                          [-2.0, -1.0, 0.0, 1.0, 2.0][i]);
                    }
                  }),
              const SizedBox(width: 8),
              _PresetChip(
                  label: 'Bass+',
                  onTap: () {
                    for (int i = 0; i < 5; i++) {
                      engine.updateEqualizerBand(
                          i, [4.0, 3.0, 0.0, -1.0, -2.0][i]);
                    }
                  }),
            ],
          ),
          const SizedBox(height: 16),
          Consumer<RadioEngine>(
            builder: (context, eng, _) => Column(
              children: List.generate(5, (i) {
                return Row(
                  children: [
                    SizedBox(
                        width: 50,
                        child: Text(_bands[i],
                            style: const TextStyle(
                                color: Color(0xFF9E9E9E), fontSize: 11))),
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          thumbColor: const Color(0xFFE53935),
                          activeTrackColor: const Color(0xFFE53935),
                          inactiveTrackColor: const Color(0xFF2A2A2A),
                        ),
                        child: Slider(
                          value: eng.equalizerBands[i],
                          min: -10,
                          max: 10,
                          onChanged: (v) =>
                              eng.updateEqualizerBand(i, v),
                        ),
                      ),
                    ),
                    SizedBox(
                        width: 40,
                        child: Text(
                            eng.equalizerBands[i].toStringAsFixed(1),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 11),
                            textAlign: TextAlign.right)),
                  ],
                );
              }),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close',
                style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text('RECORDING',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2)),
            const SizedBox(height: 20),
            if (eng.isRecording)
              Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFE53935).withValues(alpha: 0.15),
                      border: Border.all(color: const Color(0xFFE53935), width: 2),
                    ),
                    child: const Icon(Icons.mic_rounded,
                        color: Color(0xFFE53935), size: 32),
                  ),
                  const SizedBox(height: 12),
                  const Text('Recording in progress...',
                      style: TextStyle(color: Colors.white70)),
                ],
              )
            else
              Column(
                children: [
                  const Icon(Icons.fiber_manual_record_rounded,
                      color: Color(0xFFE53935), size: 48),
                  const SizedBox(height: 8),
                  Text(
                    eng.savedRecordings.isEmpty
                        ? 'Start recording the current station'
                        : '${eng.savedRecordings.length} recording(s) saved',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close',
                      style: TextStyle(color: Colors.white70)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  onPressed: () {
                    if (eng.isRecording) {
                      eng.stopRecording();
                    } else {
                      eng.startRecording();
                    }
                    Navigator.pop(context);
                  },
                  child: Text(
                    eng.isRecording ? 'Stop' : 'Record',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}