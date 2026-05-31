import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/notification_model.dart';

/// Service for managing notification preferences
class NotificationPreferencesService extends ChangeNotifier {
  static const String _preferencesKey = 'notification_preferences';
  static const String _globalEnabledKey = 'notifications_globally_enabled';
  static const String _soundEnabledKey = 'notification_sound_enabled';
  static const String _vibrationEnabledKey = 'notification_vibration_enabled';
  static const String _quietHoursEnabledKey = 'quiet_hours_enabled';
  static const String _quietHoursStartKey = 'quiet_hours_start';
  static const String _quietHoursEndKey = 'quiet_hours_end';

  // Default preferences
  Map<NotificationType, bool> _typePreferences = {
    NotificationType.achievement: true,
    NotificationType.event: true,
    NotificationType.message: true,
    NotificationType.system: true,
    NotificationType.reminder: true,
    NotificationType.social: true,
  };

  bool _globallyEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _quietHoursEnabled = false;
  String _quietHoursStart = '22:00';
  String _quietHoursEnd = '08:00';

  // Getters
  Map<NotificationType, bool> get typePreferences => Map.unmodifiable(_typePreferences);
  bool get globallyEnabled => _globallyEnabled;
  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  bool get quietHoursEnabled => _quietHoursEnabled;
  String get quietHoursStart => _quietHoursStart;
  String get quietHoursEnd => _quietHoursEnd;

  /// Initialize the service and load saved preferences
  Future<void> initialize() async {
    await _loadPreferences();
  }

  /// Check if a notification type is enabled
  bool isTypeEnabled(NotificationType type) {
    if (!_globallyEnabled) return false;
    return _typePreferences[type] ?? true;
  }

  /// Check if notifications should be shown based on quiet hours
  bool shouldShowNotification() {
    if (!_globallyEnabled) return false;
    if (!_quietHoursEnabled) return true;

    final now = DateTime.now();
    final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    
    // Simple time comparison (assumes same day)
    final startTime = _quietHoursStart;
    final endTime = _quietHoursEnd;
    
    // Handle overnight quiet hours (e.g., 22:00 to 08:00)
    if (startTime.compareTo(endTime) > 0) {
      return currentTime.compareTo(startTime) < 0 && currentTime.compareTo(endTime) > 0;
    } else {
      return currentTime.compareTo(startTime) < 0 || currentTime.compareTo(endTime) > 0;
    }
  }

  /// Toggle global notifications
  Future<void> setGloballyEnabled(bool enabled) async {
    _globallyEnabled = enabled;
    await _savePreferences();
    notifyListeners();
    debugPrint('NotificationPreferences: Global notifications ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Toggle notification type
  Future<void> setTypeEnabled(NotificationType type, bool enabled) async {
    _typePreferences[type] = enabled;
    await _savePreferences();
    notifyListeners();
    debugPrint('NotificationPreferences: ${type.displayName} notifications ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Toggle sound
  Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    await _savePreferences();
    notifyListeners();
    debugPrint('NotificationPreferences: Sound ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Toggle vibration
  Future<void> setVibrationEnabled(bool enabled) async {
    _vibrationEnabled = enabled;
    await _savePreferences();
    notifyListeners();
    debugPrint('NotificationPreferences: Vibration ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Toggle quiet hours
  Future<void> setQuietHoursEnabled(bool enabled) async {
    _quietHoursEnabled = enabled;
    await _savePreferences();
    notifyListeners();
    debugPrint('NotificationPreferences: Quiet hours ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Set quiet hours start time
  Future<void> setQuietHoursStart(String time) async {
    _quietHoursStart = time;
    await _savePreferences();
    notifyListeners();
    debugPrint('NotificationPreferences: Quiet hours start set to $time');
  }

  /// Set quiet hours end time
  Future<void> setQuietHoursEnd(String time) async {
    _quietHoursEnd = time;
    await _savePreferences();
    notifyListeners();
    debugPrint('NotificationPreferences: Quiet hours end set to $time');
  }

  /// Reset all preferences to defaults
  Future<void> resetToDefaults() async {
    _typePreferences = {
      NotificationType.achievement: true,
      NotificationType.event: true,
      NotificationType.message: true,
      NotificationType.system: true,
      NotificationType.reminder: true,
      NotificationType.social: true,
    };
    _globallyEnabled = true;
    _soundEnabled = true;
    _vibrationEnabled = true;
    _quietHoursEnabled = false;
    _quietHoursStart = '22:00';
    _quietHoursEnd = '08:00';
    
    await _savePreferences();
    notifyListeners();
    debugPrint('NotificationPreferences: Reset to defaults');
  }

  /// Load preferences from storage
  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load type preferences
      final typePrefsJson = prefs.getString(_preferencesKey);
      if (typePrefsJson != null) {
        final Map<String, dynamic> typePrefsMap = jsonDecode(typePrefsJson);
        _typePreferences = typePrefsMap.map((key, value) => MapEntry(
          NotificationType.values.firstWhere((e) => e.name == key),
          value as bool,
        ));
      }
      
      // Load other preferences
      _globallyEnabled = prefs.getBool(_globalEnabledKey) ?? true;
      _soundEnabled = prefs.getBool(_soundEnabledKey) ?? true;
      _vibrationEnabled = prefs.getBool(_vibrationEnabledKey) ?? true;
      _quietHoursEnabled = prefs.getBool(_quietHoursEnabledKey) ?? false;
      _quietHoursStart = prefs.getString(_quietHoursStartKey) ?? '22:00';
      _quietHoursEnd = prefs.getString(_quietHoursEndKey) ?? '08:00';
      
      debugPrint('NotificationPreferences: Loaded preferences');
    } catch (e) {
      debugPrint('NotificationPreferences: Error loading preferences: $e');
    }
  }

  /// Save preferences to storage
  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save type preferences
      final typePrefsMap = _typePreferences.map((key, value) => MapEntry(key.name, value));
      await prefs.setString(_preferencesKey, jsonEncode(typePrefsMap));
      
      // Save other preferences
      await prefs.setBool(_globalEnabledKey, _globallyEnabled);
      await prefs.setBool(_soundEnabledKey, _soundEnabled);
      await prefs.setBool(_vibrationEnabledKey, _vibrationEnabled);
      await prefs.setBool(_quietHoursEnabledKey, _quietHoursEnabled);
      await prefs.setString(_quietHoursStartKey, _quietHoursStart);
      await prefs.setString(_quietHoursEndKey, _quietHoursEnd);
      
      debugPrint('NotificationPreferences: Saved preferences');
    } catch (e) {
      debugPrint('NotificationPreferences: Error saving preferences: $e');
    }
  }

  /// Get enabled notification types count
  int get enabledTypesCount {
    return _typePreferences.values.where((enabled) => enabled).length;
  }

  /// Get disabled notification types count
  int get disabledTypesCount {
    return _typePreferences.values.where((enabled) => !enabled).length;
  }

  /// Check if all types are enabled
  bool get allTypesEnabled {
    return _typePreferences.values.every((enabled) => enabled);
  }

  /// Check if all types are disabled
  bool get allTypesDisabled {
    return _typePreferences.values.every((enabled) => !enabled);
  }

  /// Toggle all notification types
  Future<void> toggleAllTypes(bool enabled) async {
    for (final type in NotificationType.values) {
      _typePreferences[type] = enabled;
    }
    await _savePreferences();
    notifyListeners();
    debugPrint('NotificationPreferences: All types ${enabled ? 'enabled' : 'disabled'}');
  }
}
