import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../models/search_models.dart';

/// Service for intelligent search result caching and offline support
class SearchCacheService {
  static const String _cachePrefix = 'search_cache_';
  static const String _metadataKey = 'search_cache_metadata';
  static const String _offlineQueueKey = 'offline_search_queue';
  static const String _popularResultsKey = 'popular_search_results';

  // Cache configuration
  static const Duration _cacheExpiry = Duration(hours: 2);
  static const Duration _popularResultsExpiry = Duration(days: 1);
  static const int _maxCacheEntries = 100;
  static const int _maxOfflineResults = 50;

  final Map<String, CachedSearchResult> _memoryCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  final List<OfflineSearchRequest> _offlineQueue = [];

  bool _isOnline = true;

  SearchCacheService();

  /// Check if device is currently online using a simple network test
  Future<bool> isOnline() async {
    try {
      if (kIsWeb) {
        return true; // Assume online on web, browser handles connectivity
      }
      
      // Simple connectivity test using DNS lookup
      final result = await InternetAddress.lookup('google.com');
      _isOnline = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      return _isOnline;
    } catch (e) {
      // On error, assume offline but log it
      // If it's a DNS error, it likely means offline
      _isOnline = false;
      debugPrint('SearchCache: Device appears to be offline: $e');
      return false;
    }
  }

  /// Cache search results with intelligent storage
  Future<void> cacheSearchResults({
    required String query,
    required List<SearchFilter> filters,
    required List<SearchResult> results,
    bool isPopular = false,
  }) async {
    try {
      final cacheKey = _generateCacheKey(query, filters);
      final cachedResult = CachedSearchResult(
        query: query,
        filters: filters,
        results: results,
        timestamp: DateTime.now(),
        isPopular: isPopular,
        accessCount: 1,
      );

      // Store in memory cache
      _memoryCache[cacheKey] = cachedResult;
      _cacheTimestamps[cacheKey] = DateTime.now();

      // Store in persistent cache
      await _saveToPersistentCache(cacheKey, cachedResult);

      // Update metadata
      await _updateCacheMetadata(cacheKey, cachedResult);

      // Clean up old cache entries
      await _cleanupCache();

      debugPrint('SearchCache: Cached ${results.length} results for "$query"');
    } catch (e) {
      debugPrint('SearchCache: Error caching results: $e');
    }
  }

  /// Retrieve cached search results
  Future<List<SearchResult>?> getCachedResults({
    required String query,
    required List<SearchFilter> filters,
  }) async {
    try {
      final cacheKey = _generateCacheKey(query, filters);

      // Check memory cache first
      if (_memoryCache.containsKey(cacheKey)) {
        final cached = _memoryCache[cacheKey]!;
        if (_isCacheValid(cached.timestamp)) {
          cached.accessCount++;
          cached.lastAccessed = DateTime.now();
          debugPrint(
              'SearchCache: Retrieved ${cached.results.length} results from memory cache');
          return cached.results;
        } else {
          _memoryCache.remove(cacheKey);
          _cacheTimestamps.remove(cacheKey);
        }
      }

      // Check persistent cache
      final cached = await _loadFromPersistentCache(cacheKey);
      if (cached != null && _isCacheValid(cached.timestamp)) {
        // Load back into memory cache
        _memoryCache[cacheKey] = cached;
        _cacheTimestamps[cacheKey] = cached.timestamp;

        cached.accessCount++;
        cached.lastAccessed = DateTime.now();

        return cached.results;
      }

      return null;
    } catch (e) {
      debugPrint('SearchCache: Error retrieving cached results: $e');
      return null;
    }
  }

  /// Get popular/trending search results for offline use
  Future<List<SearchResult>> getPopularResults() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final popularJson = prefs.getString(_popularResultsKey);

