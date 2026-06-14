import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../flux_engine/radio_engine.dart';
import '../flux_storage/radio_storage.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  TimeOfDay? _alarmTime;
  bool _alarmActive = false;
  Timer? _alarmTimer;

  // Additional settings
  bool _autoPlay = true;
  bool _highQuality = false;
  bool _notificationsEnabled = true;
  bool _dataSaver = false;
  String _language = 'en';
  int _cacheSize = 100; // MB

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _alarmTimer?.cancel();
    _saveSettings();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoPlay = prefs.getBool('auto_play') ?? true;
      _highQuality = prefs.getBool('high_quality') ?? false;
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _dataSaver = prefs.getBool('data_saver') ?? false;
      _language = prefs.getString('language') ?? 'en';
      _cacheSize = prefs.getInt('cache_size') ?? 100;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_play', _autoPlay);
    await prefs.setBool('high_quality', _highQuality);
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setBool('data_saver', _dataSaver);
    await prefs.setString('language', _language);
    await prefs.setInt('cache_size', _cacheSize);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final engine = Provider.of<RadioEngine>(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF0A0A0A), const Color(0xFF1A1A2E)]
                : [const Color(0xFFF5F7FA), const Color(0xFFB8C6DB)],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            physics: const BouncingScrollPhysics(),
            children: [
              _buildModernSection(
                context,
                'AUDIO ENGINE',
                [
                  _buildModernSwitchTile(
                    icon: Icons.high_quality_rounded,
                    title: 'High Quality Audio',
                    subtitle: 'Prioritize high bitrate streams',
                    value: engine.highQuality,
                    onChanged: (v) => engine.setHighQuality(v),
                    activeColor: Colors.redAccent,
                  ),
                  _buildModernTile(
                    icon: Icons.volume_up_rounded,
                    title: 'Playback Volume',
                    subtitle: '${(engine.volume * 100).round()}%',
                    onTap: () => _showVolumeDialog(context, engine),
                  ),
                  _buildModernTile(
                    icon: Icons.equalizer_rounded,
                    title: 'Equalizer & Effects',
                    subtitle: 'Customize your sound',
                    onTap: () => _showEqualizerDialog(context, engine),
                  ),
                ],
              ),
              _buildModernSection(
                context,
                'PLAYBACK & RECORDING',
                [
                  _buildModernSwitchTile(
                    icon: Icons.play_circle_filled_rounded,
                    title: 'Auto-play on Start',
                    subtitle: 'Resume last station automatically',
                    value: engine.autoPlay,
                    onChanged: (v) => engine.setAutoPlay(v),
                  ),
                  _buildModernTile(
                    icon: Icons.mic_rounded,
                    title: 'Live Recording',
                    subtitle: engine.isRecording ? 'Recording active...' : 'Manage your recordings',
                    onTap: () => _showRecordingDialog(context, engine),
                    trailing: engine.isRecording ? _buildLiveIndicator() : null,
                  ),
                  _buildModernTile(
                    icon: Icons.history_rounded,
                    title: 'Recently Played',
                    subtitle: 'View listening history',
                    onTap: () {
                      // Handle navigation to library or history
                    },
                  ),
                ],
              ),
              _buildModernSection(
                context,
                'TIMERS',
                [
                  _buildModernTile(
                    icon: Icons.bedtime_rounded,
                    title: 'Sleep Timer',
                    subtitle: engine.isSleepTimerActive
                        ? 'Stopping in ${engine.sleepRemainingTime.inMinutes}m ${engine.sleepRemainingTime.inSeconds % 60}s'
                        : 'Set auto-off timer',
                    onTap: () => _showSleepTimerDialog(context, engine),
                    trailing: engine.isSleepTimerActive ? const Icon(Icons.timer_rounded, color: Colors.redAccent, size: 20) : null,
                  ),
                  _buildModernTile(
                    icon: Icons.alarm_rounded,
                    title: 'Radio Alarm',
                    subtitle: _alarmActive && _alarmTime != null
                        ? 'Set for ${_alarmTime!.format(context)}'
                        : 'Wake up with music',
                    onTap: () => _showAlarmDialog(context),
                  ),
                ],
              ),
              _buildModernSection(
                context,
                'DATA & STORAGE',
                [
                  _buildModernSwitchTile(
                    icon: Icons.data_usage_rounded,
                    title: 'Data Saver Mode',
                    subtitle: 'Reduce bandwidth usage',
                    value: engine.dataSaver,
                    onChanged: (v) => engine.setDataSaver(v),
                  ),
                  _buildModernTile(
                    icon: Icons.storage_rounded,
                    title: 'Cache Management',
                    subtitle: 'Current limit: ${_cacheSize}MB',
                    onTap: () => _showCacheDialog(context),
                  ),
                  _buildModernTile(
                    icon: Icons.delete_sweep_rounded,
                    title: 'Clear All Cache',
                    subtitle: 'Reset temporary data',
                    onTap: () {
                      engine.clearCache();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cache cleared')));
                    },
                  ),
                ],
              ),
              _buildModernSection(
                context,
                'APPLICATION',
                [
                  _buildModernTile(
                    icon: Icons.language_rounded,
                    title: 'Display Language',
                    subtitle: _getLanguageName(_language),
                    onTap: () => _showLanguageDialog(context),
                  ),
                  _buildModernTile(
                    icon: Icons.info_outline_rounded,
                    title: 'About Flux',
                    subtitle: 'Version 1.1.0',
                    onTap: () => showAboutDialog(
                      context: context,
                      applicationName: 'Flux Radio',
                      applicationVersion: '1.1.0',
                      applicationIcon: const Icon(Icons.radio, color: Colors.red, size: 40),
                      applicationLegalese: '© 2024 Flux Audio Labs',
                    ),
                  ),
                  _buildModernTile(
                    icon: Icons.backup_rounded,
                    title: 'Export Data',
                    subtitle: 'Backup favorites & history',
                    onTap: () => _exportDatabase(context),
                  ),
                  _buildModernTile(
                    icon: Icons.restore_rounded,
                    title: 'Reset to Factory Settings',
                    subtitle: 'Warning: This cannot be undone',
                    onTap: () => _showResetDialog(context),
                    textColor: Colors.redAccent,
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernSection(BuildContext context, String title, List<Widget> children) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            title,
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.black54,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildModernTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
    Color? textColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.redAccent, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? (isDark ? Colors.white : Colors.black87),
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: isDark ? Colors.white38 : Colors.black38,
          fontSize: 13,
        ),
      ),
      trailing: trailing ?? Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white24 : Colors.grey.withValues(alpha: 0.5)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildModernSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    Color activeColor = Colors.redAccent,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SwitchListTile(
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: activeColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: activeColor, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: isDark ? Colors.white38 : Colors.black38,
          fontSize: 13,
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeThumbColor: activeColor,
      activeTrackColor: activeColor.withValues(alpha: 0.5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildLiveIndicator() {
    return Container(
      width: 12,
      height: 12,
      decoration: const BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.red, blurRadius: 4, spreadRadius: 1)],
      ),
    );
  }

  void _showVolumeDialog(BuildContext context, RadioEngine engine) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text(
          'Volume Control',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.volume_down, color: Colors.white70),
                Expanded(
                  child: Slider(
                    value: engine.volume,
                    min: 0.0,
                    max: 1.0,
                    onChanged: engine.setVolume,
                    activeColor: Colors.red,
                    inactiveColor: Colors.white24,
                  ),
                ),
                const Icon(Icons.volume_up, color: Colors.white70),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Volume: ${(engine.volume * 100).round()}%',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSleepTimerDialog(BuildContext context, RadioEngine engine) {
    int minutes = 30;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text(
          'Sleep Timer',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Set timer to stop playback:',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [15, 30, 60, 120].map((preset) {
                return ElevatedButton(
                  onPressed: () {
                    minutes = preset;
                  },
                  child: Text('${preset}m'),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Custom minutes',
                labelStyle: TextStyle(color: Colors.red),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.red),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.red),
                ),
              ),
              onChanged: (value) => minutes = int.tryParse(value) ?? 30,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          if (engine.isSleepTimerActive)
            TextButton(
              onPressed: () {
                engine.cancelSleepTimer();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sleep timer cancelled')),
                );
              },
              child: const Text('Cancel Timer', style: TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () {
              engine.startSleepTimer(Duration(minutes: minutes));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Sleep timer set for $minutes minutes')),
              );
            },
            child: const Text('Start', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAlarmDialog(BuildContext context) {
    TimeOfDay? selectedTime;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text(
          'Set Alarm',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select time to wake up with radio:',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (time != null) {
                  selectedTime = time;
                }
              },
              child: const Text('Pick Time'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              if (selectedTime != null) {
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);
                _alarmTimer?.cancel();
                final now = DateTime.now();
                final alarmDateTime = DateTime(
                  now.year,
                  now.month,
                  now.day,
                  selectedTime!.hour,
                  selectedTime!.minute,
                );
                final duration = alarmDateTime.isAfter(now)
                    ? alarmDateTime.difference(now)
                    : alarmDateTime.add(const Duration(days: 1)).difference(now);
                _alarmTimer = Timer(duration, () {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Alarm! Playing radio'),
                      backgroundColor: Colors.red,
                    ),
                  );
                });
                setState(() {
                  _alarmActive = true;
                  _alarmTime = selectedTime;
                });
                messenger.showSnackBar(
                  SnackBar(content: Text('Alarm set for ${selectedTime!.format(context)}')),
                );
                navigator.pop();
              }
            },
            child: const Text('Set', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showEqualizerDialog(BuildContext context, RadioEngine engine) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text(
          'Equalizer',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    engine.resetEqualizer();
                  },
                  child: const Text('Flat'),
                ),
                ElevatedButton(
                  onPressed: () {
                    engine.updateEqualizerBand(0, 2.0);
                    engine.updateEqualizerBand(1, 1.0);
                    engine.updateEqualizerBand(2, 0.0);
                    engine.updateEqualizerBand(3, -1.0);
                    engine.updateEqualizerBand(4, -2.0);
                  },
                  child: const Text('Pop'),
                ),
                ElevatedButton(
                  onPressed: () {
                    engine.updateEqualizerBand(0, -2.0);
                    engine.updateEqualizerBand(1, -1.0);
                    engine.updateEqualizerBand(2, 0.0);
                    engine.updateEqualizerBand(3, 1.0);
                    engine.updateEqualizerBand(4, 2.0);
                  },
                  child: const Text('Rock'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Bass Boost', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('60Hz', style: TextStyle(color: Colors.grey, fontSize: 12)),
                Expanded(
                  child: Slider(
                    value: engine.equalizerBands[0],
                    min: -10,
                    max: 10,
                    onChanged: (value) => engine.updateEqualizerBand(0, value),
                    activeColor: Colors.red,
                    inactiveColor: Colors.white24,
                  ),
                ),
                const Text('10kHz', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('170Hz', style: TextStyle(color: Colors.grey, fontSize: 12)),
                Expanded(
                  child: Slider(
                    value: engine.equalizerBands[1],
                    min: -10,
                    max: 10,
                    onChanged: (value) => engine.updateEqualizerBand(1, value),
                    activeColor: Colors.red,
                    inactiveColor: Colors.white24,
                  ),
                ),
                const Text('4kHz', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('31Hz', style: TextStyle(color: Colors.grey, fontSize: 12)),
                Expanded(
                  child: Slider(
                    value: engine.equalizerBands[2],
                    min: -10,
                    max: 10,
                    onChanged: (value) => engine.updateEqualizerBand(2, value),
                    activeColor: Colors.red,
                    inactiveColor: Colors.white24,
                  ),
                ),
                const Text('8kHz', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('60Hz', style: TextStyle(color: Colors.grey, fontSize: 12)),
                Expanded(
                  child: Slider(
                    value: engine.equalizerBands[3],
                    min: -10,
                    max: 10,
                    onChanged: (value) => engine.updateEqualizerBand(3, value),
                    activeColor: Colors.red,
                    inactiveColor: Colors.white24,
                  ),
                ),
                const Text('12kHz', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('170Hz', style: TextStyle(color: Colors.grey, fontSize: 12)),
                Expanded(
                  child: Slider(
                    value: engine.equalizerBands[4],
                    min: -10,
                    max: 10,
                    onChanged: (value) => engine.updateEqualizerBand(4, value),
                    activeColor: Colors.red,
                    inactiveColor: Colors.white24,
                  ),
                ),
                const Text('16kHz', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRecordingDialog(BuildContext context, RadioEngine engine) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text(
          'Recording',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (engine.isRecording)
              const Column(
                children: [
                  CircularProgressIndicator(color: Colors.red),
                  SizedBox(height: 8),
                  Text(
                    'Recording in progress...',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              )
            else if (engine.savedRecordings.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Saved Recordings:',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...engine.savedRecordings.take(3).map((path) => ListTile(
                    leading: const Icon(Icons.audio_file, color: Colors.red),
                    title: Text(
                      File(path).uri.pathSegments.isNotEmpty 
                          ? File(path).uri.pathSegments.last 
                          : 'Recording',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.play_arrow, color: Colors.red),
                      onPressed: () {
                        Navigator.pop(context);
                        engine.playRecording(path);
                      },
                    ),
                  )),
                ],
              ),
            if (engine.savedRecordings.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No recordings yet', style: TextStyle(color: Colors.grey)),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              if (engine.isRecording) {
                engine.stopRecording();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Recording stopped')),
                );
                navigator.pop();
              } else {
                if (engine.currentStation == null) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('No station playing')),
                  );
                  return;
                }
                engine.startRecording();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Recording started')),
                );
                navigator.pop();
              }
            },
            child: Text(
              engine.isRecording ? 'Stop' : 'Start',
              style: TextStyle(color: engine.isRecording ? Colors.red : Colors.white),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  String _getLanguageName(String code) {
    switch (code) {
      case 'en': return 'English';
      case 'es': return 'Español';
      case 'fr': return 'Français';
      case 'de': return 'Deutsch';
      case 'it': return 'Italiano';
      case 'pt': return 'Português';
      case 'ru': return 'Русский';
      case 'ja': return '日本語';
      case 'ko': return '한국어';
      case 'zh': return '中文';
      default: return 'English';
    }
  }

  void _showCacheDialog(BuildContext context) {
    int tempCacheSize = _cacheSize;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Cache Size', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Set maximum cache size (MB):',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Slider(
              value: tempCacheSize.toDouble(),
              min: 50,
              max: 500,
              divisions: 9,
              label: '${tempCacheSize}MB',
              onChanged: (value) => setState(() => tempCacheSize = value.round()),
              activeColor: Colors.red,
              inactiveColor: Colors.white24,
            ),
            Text(
              '${tempCacheSize}MB',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              setState(() => _cacheSize = tempCacheSize);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cache size updated')),
              );
            },
            child: const Text('Save', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    final languages = {
      'en': 'English',
      'es': 'Español',
      'fr': 'Français',
      'de': 'Deutsch',
      'it': 'Italiano',
      'pt': 'Português',
      'ru': 'Русский',
      'ja': '日本語',
      'ko': '한국어',
      'zh': '中文',
    };

    String selectedLanguage = _language;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text('Select Language', style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: languages.entries.map((entry) {
                return RadioMenuButton<String>(
                  value: entry.key,
                  groupValue: selectedLanguage,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedLanguage = value);
                    }
                  },
                  child: Text(entry.value, style: const TextStyle(color: Colors.white)),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                this.setState(() => _language = selectedLanguage);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Language set to ${languages[selectedLanguage]}')),
                );
              },
              child: const Text('Save', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Reset Settings', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to reset all settings to their default values?',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (!mounted) return;
              setState(() {
                _autoPlay = true;
                _highQuality = false;
                _notificationsEnabled = true;
                _dataSaver = false;
                _language = 'en';
                _cacheSize = 100;
              });
              Navigator.pop(this.context);
              ScaffoldMessenger.of(this.context).showSnackBar(
                const SnackBar(content: Text('Settings reset to defaults')),
              );
            },
            child: const Text('Reset', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _exportDatabase(BuildContext context) async {
    try {
      final storage = RadioStorage();
      final data = await storage.exportDatabase();
      final jsonString = jsonEncode(data);

      if (!context.mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text('Database Export', style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: SelectableText(
                      jsonString,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close', style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: jsonString));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              },
              child: const Text('Copy', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }
}
