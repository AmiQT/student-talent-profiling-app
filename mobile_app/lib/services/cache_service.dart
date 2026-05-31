import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  SharedPreferences? _prefs;
  
  // Cache duration constants
  static const Duration shortCache = Duration(minutes: 5);
  static const Duration mediumCache = Duration(hours: 1);
  static const Duration longCache = Duration(hours: 24);

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    debugPrint('💾 Cache service initialized');
  }

  // Store data with expiration
  Future<void> store(
    String key,
    dynamic data, {
    Duration duration = mediumCache,
  }) async {
    if (_prefs == null) await initialize();
    
    final cacheData = {
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'duration': duration.inMilliseconds,
    };
    
    await _prefs!.setString(key, jsonEncode(cacheData));
    debugPrint('💾 Cached: $key (expires in ${duration.inMinutes}min)');
  }

  // Retrieve data if not expired
  T? get<T>(String key) {
    if (_prefs == null) return null;
    
    final cachedString = _prefs!.getString(key);
    if (cachedString == null) return null;
    
    try {
      final cacheData = jsonDecode(cachedString);
      final timestamp = cacheData['timestamp'] as int;
      final duration = cacheData['duration'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Check if expired
      if (now - timestamp > duration) {
        _prefs!.remove(key);
        debugPrint('💾 Cache expired: $key');
        return null;
      }
      
      debugPrint('💾 Cache hit: $key');
      return cacheData['data'] as T;
    } catch (e) {
      debugPrint('💾 Cache error for $key: $e');
      _prefs!.remove(key);
      return null;
    }
  }

  // Check if data exists and is valid
  bool isValid(String key) {
    return get(key) != null;
  }

  // Clear specific cache
  Future<void> clear(String key) async {
    if (_prefs == null) await initialize();
    await _prefs!.remove(key);
    debugPrint('💾 Cleared cache: $key');
  }

  // Clear all cache
  Future<void> clearAll() async {
    if (_prefs == null) await initialize();
    await _prefs!.clear();
    debugPrint('💾 Cleared all cache');
  }

  // Get cache size info
  Map<String, dynamic> getCacheInfo() {
    if (_prefs == null) return {};
    
    final keys = _prefs!.getKeys();
    int totalSize = 0;
    int validEntries = 0;
    int expiredEntries = 0;
    
    for (final key in keys) {
      final value = _prefs!.getString(key);
      if (value != null) {
        totalSize += value.length;
        if (isValid(key)) {
          validEntries++;
        } else {
          expiredEntries++;
        }
      }
    }
    
    return {
      'totalKeys': keys.length,
      'validEntries': validEntries,
      'expiredEntries': expiredEntries,
      'estimatedSize': '${(totalSize / 1024).toStringAsFixed(1)}KB',
    };
  }

  // Clean expired entries
  Future<void> cleanExpired() async {
    if (_prefs == null) await initialize();
    
    final keys = _prefs!.getKeys().toList();
    int cleaned = 0;
    
    for (final key in keys) {
      if (!isValid(key)) {
        await _prefs!.remove(key);
        cleaned++;
      }
    }
    
    debugPrint('💾 Cleaned $cleaned expired cache entries');
  }
}

// Specific cache keys for the app
class CacheKeys {
  static const String userProfile = 'user_profile';
  static const String achievements = 'achievements_';
  static const String events = 'events';
  static const String searchResults = 'search_';
  static const String profileStats = 'profile_stats';
  static const String notifications = 'notifications_';
  
  // Generate user-specific keys
  static String userAchievements(String userId) => '$achievements$userId';
  static String userNotifications(String userId) => '$notifications$userId';
  static String searchQuery(String query) => '$searchResults${query.hashCode}';
}