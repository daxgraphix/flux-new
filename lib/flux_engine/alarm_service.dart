import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import '../flux_storage/radio_storage.dart';

class AlarmService extends ChangeNotifier {
  List<RadioAlarm> _alarms = [];
  List<RadioAlarm> get alarms => List.unmodifiable(_alarms);

  Future<void> initialize() async {
    _alarms = await RadioStorage().getAlarms();
    notifyListeners();
  }

  Future<void> addAlarm(RadioAlarm alarm) async {
    _alarms.add(alarm);
    await RadioStorage().saveAlarm(alarm);
    if (alarm.isEnabled) {
      await _scheduleAlarm(alarm);
    }
    notifyListeners();
  }

  Future<void> deleteAlarm(String id) async {
    _alarms.removeWhere((a) => a.id == id);
    await RadioStorage().deleteAlarm(id);
    if (Platform.isAndroid) {
      await AndroidAlarmManager.cancel(id.hashCode);
    }
    notifyListeners();
  }

  Future<void> toggleAlarm(String id) async {
    final index = _alarms.indexWhere((a) => a.id == id);
    if (index != -1) {
      final alarm = _alarms[index];
      final updatedAlarm = RadioAlarm(
        id: alarm.id,
        stationName: alarm.stationName,
        stationUrl: alarm.stationUrl,
        hour: alarm.hour,
        minute: alarm.minute,
        isEnabled: !alarm.isEnabled,
        daysOfWeek: alarm.daysOfWeek,
      );
      _alarms[index] = updatedAlarm;
      await RadioStorage().saveAlarm(updatedAlarm);
      
      if (updatedAlarm.isEnabled) {
        await _scheduleAlarm(updatedAlarm);
      } else if (Platform.isAndroid) {
        await AndroidAlarmManager.cancel(updatedAlarm.id.hashCode);
      }
      notifyListeners();
    }
  }

  Future<void> _scheduleAlarm(RadioAlarm alarm) async {
    if (!Platform.isAndroid) return;

    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, alarm.hour, alarm.minute);
    
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await AndroidAlarmManager.oneShotAt(
      scheduledDate,
      alarm.id.hashCode,
      alarmCallback,
      exact: true,
      wakeup: true,
      allowWhileIdle: true,
      params: {
        'url': alarm.stationUrl,
        'name': alarm.stationName,
      },
    );
  }

  @pragma('vm:entry-point')
  static void alarmCallback(int id, Map<String, dynamic> params) async {
    debugPrint('FLUX_ALARM: Fired for ${params['name']}');
    // In a real app, we would use a platform channel or a background service 
    // to start the RadioAudioHandler and begin playback.
    // For now, we'll log it clearly.
    // To implement full background playback on alarm:
    // 1. Start AudioService if not running
    // 2. Call playMediaItem with the station details
  }
}
