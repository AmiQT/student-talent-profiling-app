import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.system;
  bool _isDarkMode = false;
  bool _isSystemTheme = true;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _isDarkMode;
  bool get isSystemTheme => _isSystemTheme;

  bool _isInitialized = false;

  ThemeProvider() {
    // Delay theme loading slightly to prevent interference with app initialization
    Future.microtask(() => _loadThemeMode());
  }

  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeString = prefs.getString(_themeKey);

      if (themeString != null) {
        switch (themeString) {
          case 'light':
            _themeMode = ThemeMode.light;
            _isDarkMode = false;
            _isSystemTheme = false;
            break;
          case 'dark':
            _themeMode = ThemeMode.dark;
            _isDarkMode = true;
            _isSystemTheme = false;
            break;
          case 'system':
          default:
            _themeMode = ThemeMode.system;
            _isSystemTheme = true;
            _updateSystemTheme();
            break;
        }
      } else {
        _themeMode = ThemeMode.system;
        _isSystemTheme = true;
        _updateSystemTheme();
      }

      _isInitialized = true;
      // Only notify listeners after initialization is complete
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading theme mode: $e');
      // Fallback to system theme
      _themeMode = ThemeMode.system;
      _isSystemTheme = true;
      _updateSystemTheme();
      _isInitialized = true;
    }
  }

  void _updateSystemTheme() {
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    _isDarkMode = brightness == Brightness.dark;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode || !_isInitialized) return;

    _themeMode = mode;

    switch (mode) {
      case ThemeMode.light:
        _isDarkMode = false;
        _isSystemTheme = false;
        break;
      case ThemeMode.dark:
        _isDarkMode = true;
        _isSystemTheme = false;
        break;
      case ThemeMode.system:
        _isSystemTheme = true;
        _updateSystemTheme();
        break;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      String themeString;
      switch (mode) {
        case ThemeMode.light:
          themeString = 'light';
          break;
        case ThemeMode.dark:
          themeString = 'dark';
          break;
        case ThemeMode.system:
          themeString = 'system';
          break;
      }
      await prefs.setString(_themeKey, themeString);
    } catch (e) {
      debugPrint('Error saving theme mode: $e');
    }

    notifyListeners();
  }

  Future<void> toggleTheme() async {
    if (_isSystemTheme) {
      // If system theme, switch to light
      await setThemeMode(ThemeMode.light);
    } else if (_isDarkMode) {
      // If dark, switch to light
      await setThemeMode(ThemeMode.light);
    } else {
      // If light, switch to dark
      await setThemeMode(ThemeMode.dark);
    }
  }

  Future<void> resetToSystem() async {
    await setThemeMode(ThemeMode.system);
  }

  // Helper method to get current theme mode string
  String get currentThemeString {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  // Helper method to get next theme mode
  ThemeMode get nextThemeMode {
    switch (_themeMode) {
      case ThemeMode.light:
        return ThemeMode.dark;
      case ThemeMode.dark:
        return ThemeMode.system;
      case ThemeMode.system:
        return ThemeMode.light;
    }
  }

  // Helper method to get next theme mode string
  String get nextThemeString {
    switch (nextThemeMode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  // Material theme mode for backward compatibility
  ThemeMode get materialThemeMode => _themeMode;
}