      if (popularJson != null) {
        final data = jsonDecode(popularJson) as Map<String, dynamic>;
        final timestamp = DateTime.parse(data['timestamp']);

        if (_isCacheValid(timestamp, _popularResultsExpiry)) {
          final resultsList = data['results'] as List;
          final results =
              resultsList.map((r) => SearchResult.fromJson(r)).toList();

          debugPrint(
              'SearchCache: Retrieved ${results.length} popular results');
          return results.take(_maxOfflineResults).toList();
        }
      }

      return [];
    } catch (e) {
      debugPrint('SearchCache: Error retrieving popular results: $e');
      return [];
    }
  }

  /// Cache popular results for offline access
  Future<void> cachePopularResults(List<SearchResult> results) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'results': results.map((r) => r.toJson()).toList(),
        'timestamp': DateTime.now().toIso8601String(),
      };

      await prefs.setString(_popularResultsKey, jsonEncode(data));
    } catch (e) {
      debugPrint('SearchCache: Error caching popular results: $e');
    }
  }

  /// Queue search request for when back online
  Future<void> queueOfflineSearch({
    required String query,
    required List<SearchFilter> filters,
  }) async {
    try {
      final request = OfflineSearchRequest(
        query: query,
        filters: filters,
        timestamp: DateTime.now(),
      );

      _offlineQueue.add(request);
      await _saveOfflineQueue();

      debugPrint('SearchCache: Queued offline search for "$query"');
    } catch (e) {
      debugPrint('SearchCache: Error queuing offline search: $e');
    }
  }

  /// Generate cache key from query and filters
  String _generateCacheKey(String query, List<SearchFilter> filters) {
    final filterString = filters
        .where((f) => f.isSelected)
        .map((f) => '${f.category}:${f.id}')
        .join(',');

    return '${query.toLowerCase()}_$filterString'.replaceAll(' ', '_');
  }

  /// Check if cache entry is still valid
  bool _isCacheValid(DateTime timestamp, [Duration? customExpiry]) {
    final expiry = customExpiry ?? _cacheExpiry;
    return DateTime.now().difference(timestamp) < expiry;
  }

  /// Save cached result to persistent storage
  Future<void> _saveToPersistentCache(
      String key, CachedSearchResult result) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$key';
      final json = jsonEncode(result.toJson());
      await prefs.setString(cacheKey, json);
    } catch (e) {
      debugPrint('SearchCache: Error saving to persistent cache: $e');
    }
  }

  /// Load cached result from persistent storage
  Future<CachedSearchResult?> _loadFromPersistentCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$key';
      final json = prefs.getString(cacheKey);

      if (json != null) {
        final data = jsonDecode(json) as Map<String, dynamic>;
        return CachedSearchResult.fromJson(data);
      }

      return null;
    } catch (e) {
      debugPrint('SearchCache: Error loading from persistent cache: $e');
      return null;
    }
  }

  /// Update cache metadata for management
  Future<void> _updateCacheMetadata(
      String key, CachedSearchResult result) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final metadataJson = prefs.getString(_metadataKey) ?? '{}';
      final metadata = jsonDecode(metadataJson) as Map<String, dynamic>;

      metadata[key] = {
        'timestamp': result.timestamp.toIso8601String(),
        'accessCount': result.accessCount,
        'lastAccessed': result.lastAccessed?.toIso8601String(),
        'isPopular': result.isPopular,
        'resultCount': result.results.length,
      };

      await prefs.setString(_metadataKey, jsonEncode(metadata));
    } catch (e) {
      debugPrint('SearchCache: Error updating metadata: $e');
    }
  }

  /// Clean up old cache entries
  Future<void> _cleanupCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final metadataJson = prefs.getString(_metadataKey) ?? '{}';
      final metadata = jsonDecode(metadataJson) as Map<String, dynamic>;

      // Remove expired entries
      final keysToRemove = <String>[];
      for (final entry in metadata.entries) {
        final timestamp = DateTime.parse(entry.value['timestamp']);
        if (!_isCacheValid(timestamp)) {
          keysToRemove.add(entry.key);
        }
      }

      // Remove from both metadata and cache
      for (final key in keysToRemove) {
        metadata.remove(key);
        await prefs.remove('$_cachePrefix$key');
        _memoryCache.remove(key);
        _cacheTimestamps.remove(key);
      }

      // If still too many entries, remove least recently used
      if (metadata.length > _maxCacheEntries) {
        final sortedEntries = metadata.entries.toList()
          ..sort((a, b) {
            final aAccessed = a.value['lastAccessed'] as String?;
            final bAccessed = b.value['lastAccessed'] as String?;

            if (aAccessed == null && bAccessed == null) return 0;
            if (aAccessed == null) return 1;
            if (bAccessed == null) return -1;

            return DateTime.parse(aAccessed)
                .compareTo(DateTime.parse(bAccessed));
          });

        final toRemove = sortedEntries.take(metadata.length - _maxCacheEntries);
        for (final entry in toRemove) {
          metadata.remove(entry.key);
          await prefs.remove('$_cachePrefix${entry.key}');
          _memoryCache.remove(entry.key);
          _cacheTimestamps.remove(entry.key);
        }
      }

      await prefs.setString(_metadataKey, jsonEncode(metadata));
      debugPrint(
          'SearchCache: Cleaned up cache, ${keysToRemove.length} expired entries removed');
    } catch (e) {
      debugPrint('SearchCache: Error cleaning up cache: $e');
    }
  }

  /// Save offline queue to persistent storage
  Future<void> _saveOfflineQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(_offlineQueue.map((r) => r.toJson()).toList());
      await prefs.setString(_offlineQueueKey, json);
    } catch (e) {
      debugPrint('SearchCache: Error saving offline queue: $e');
    }
  }

  /// Load offline queue from persistent storage
  Future<void> loadOfflineQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_offlineQueueKey);

      if (json != null) {
        final list = jsonDecode(json) as List;
        _offlineQueue.clear();
        _offlineQueue.addAll(
          list.map((r) => OfflineSearchRequest.fromJson(r)),
        );

        debugPrint(
            'SearchCache: Loaded ${_offlineQueue.length} queued searches');
      }
    } catch (e) {
      debugPrint('SearchCache: Error loading offline queue: $e');
    }
  }

  /// Get cache statistics
  Future<CacheStatistics> getCacheStatistics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final metadataJson = prefs.getString(_metadataKey) ?? '{}';
      final metadata = jsonDecode(metadataJson) as Map<String, dynamic>;

      int totalEntries = metadata.length;
      int totalResults = 0;
      int popularEntries = 0;

      for (final entry in metadata.values) {
        totalResults += entry['resultCount'] as int;
        if (entry['isPopular'] == true) popularEntries++;
      }

      return CacheStatistics(
        totalEntries: totalEntries,
        totalResults: totalResults,
        popularEntries: popularEntries,
        memoryEntries: _memoryCache.length,
        queuedSearches: _offlineQueue.length,
        isOnline: _isOnline,
      );
    } catch (e) {
      debugPrint('SearchCache: Error getting cache statistics: $e');
      return CacheStatistics(
        totalEntries: 0,
        totalResults: 0,
        popularEntries: 0,
        memoryEntries: _memoryCache.length,
        queuedSearches: _offlineQueue.length,
        isOnline: _isOnline,
      );
    }
  }

  /// Clear all cache data
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get all cache keys
      final keys = prefs.getKeys().where((key) => key.startsWith(_cachePrefix));

      // Remove all cache entries
      for (final key in keys) {
        await prefs.remove(key);
      }

      // Clear metadata and other cache data
      await prefs.remove(_metadataKey);
      await prefs.remove(_popularResultsKey);
      await prefs.remove(_offlineQueueKey);

      // Clear memory cache
      _memoryCache.clear();
      _cacheTimestamps.clear();
      _offlineQueue.clear();

      debugPrint('SearchCache: Cleared all cache data');
    } catch (e) {
      debugPrint('SearchCache: Error clearing cache: $e');
    }
  }
}
