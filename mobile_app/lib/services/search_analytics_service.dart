import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../models/search_models.dart';

/// Service for tracking search analytics and performance metrics
class SearchAnalyticsService {
  static const String _analyticsKey = 'search_analytics';
  static const String _performanceKey = 'search_performance';
  static const String _popularTermsKey = 'popular_search_terms';
  static const String _userEngagementKey = 'user_engagement';

  // Note: _firestore will be used when implementing cloud analytics
  // final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Analytics data structures
  final Map<String, int> _searchTermFrequency = {};
  final Map<String, double> _searchTermRelevance = {};
  final Map<String, List<String>> _searchTermResults = {};
  final List<SearchAnalyticsEvent> _analyticsEvents = [];
  final Map<String, SearchPerformanceMetrics> _performanceMetrics = {};

  /// Track a search query with results
  Future<void> trackSearch({
    required String query,
    required List<SearchResult> results,
    required Duration searchDuration,
    required List<SearchFilter> appliedFilters,
    String? userId,
  }) async {
    try {
      final event = SearchAnalyticsEvent(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: SearchEventType.search,
        query: query,
        resultCount: results.length,
        searchDuration: searchDuration,
        appliedFilters: appliedFilters,
        timestamp: DateTime.now(),
        userId: userId,
      );

      _analyticsEvents.add(event);

      // Update frequency tracking
      _searchTermFrequency[query.toLowerCase()] =
          (_searchTermFrequency[query.toLowerCase()] ?? 0) + 1;

      // Calculate average relevance score
      if (results.isNotEmpty) {
        final avgRelevance =
            results.map((r) => r.relevanceScore).reduce((a, b) => a + b) /
                results.length;
        _searchTermRelevance[query.toLowerCase()] = avgRelevance;
      }

      // Store result user IDs for this query
      _searchTermResults[query.toLowerCase()] =
          results.map((r) => r.user.uid).toList();

      // Update performance metrics
      _updatePerformanceMetrics(query, searchDuration, results.length);

      // Save analytics data
      await _saveAnalyticsData();

      // debugPrint(
      //     'SearchAnalytics: Tracked search for "$query" - ${results.length} results in ${searchDuration.inMilliseconds}ms');
    } catch (e) {
      debugPrint('SearchAnalytics: Error tracking search: $e');
    }
  }

  /// Track user interaction with search results
  Future<void> trackResultInteraction({
    required String query,
    required SearchResult result,
    required SearchInteractionType interactionType,
    String? userId,
  }) async {
    try {
      final event = SearchAnalyticsEvent(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: SearchEventType.interaction,
        query: query,
        interactionType: interactionType,
        resultUserId: result.user.uid,
        timestamp: DateTime.now(),
        userId: userId,
      );

      _analyticsEvents.add(event);
      await _saveAnalyticsData();

      // debugPrint(
      //     'SearchAnalytics: Tracked ${interactionType.name} for "$query" -> ${result.user.name}');
    } catch (e) {
      debugPrint('SearchAnalytics: Error tracking interaction: $e');
    }
  }

  /// Track filter usage
  Future<void> trackFilterUsage({
    required List<SearchFilter> filters,
    required String query,
    String? userId,
  }) async {
    try {
      final selectedFilters = filters.where((f) => f.isSelected).toList();

      final event = SearchAnalyticsEvent(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: SearchEventType.filter,
        query: query,
        appliedFilters: selectedFilters,
        timestamp: DateTime.now(),
        userId: userId,
      );

      _analyticsEvents.add(event);
      await _saveAnalyticsData();

      // debugPrint(
      //     'SearchAnalytics: Tracked filter usage - ${selectedFilters.length} filters applied');
    } catch (e) {
      debugPrint('SearchAnalytics: Error tracking filter usage: $e');
    }
  }

  /// Get popular search terms
  List<PopularSearchTerm> getPopularSearchTerms({int limit = 10}) {
    final sortedTerms = _searchTermFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedTerms.take(limit).map((entry) {
      return PopularSearchTerm(
        term: entry.key,
        frequency: entry.value,
        averageRelevance: _searchTermRelevance[entry.key] ?? 0.0,
        lastSearched: _getLastSearchTime(entry.key),
      );
    }).toList();
  }

