import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import '../flux_engine/radio_engine.dart';
import '../flux_engine/theme_provider.dart';
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF1A1A2E), const Color(0xFF0A0A0A)]
                : [const Color(0xFFE3F2FD), const Color(0xFFBBDEFB)],
          ),
        ),
        child: SafeArea(
          child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Audio Section
            _buildSectionCard(
              isDark,
              icon: Icons.audiotrack,
              title: 'Audio',
              children: [
                _buildSwitchTile(
                  isDark,
                  icon: Icons.high_quality,
                  title: 'High Quality Audio',
                  subtitle: 'Use higher bitrate streams (uses more data)',
                  value: _highQuality,
                  onChanged: (value) => setState(() => _highQuality = value),
                ),
                Consumer<RadioEngine>(
                  builder: (context, engine, _) => _buildTile(
                    isDark,
                    icon: Icons.volume_up,
                    title: 'Volume',
                    subtitle: 'Current: ${(engine.volume * 100).round()}%',
                    onTap: () => _showVolumeDialog(context, engine),
                  ),
                ),
                Consumer<RadioEngine>(
                  builder: (context, engine, _) => _buildTile(
                    isDark,
                    icon: Icons.equalizer,
                    title: 'Equalizer',
                    subtitle: 'Tone controls and presets',
                    onTap: () => _showEqualizerDialog(context, engine),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Playback Section
            _buildSectionCard(
              isDark,
              icon: Icons.play_arrow,
              title: 'Playback',
              children: [
                _buildSwitchTile(
                  isDark,
                  icon: Icons.play_circle,
                  title: 'Auto-play',
                  subtitle: 'Automatically play last station on app start',
                  value: _autoPlay,
                  onChanged: (value) => setState(() => _autoPlay = value),
                ),
                _buildTile(
                  isDark,
                  icon: Icons.stop,
                  title: 'Stop Playback',
                  subtitle: 'Stop current station immediately',
                  onTap: () {
                    final engine = Provider.of<RadioEngine>(context, listen: false);
                    engine.stop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Playback stopped')),
                    );
                  },
                ),
                Consumer<RadioEngine>(
                  builder: (context, engine, _) => _buildTile(
                    isDark,
                    icon: Icons.mic,
                    title: 'Recording',
                    subtitle: engine.isRecording
                        ? 'Recording in progress...'
                        : 'Record live radio',
                    onTap: () => _showRecordingDialog(context, engine),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Timer & Alarm Section
            _buildSectionCard(
              isDark,
              icon: Icons.timer,
              title: 'Timers & Alarms',
              children: [
                Consumer<RadioEngine>(
                  builder: (context, engine, _) => _buildTile(
                    isDark,
                    icon: Icons.bedtime,
                    title: 'Sleep Timer',
                    subtitle: engine.isSleepTimerActive
                        ? 'Active: ${engine.sleepDuration.inMinutes} minutes'
                        : 'Set auto-off timer',
                    onTap: () => _showSleepTimerDialog(context, engine),
                  ),
                ),
                _buildTile(
                  isDark,
                  icon: Icons.alarm,
                  title: 'Set Alarm',
                  subtitle: _alarmActive && _alarmTime != null
                      ? 'Alarm set for ${_alarmTime!.format(context)}'
                      : 'Wake up with your favorite station',
                  onTap: () => _showAlarmDialog(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Library Section
            _buildSectionCard(
              isDark,
              icon: Icons.library_music,
              title: 'Library',
              children: [
                _buildTile(
                  isDark,
                  icon: Icons.favorite,
                  title: 'Manage Favourites',
                  subtitle: 'View and remove saved stations',
                  onTap: () => _showFavouritesDialog(context),
                ),
                _buildTile(
                  isDark,
                  icon: Icons.location_on,
                  title: 'Nearby Discovery',
                  subtitle: 'Find live stations near you',
                  onTap: () {
                    final engine = Provider.of<RadioEngine>(context, listen: false);
                    engine.loadNearbyStations();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Searching nearby stations...')),
                    );
                  },
                ),
                Consumer<RadioEngine>(
                  builder: (context, engine, child) => _buildTile(
                    isDark,
                    icon: Icons.cleaning_services,
                    title: 'Clear Cache',
                    subtitle: 'Reset station results and cached data',
                    onTap: () {
                      engine.clearCache();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Cache cleared')),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Notifications & Data Section
            _buildSectionCard(
              isDark,
              icon: Icons.notifications,
              title: 'Notifications & Data',
              children: [
                _buildSwitchTile(
                  isDark,
                  icon: Icons.notifications,
                  title: 'Push Notifications',
                  subtitle: 'Receive notifications for new features',
                  value: _notificationsEnabled,
                  onChanged: (value) => setState(() => _notificationsEnabled = value),
                ),
                _buildSwitchTile(
                  isDark,
                  icon: Icons.data_usage,
                  title: 'Data Saver',
                  subtitle: 'Reduce data usage by limiting image quality',
                  value: _dataSaver,
                  onChanged: (value) => setState(() => _dataSaver = value),
                ),
                _buildTile(
                  isDark,
                  icon: Icons.storage,
                  title: 'Cache Size',
                  subtitle: 'Current: ${_cacheSize}MB',
                  onTap: () => _showCacheDialog(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // App Settings Section
            _buildSectionCard(
              isDark,
              icon: Icons.settings,
              title: 'App Settings',
              children: [
                Consumer<ThemeProvider>(
                  builder: (context, themeProvider, _) => _buildTile(
                    isDark,
                    icon: themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                    title: 'Theme',
                    subtitle: themeProvider.isDarkMode ? 'Dark Mode' : 'Light Mode',
                    onTap: themeProvider.toggleTheme,
                  ),
                ),
                _buildTile(
                  isDark,
                  icon: Icons.language,
                  title: 'Language',
                  subtitle: _getLanguageName(_language),
                  onTap: () => _showLanguageDialog(context),
                ),
                _buildTile(
                  isDark,
                  icon: Icons.info,
                  title: 'About',
                  subtitle: 'Flux Radio v1.0.0',
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'Flux Radio',
                      applicationVersion: '1.0.0',
                      applicationLegalese: 'Global AM/FM radio streaming app',
                    );
                  },
                ),
                _buildTile(
                  isDark,
                  icon: Icons.restore,
                  title: 'Reset to Defaults',
                  subtitle: 'Reset all settings to default values',
                  onTap: () => _showResetDialog(context),
                ),
                _buildTile(
                  isDark,
                  icon: Icons.storage,
                  title: 'Export Database',
                  subtitle: 'Export favorites and history as JSON',
                  onTap: () => _exportDatabase(context),
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(bool isDark, {
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: isDark ? Colors.red : Colors.blue, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchTile(bool isDark, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SwitchListTile(
        secondary: Icon(icon, color: isDark ? Colors.red : Colors.blue),
        title: Text(
          title,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: isDark ? Colors.grey : Colors.black.withValues(alpha: 0.6)),
        ),
        value: value,
        onChanged: onChanged,
        activeThumbColor: Colors.red,
      ),
    );
  }

  Widget _buildTile(bool isDark, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: isDark ? Colors.red : Colors.blue),
        title: Text(
          title,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: isDark ? Colors.grey : Colors.black.withValues(alpha: 0.6)),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: isDark ? Colors.grey : Colors.black.withValues(alpha: 0.4),
        ),
        onTap: onTap,
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
            // Presets
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    for (int i = 0; i < 5; i++) {
                      engine.updateEqualizerBand(i, 0.0);
                    }
                  },
                  child: const Text('Flat'),
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
              ],
            ),
            const SizedBox(height: 16),
            // Bands
            ...List.generate(5, (index) {
              return Row(
                children: [
                  Text(
                    'Band ${index + 1}',
                    style: const TextStyle(color: Colors.white),
                  ),
                  Expanded(
                    child: Slider(
                      value: engine.equalizerBands[index],
                      min: -10,
                      max: 10,
                      onChanged: (value) => engine.updateEqualizerBand(index, value),
                      activeColor: Colors.red,
                      inactiveColor: Colors.white24,
                    ),
                  ),
                  Text(
                    '${engine.equalizerBands[index].toStringAsFixed(1)}dB',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              );
            }),
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

  void _showFavouritesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text(
          'Manage Favourites',
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: FutureBuilder<List<FavoriteStation>>(
            future: RadioStorage().getFavorites(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.red));
              }
              if (snapshot.hasError || snapshot.data == null) {
                return const Text('Error loading favourites', style: TextStyle(color: Colors.white));
              }
              final favourites = snapshot.data!;
              if (favourites.isEmpty) {
                return const Text('No favourites', style: TextStyle(color: Colors.white));
              }
              return ListView.builder(
                shrinkWrap: true,
                itemCount: favourites.length,
                itemBuilder: (context, index) {
                  final fav = favourites[index];
                  return Card(
                    color: Colors.white.withValues(alpha: 0.05),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    child: ListTile(
                      leading: fav.favicon.isNotEmpty
                          ? CircleAvatar(backgroundImage: NetworkImage(fav.favicon))
                          : const CircleAvatar(
                              backgroundColor: Colors.red,
                              child: Icon(Icons.radio, color: Colors.white),
                            ),
                      title: Text(fav.name, style: const TextStyle(color: Colors.white)),
                      subtitle: Text('${fav.country} • ${fav.genre}', style: const TextStyle(color: Colors.grey)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          final messenger = ScaffoldMessenger.of(context);
                          RadioStorage().removeFavorite(fav.id).then((_) {
                            setState(() {});
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Removed from favourites')),
                            );
                          });
                        },
                      ),
                    ),
                  );
                },
              );
            },
          ),
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
              const Text(
                'Recording in progress. Tap stop to save.',
                style: TextStyle(color: Colors.grey),
              )
            else if (engine.recordingPath != null)
              Text(
                'Recording saved at: ${engine.recordingPath}',
                style: const TextStyle(color: Colors.white),
              )
            else
              const Text(
                'Start recording the current station.',
                style: TextStyle(color: Colors.grey),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              if (engine.isRecording) {
                engine.stopRecording().then((_) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Recording stopped and saved')),
                  );
                  navigator.pop();
                });
              } else {
                engine.startRecording().then((_) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Recording started')),
                  );
                  navigator.pop();
                });
              }
            },
            child: Text(
              engine.isRecording ? 'Stop' : 'Start',
              style: const TextStyle(color: Colors.red),
            ),
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
            child: ListView(
              shrinkWrap: true,
              children: languages.entries.map((entry) {
                return RadioListTile<String>(
                  title: Text(entry.value, style: const TextStyle(color: Colors.white)),
                  value: entry.key,
                  // ignore: deprecated_member_use
                  groupValue: selectedLanguage,
                  // ignore: deprecated_member_use
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedLanguage = value);
                    }
                  },
                  // ignore: deprecated_member_use
                  activeColor: Colors.red,
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