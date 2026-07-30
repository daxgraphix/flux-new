import 'package:flutter/foundation.dart';
import '../flux_storage/radio_storage.dart';

class SettingsService extends ChangeNotifier {
  bool _autoPlay = true;
  bool _highQuality = false;
  bool _dataSaver = false;
  bool _notificationsEnabled = true;
  String _language = 'en';
  int _cacheSize = 100;
  double _volume = 1.0;

  bool get autoPlay => _autoPlay;
  bool get highQuality => _highQuality;
  bool get dataSaver => _dataSaver;
  bool get notificationsEnabled => _notificationsEnabled;
  String get language => _language;
  int get cacheSize => _cacheSize;
  double get volume => _volume;

  Future<void> loadSettings() async {
    _autoPlay = await RadioStorage().getSettings<bool>('auto_play', defaultValue: true) ?? true;
    _highQuality = await RadioStorage().getSettings<bool>('high_quality', defaultValue: false) ?? false;
    _dataSaver = await RadioStorage().getSettings<bool>('data_saver', defaultValue: false) ?? false;
    _notificationsEnabled = await RadioStorage().getSettings<bool>('notifications_enabled', defaultValue: true) ?? true;
    _language = await RadioStorage().getSettings<String>('language', defaultValue: 'en') ?? 'en';
    _cacheSize = await RadioStorage().getSettings<int>('cache_size', defaultValue: 100) ?? 100;
    _volume = await RadioStorage().getSettings<double>('volume', defaultValue: 1.0) ?? 1.0;
    notifyListeners();
  }

  Future<void> saveSetting(String key, dynamic value) async {
    await RadioStorage().saveSettings(key, value);
    switch (key) {
      case 'auto_play': _autoPlay = value; break;
      case 'high_quality': _highQuality = value; break;
      case 'data_saver': _dataSaver = value; break;
      case 'notifications_enabled': _notificationsEnabled = value; break;
      case 'language': _language = value; break;
      case 'cache_size': _cacheSize = value; break;
      case 'volume': _volume = value; break;
    }
    notifyListeners();
  }

  Future<void> setHighQuality(bool value) => saveSetting('high_quality', value);
  Future<void> setAutoPlay(bool value) => saveSetting('auto_play', value);
  Future<void> setDataSaver(bool value) => saveSetting('data_saver', value);
  Future<void> setCacheSize(int value) => saveSetting('cache_size', value);
  Future<void> setLanguage(String value) => saveSetting('language', value);
  Future<void> setVolume(double value) => saveSetting('volume', value);

  Future<void> clearCache() async {
    await RadioStorage().clearCache();
    notifyListeners();
  }

  Future<void> resetSettings() async {
    await saveSetting('auto_play', true);
    await saveSetting('high_quality', false);
    await saveSetting('data_saver', false);
    await saveSetting('notifications_enabled', true);
    await saveSetting('language', 'en');
    await saveSetting('cache_size', 100);
    await saveSetting('volume', 1.0);
    notifyListeners();
  }
}