  /// Get search performance metrics
  SearchPerformanceMetrics getPerformanceMetrics() {
    if (_performanceMetrics.isEmpty) {
      return SearchPerformanceMetrics(
        totalSearches: 0,
        averageSearchDuration: Duration.zero,
        averageResultCount: 0.0,
        searchSuccessRate: 0.0,
        popularFilters: [],
      );
    }

    final totalSearches = _performanceMetrics.values
        .map((m) => m.totalSearches)
        .reduce((a, b) => a + b);

    final avgDuration = Duration(
      milliseconds: (_performanceMetrics.values
                  .map((m) => m.averageSearchDuration.inMilliseconds)
                  .reduce((a, b) => a + b) /
              _performanceMetrics.length)
          .round(),
    );

    final avgResultCount = _performanceMetrics.values
            .map((m) => m.averageResultCount)
            .reduce((a, b) => a + b) /
        _performanceMetrics.length;

    final successRate = _performanceMetrics.values
            .map((m) => m.searchSuccessRate)
            .reduce((a, b) => a + b) /
        _performanceMetrics.length;

    return SearchPerformanceMetrics(
      totalSearches: totalSearches,
      averageSearchDuration: avgDuration,
      averageResultCount: avgResultCount,
      searchSuccessRate: successRate,
      popularFilters: _getPopularFilters(),
    );
  }

  /// Get user engagement metrics
  UserEngagementMetrics getUserEngagementMetrics() {
    final interactions = _analyticsEvents
        .where((e) => e.type == SearchEventType.interaction)
        .toList();

    final clickThroughRate = _analyticsEvents.isNotEmpty
        ? interactions.length / _analyticsEvents.length
        : 0.0;

    final avgSessionDuration = _calculateAverageSessionDuration();
    final topInteractionTypes = _getTopInteractionTypes();

    return UserEngagementMetrics(
      clickThroughRate: clickThroughRate,
      averageSessionDuration: avgSessionDuration,
      topInteractionTypes: topInteractionTypes,
      totalInteractions: interactions.length,
    );
  }

  /// Update performance metrics for a search
  void _updatePerformanceMetrics(
      String query, Duration duration, int resultCount) {
    final key = query.toLowerCase();
    final existing = _performanceMetrics[key];

    if (existing != null) {
      final newTotal = existing.totalSearches + 1;
      final newAvgDuration = Duration(
        milliseconds: ((existing.averageSearchDuration.inMilliseconds *
                    existing.totalSearches) +
                duration.inMilliseconds) ~/
            newTotal,
      );
      final newAvgResults =
          ((existing.averageResultCount * existing.totalSearches) +
                  resultCount) /
              newTotal;
      final newSuccessRate = resultCount > 0
          ? ((existing.searchSuccessRate * existing.totalSearches) + 1) /
              newTotal
          : (existing.searchSuccessRate * existing.totalSearches) / newTotal;

      _performanceMetrics[key] = SearchPerformanceMetrics(
        totalSearches: newTotal,
        averageSearchDuration: newAvgDuration,
        averageResultCount: newAvgResults,
        searchSuccessRate: newSuccessRate,
        popularFilters: existing.popularFilters,
      );
    } else {
      _performanceMetrics[key] = SearchPerformanceMetrics(
        totalSearches: 1,
        averageSearchDuration: duration,
        averageResultCount: resultCount.toDouble(),
        searchSuccessRate: resultCount > 0 ? 1.0 : 0.0,
        popularFilters: [],
      );
    }
  }

  /// Save analytics data to local storage
  Future<void> _saveAnalyticsData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save events (keep only recent 1000 events)
      final recentEvents = _analyticsEvents.length > 1000
          ? _analyticsEvents.sublist(_analyticsEvents.length - 1000)
          : _analyticsEvents;

      final eventsJson =
          jsonEncode(recentEvents.map((e) => e.toJson()).toList());
      await prefs.setString(_analyticsKey, eventsJson);

