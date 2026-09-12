import 'package:flutter/material.dart';

import '../data/local/preferences_service.dart';

/// Holds the app's [ThemeMode] and persists changes locally.
class ThemeController extends ChangeNotifier {
  ThemeController(this._preferences) {
    _mode = _parse(_preferences.themeMode);
  }

  final PreferencesService _preferences;
  late ThemeMode _mode;

  ThemeMode get mode => _mode;

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    await _preferences.setThemeMode(_serialize(mode));
  }

  static ThemeMode _parse(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _serialize(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}
