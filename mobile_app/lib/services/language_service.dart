import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing language preferences and localization
class LanguageService extends ChangeNotifier {
  static const String _languageKey = 'selected_language';
  static const String _defaultLanguageCode = 'en';
  
  Locale _currentLocale = const Locale(_defaultLanguageCode);
  
  /// Get the current locale
  Locale get currentLocale => _currentLocale;
  
  /// Get the current language code
  String get currentLanguageCode => _currentLocale.languageCode;
  
  /// Get the current language display name
  String get currentLanguageDisplayName {
    switch (_currentLocale.languageCode) {
      case 'en':
        return 'English';
      case 'ms':
        return 'Bahasa Melayu';
      default:
        return 'English';
    }
  }
  
  /// List of supported locales
  static const List<Locale> supportedLocales = [
    Locale('en'), // English
    Locale('ms'), // Bahasa Melayu
  ];
  
  /// Map of language codes to display names
  static const Map<String, String> languageNames = {
    'en': 'English',
    'ms': 'Bahasa Melayu',
  };
  
  /// Initialize the language service
  Future<void> initialize() async {
    await _loadSavedLanguage();
  }
  
  /// Load the saved language preference
  Future<void> _loadSavedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLanguageCode = prefs.getString(_languageKey);
      
      if (savedLanguageCode != null && 
          supportedLocales.any((locale) => locale.languageCode == savedLanguageCode)) {
        _currentLocale = Locale(savedLanguageCode);
      } else {
        // Use system locale if supported, otherwise default to English
        final systemLocale = PlatformDispatcher.instance.locale;
        if (supportedLocales.any((locale) => locale.languageCode == systemLocale.languageCode)) {
          _currentLocale = Locale(systemLocale.languageCode);
        } else {
          _currentLocale = const Locale(_defaultLanguageCode);
        }
      }
    } catch (e) {
      // If there's an error, use default language
      _currentLocale = const Locale(_defaultLanguageCode);
    }
  }
  
  /// Change the current language
  Future<void> changeLanguage(String languageCode) async {
    if (!supportedLocales.any((locale) => locale.languageCode == languageCode)) {
      throw ArgumentError('Unsupported language code: $languageCode');
    }
    
    _currentLocale = Locale(languageCode);
    await _saveLanguagePreference(languageCode);
    notifyListeners();
  }
  
  /// Save the language preference to SharedPreferences
  Future<void> _saveLanguagePreference(String languageCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, languageCode);
    } catch (e) {
      // Handle error silently - the language change will still work for this session
      debugPrint('Error saving language preference: $e');
    }
  }
  
  /// Get display name for a language code
  static String getLanguageDisplayName(String languageCode) {
    return languageNames[languageCode] ?? 'Unknown';
  }
  
  /// Check if a language code is supported
  static bool isLanguageSupported(String languageCode) {
    return supportedLocales.any((locale) => locale.languageCode == languageCode);
  }
  
  /// Get the system's preferred language if supported
  static String? getSystemLanguageCode() {
    final systemLocale = PlatformDispatcher.instance.locale;
    if (supportedLocales.any((locale) => locale.languageCode == systemLocale.languageCode)) {
      return systemLocale.languageCode;
    }
    return null;
  }
  
  /// Reset to default language
  Future<void> resetToDefault() async {
    await changeLanguage(_defaultLanguageCode);
  }
  
  /// Reset to system language if supported, otherwise default
  Future<void> resetToSystem() async {
    final systemLanguageCode = getSystemLanguageCode();
    if (systemLanguageCode != null) {
      await changeLanguage(systemLanguageCode);
    } else {
      await resetToDefault();
    }
  }
}