      // Save frequency data
      final frequencyJson = jsonEncode(_searchTermFrequency);
      await prefs.setString(_popularTermsKey, frequencyJson);

      // Save performance metrics
      final performanceJson = jsonEncode(_performanceMetrics.map(
        (key, value) => MapEntry(key, value.toJson()),
      ));
      await prefs.setString(_performanceKey, performanceJson);
    } catch (e) {
      debugPrint('SearchAnalytics: Error saving analytics data: $e');
    }
  }

  /// Load analytics data from local storage
  Future<void> loadAnalyticsData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load events
      final eventsJson = prefs.getString(_analyticsKey);
      if (eventsJson != null) {
        final eventsList = jsonDecode(eventsJson) as List;
        _analyticsEvents.clear();
        _analyticsEvents.addAll(
          eventsList.map((e) => SearchAnalyticsEvent.fromJson(e)),
        );
      }

      // Load frequency data
      final frequencyJson = prefs.getString(_popularTermsKey);
      if (frequencyJson != null) {
        final frequencyMap = jsonDecode(frequencyJson) as Map<String, dynamic>;
        _searchTermFrequency.clear();
        _searchTermFrequency.addAll(
          frequencyMap.map((key, value) => MapEntry(key, value as int)),
        );
      }

      // Load performance metrics
      final performanceJson = prefs.getString(_performanceKey);
      if (performanceJson != null) {
        final performanceMap =
            jsonDecode(performanceJson) as Map<String, dynamic>;
        _performanceMetrics.clear();
        _performanceMetrics.addAll(
          performanceMap.map((key, value) =>
              MapEntry(key, SearchPerformanceMetrics.fromJson(value))),
        );
      }

      // debugPrint(
      //     'SearchAnalytics: Loaded ${_analyticsEvents.length} events, ${_searchTermFrequency.length} terms');
    } catch (e) {
      debugPrint('SearchAnalytics: Error loading analytics data: $e');
    }
  }

  /// Helper methods
  DateTime? _getLastSearchTime(String term) {
    final events = _analyticsEvents
        .where((e) =>
            e.query?.toLowerCase() == term && e.type == SearchEventType.search)
        .toList();

    if (events.isEmpty) return null;
    events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return events.first.timestamp;
  }

  List<String> _getPopularFilters() {
    final filterCounts = <String, int>{};

    for (final event in _analyticsEvents) {
      if (event.appliedFilters != null) {
        for (final filter in event.appliedFilters!) {
          if (filter.isSelected) {
            filterCounts[filter.name] = (filterCounts[filter.name] ?? 0) + 1;
          }
        }
      }
    }

    final sortedFilters = filterCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedFilters.take(10).map((e) => e.key).toList();
  }

  Duration _calculateAverageSessionDuration() {
    // Simple calculation based on time between first and last event
    if (_analyticsEvents.length < 2) return Duration.zero;

    _analyticsEvents.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final duration = _analyticsEvents.last.timestamp
        .difference(_analyticsEvents.first.timestamp);

    return Duration(
        milliseconds: duration.inMilliseconds ~/ _analyticsEvents.length);
  }

  Map<SearchInteractionType, int> _getTopInteractionTypes() {
    final counts = <SearchInteractionType, int>{};

    for (final event in _analyticsEvents) {
      if (event.interactionType != null) {
        counts[event.interactionType!] =
            (counts[event.interactionType!] ?? 0) + 1;
      }
    }

    return counts;
  }

  /// Clear all analytics data
  Future<void> clearAnalyticsData() async {
    try {
      _analyticsEvents.clear();
      _searchTermFrequency.clear();
      _searchTermRelevance.clear();
      _searchTermResults.clear();
      _performanceMetrics.clear();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_analyticsKey);
      await prefs.remove(_popularTermsKey);
      await prefs.remove(_performanceKey);
      await prefs.remove(_userEngagementKey);

      // debugPrint('SearchAnalytics: Cleared all analytics data');
    } catch (e) {
      debugPrint('SearchAnalytics: Error clearing analytics data: $e');
    }
  }
}
