import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../flux_engine/radio_engine.dart';
import '../flux_storage/radio_storage.dart';
import '../helpers/navigation_helper.dart';
import 'recent_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final engine = Provider.of<RadioEngine>(context);
    final width = MediaQuery.of(context).size.width;
    final isTablet = width >= 600;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Settings', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, color: theme.appBarTheme.foregroundColor)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: true,
      ),
      body: Container(
        color: theme.scaffoldBackgroundColor,
        child: SafeArea(
          child: Center(
            child: SizedBox(
              width: isTablet ? 600 : double.infinity,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                physics: const BouncingScrollPhysics(),
                children: [
              _buildModernSection(
                context,
                'AUDIO ENGINE',
                [
                  _buildModernSwitchTile(
                    context,
                    icon: Icons.high_quality_rounded,
                    title: 'High Quality Audio',
                    subtitle: 'Prioritize high bitrate streams',
                    value: engine.highQuality,
                    onChanged: (v) => engine.setHighQuality(v),
                  ),
                  _buildModernTile(
                    context,
                    icon: Icons.volume_up_rounded,
                    title: 'Playback Volume',
                    subtitle: '${(engine.volume * 100).round()}%',
                    onTap: () => _showVolumeDialog(context, engine),
                  ),
                  _buildModernTile(
                    context,
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
                    context,
                    icon: Icons.play_circle_filled_rounded,
                    title: 'Auto-play on Start',
                    subtitle: 'Resume last station automatically',
                    value: engine.autoPlay,
                    onChanged: (v) => engine.setAutoPlay(v),
                  ),
                  _buildModernTile(
                    context,
                    icon: Icons.mic_rounded,
                    title: 'Live Recording',
                    subtitle: engine.isRecording ? 'Recording active...' : 'Manage your recordings',
                    onTap: () => _showRecordingDialog(context, engine),
                    trailing: engine.isRecording ? _buildLiveIndicator(theme) : null,
                  ),
                  _buildModernTile(
                    context,
                    icon: Icons.history_rounded,
                    title: 'Recently Played',
                    subtitle: 'View listening history',
                    onTap: () {
                      Navigator.of(context).push(NavigationHelper.slideRightRoute(const RecentScreen()));
                    },
                  ),
                  _buildModernTile(
                    context,
                    icon: Icons.alarm_rounded,
                    title: 'Radio Alarm',
                    subtitle: engine.alarms.any((a) => a.isEnabled)
                        ? '${engine.alarms.where((a) => a.isEnabled).length} active alarms'
                        : 'Wake up with music',
                    onTap: () => _showAlarmListDialog(context, engine),
                  ),
                ],
              ),
              _buildModernSection(
                context,
                'DATA & STORAGE',
                [
                  _buildModernSwitchTile(
                    context,
                    icon: Icons.data_usage_rounded,
                    title: 'Data Saver Mode',
                    subtitle: 'Reduce bandwidth usage',
                    value: engine.dataSaver,
                    onChanged: (v) => engine.setDataSaver(v),
                  ),
                  _buildModernTile(
                    context,
                    icon: Icons.storage_rounded,
                    title: 'Cache Management',
                    subtitle: 'Current limit: ${engine.cacheSize}MB',
                    onTap: () => _showCacheDialog(context, engine),
                  ),
                  _buildModernTile(
                    context,
                    icon: Icons.update_rounded,
                    title: 'Update Directory',
                    subtitle: 'Refresh countries, genres & tags',
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await engine.checkForUpdates();
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Station directory updated!')),
                        );
                      } catch (e) {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Failed to update directory.')),
                        );
                      }
                    },
                  ),
                  _buildModernTile(
                    context,
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
                    context,
                    icon: Icons.restore_rounded,
                    title: 'Reset to Factory Settings',
                    subtitle: 'Warning: This cannot be undone',
                    onTap: () => _showResetDialog(context),
                    textColor: theme.colorScheme.error,
                  ),
                ],
              ),
               const SizedBox(height: 32),
             ],
           ),
         ),
       ),
     ),
   ),
 );
  }

  Widget _buildModernSection(BuildContext context, String title, List<Widget> children) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            title,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildModernTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
    Color? textColor,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: theme.colorScheme.primary, size: 22),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          fontSize: 13,
        ),
      ),
      trailing: trailing ?? Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildModernSwitchTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    Color? activeColor,
  }) {
    final theme = Theme.of(context);
    final effectiveActiveColor = activeColor ?? theme.colorScheme.primary;
    return SwitchListTile(
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: effectiveActiveColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: effectiveActiveColor, size: 22),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          fontSize: 13,
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeThumbColor: effectiveActiveColor,
      activeTrackColor: effectiveActiveColor.withValues(alpha: 0.5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildLiveIndicator(ThemeData theme) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: theme.colorScheme.error,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: theme.colorScheme.error, blurRadius: 4, spreadRadius: 1)],
      ),
    );
  }

  void _showVolumeDialog(BuildContext context, RadioEngine engine) {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: theme.cardColor,
          title: Text(
            'Volume Control',
            style: TextStyle(color: theme.textTheme.titleLarge?.color),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.volume_down, color: theme.iconTheme.color?.withValues(alpha: 0.7)),
                  Expanded(
                    child: Slider(
                      value: engine.volume,
                      min: 0.0,
                      max: 1.0,
                      onChanged: engine.setVolume,
                      activeColor: theme.primaryColor,
                      inactiveColor: theme.primaryColor.withValues(alpha: 0.2),
                    ),
                  ),
                  Icon(Icons.volume_up, color: theme.iconTheme.color?.withValues(alpha: 0.7)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Volume: ${(engine.volume * 100).round()}%',
                style: TextStyle(color: theme.textTheme.bodyMedium?.color),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close', style: TextStyle(color: theme.primaryColor)),
            ),
          ],
        );
      },
    );
  }

  void _showAlarmListDialog(BuildContext context, RadioEngine engine) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final theme = Theme.of(context);
          final textColor = theme.textTheme.bodyLarge?.color;
          final secondaryTextColor = theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6);

          return AlertDialog(
            backgroundColor: theme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                Icon(Icons.alarm, color: theme.primaryColor),
                const SizedBox(width: 12),
                Text('Radio Alarms', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.add_alarm, color: theme.primaryColor),
                  onPressed: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (time != null && engine.currentStation != null) {
                      final alarm = RadioAlarm(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        stationName: engine.currentStation!.name,
                        stationUrl: engine.currentStation!.url,
                        hour: time.hour,
                        minute: time.minute,
                      );
                      await engine.addAlarm(alarm);
                      if (mounted) setDialogState(() {});
                    } else if (engine.currentStation == null) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select a station first')),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: engine.alarms.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text('No alarms set. Current station will be used for new alarms.',
                          textAlign: TextAlign.center, style: TextStyle(color: secondaryTextColor)),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: engine.alarms.length,
                      itemBuilder: (context, index) {
                        final alarm = engine.alarms[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${alarm.hour.toString().padLeft(2, '0')}:${alarm.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                          ),
                          subtitle: Text(alarm.stationName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: secondaryTextColor)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: alarm.isEnabled,
                                activeTrackColor: theme.primaryColor.withValues(alpha: 0.5),
                                activeThumbColor: theme.primaryColor,
                                onChanged: (value) async {
                                  await engine.toggleAlarm(alarm.id);
                                  if (mounted) setDialogState(() {});
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_outline, color: secondaryTextColor),
                                onPressed: () async {
                                  await engine.deleteAlarm(alarm.id);
                                  setDialogState(() {});
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('CLOSE', style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEqualizerDialog(BuildContext context, RadioEngine engine) {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final textColor = theme.textTheme.bodyLarge?.color;

        return AlertDialog(
          backgroundColor: theme.cardColor,
          title: Text(
            'Equalizer',
            style: TextStyle(color: theme.textTheme.titleLarge?.color),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () => engine.resetEqualizer(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
                        foregroundColor: theme.primaryColor,
                        elevation: 0,
                      ),
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
                        foregroundColor: theme.primaryColor,
                        elevation: 0,
                      ),
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
                        foregroundColor: theme.primaryColor,
                        elevation: 0,
                      ),
                      child: const Text('Rock'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Frequency Bands', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildEqSlider(engine, 0, '60Hz', '10kHz', theme),
                _buildEqSlider(engine, 1, '170Hz', '4kHz', theme),
                _buildEqSlider(engine, 2, '31Hz', '8kHz', theme),
                _buildEqSlider(engine, 3, '60Hz', '12kHz', theme),
                _buildEqSlider(engine, 4, '170Hz', '16kHz', theme),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close', style: TextStyle(color: theme.primaryColor)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEqSlider(RadioEngine engine, int index, String lowLabel, String highLabel, ThemeData theme) {
    return Row(
      children: [
        Text(lowLabel, style: TextStyle(color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6), fontSize: 10)),
        Expanded(
          child: Slider(
            value: engine.equalizerBands[index],
            min: -10,
            max: 10,
            onChanged: (value) => engine.updateEqualizerBand(index, value),
            activeColor: theme.primaryColor,
            inactiveColor: theme.primaryColor.withValues(alpha: 0.2),
          ),
        ),
        Text(highLabel, style: TextStyle(color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6), fontSize: 10)),
      ],
    );
  }

  void _showRecordingDialog(BuildContext context, RadioEngine engine) {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final textColor = theme.textTheme.bodyLarge?.color;
        final secondaryTextColor = theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6);

        return AlertDialog(
          backgroundColor: theme.cardColor,
          title: Text(
            'Recording',
            style: TextStyle(color: theme.textTheme.titleLarge?.color),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (engine.isRecording)
                Column(
                  children: [
                    CircularProgressIndicator(color: theme.primaryColor),
                    const SizedBox(height: 8),
                    Text(
                      'Recording in progress...',
                      style: TextStyle(color: secondaryTextColor),
                    ),
                  ],
                )
              else if (engine.savedRecordings.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Saved Recordings:',
                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...engine.savedRecordings.take(3).map((path) => ListTile(
                      leading: Icon(Icons.audio_file, color: theme.primaryColor),
                      title: Text(
                        File(path).uri.pathSegments.isNotEmpty 
                            ? File(path).uri.pathSegments.last 
                            : 'Recording',
                        style: TextStyle(color: textColor, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.play_arrow, color: theme.primaryColor),
                        onPressed: () {
                          Navigator.pop(context);
                          engine.playRecording(path);
                        },
                      ),
                    )),
                  ],
                ),
              if (engine.savedRecordings.isEmpty && !engine.isRecording)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No recordings yet', style: TextStyle(color: secondaryTextColor)),
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
                style: TextStyle(color: engine.isRecording ? theme.colorScheme.error : theme.primaryColor),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close', style: TextStyle(color: secondaryTextColor)),
            ),
          ],
        );
      },
    );
  }

  void _showCacheDialog(BuildContext context, RadioEngine engine) {
    int tempCacheSize = engine.cacheSize;
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final textColor = theme.textTheme.bodyLarge?.color;
        final secondaryTextColor = theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6);

        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: theme.cardColor,
            title: Text('Cache Size', style: TextStyle(color: theme.textTheme.titleLarge?.color)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Set maximum cache size (MB):',
                  style: TextStyle(color: secondaryTextColor),
                ),
                const SizedBox(height: 16),
                Slider(
                  value: tempCacheSize.toDouble(),
                  min: 50,
                  max: 500,
                  divisions: 9,
                  label: '${tempCacheSize}MB',
                  onChanged: (value) => setDialogState(() => tempCacheSize = value.round()),
                  activeColor: theme.primaryColor,
                  inactiveColor: theme.primaryColor.withValues(alpha: 0.2),
                ),
                Text(
                  '${tempCacheSize}MB',
                  style: TextStyle(color: textColor, fontSize: 16),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: secondaryTextColor)),
              ),
              TextButton(
                onPressed: () {
                  engine.setCacheSize(tempCacheSize);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cache size updated')),
                  );
                },
                child: Text('Save', style: TextStyle(color: theme.primaryColor)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showResetDialog(BuildContext context) {
    final engine = Provider.of<RadioEngine>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: theme.cardColor,
          title: Text('Reset Settings', style: TextStyle(color: theme.textTheme.titleLarge?.color)),
          content: Text(
            'Are you sure you want to reset all settings to their default values?',
            style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6))),
            ),
            TextButton(
              onPressed: () async {
                await engine.resetSettings();
                if (!mounted) return;
                Navigator.pop(this.context);
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Settings reset to defaults')),
                );
              },
              child: Text('Reset', style: TextStyle(color: theme.colorScheme.error)),
            ),
          ],
        );
      },
    );
  }
}
