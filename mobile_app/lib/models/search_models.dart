import '../models/user_model.dart';
import '../models/profile_model.dart';

/// Search filter model for organizing search criteria
class SearchFilter {
  final String id;
  final String name;
  final String category;
  final bool isSelected;

  SearchFilter({
    required this.id,
    required this.name,
    required this.category,
    this.isSelected = false,
  });

  SearchFilter copyWith({
    String? id,
    String? name,
    String? category,
    bool? isSelected,
  }) {
    return SearchFilter(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'isSelected': isSelected,
    };
  }

  factory SearchFilter.fromJson(Map<String, dynamic> json) {
    return SearchFilter(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      isSelected: json['isSelected'] ?? false,
    );
  }
}

/// Search result model combining user and profile data
class SearchResult {
  final UserModel user;
  final ProfileModel? profile;
  final double relevanceScore;
  final List<String> matchedFields;

  SearchResult({
    required this.user,
    this.profile,
    this.relevanceScore = 0.0,
    this.matchedFields = const [],
  });

  // Get display name (prefer profile full name, fallback to user name)
  String get displayName => profile?.fullName ?? user.name;

  // Get profile image URL
  String? get profileImageUrl => profile?.profileImageUrl;

  // Get bio/headline
  String? get bio => profile?.bio;
  String? get headline => profile?.headline;

  // Get department (prefer profile, fallback to user)
  String? get department =>
      profile?.academicInfo?.department ?? user.department;

  // Get role display
  String get roleDisplay {
    switch (user.role) {
      case UserRole.student:
        return 'Student';
      case UserRole.lecturer:
        return 'Lecturer';
      case UserRole.admin:
        return 'Admin';
    }
  }

  // Get skills
  List<String> get skills => profile?.skills ?? [];

  // Get interests
  List<String> get interests => profile?.interests ?? [];

  // Get academic info
  String? get program => profile?.academicInfo?.program;
  int? get currentSemester => profile?.academicInfo?.currentSemester;
  String? get studentId => profile?.academicInfo?.studentId ?? user.studentId;

  // Profile completeness percentage
  double get profileCompleteness {
    if (profile == null) return 0.0;

    int totalFields = 10; // Adjust based on important fields
    int completedFields = 0;

    if (profile!.fullName.isNotEmpty) completedFields++;
    if (profile!.bio != null && profile!.bio!.isNotEmpty) completedFields++;
    if (profile!.headline != null && profile!.headline!.isNotEmpty) {
      completedFields++;
    }
    if (profile!.profileImageUrl != null &&
        profile!.profileImageUrl!.isNotEmpty) {
      completedFields++;
    }
    if (profile!.skills.isNotEmpty) completedFields++;
    if (profile!.interests.isNotEmpty) completedFields++;
    if (profile!.experiences.isNotEmpty) completedFields++;
    if (profile!.projects.isNotEmpty) completedFields++;
    if (profile!.achievements.isNotEmpty) completedFields++;
    if (profile!.academicInfo != null) completedFields++;

    return (completedFields / totalFields) * 100;
  }

  // Check if user is currently active (for future online status)
  bool get isActive => user.isActive;

  SearchResult copyWith({
    UserModel? user,
    ProfileModel? profile,
    double? relevanceScore,
    List<String>? matchedFields,
  }) {
    return SearchResult(
      user: user ?? this.user,
      profile: profile ?? this.profile,
      relevanceScore: relevanceScore ?? this.relevanceScore,
      matchedFields: matchedFields ?? this.matchedFields,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'profile': profile?.toJson(),
      'relevanceScore': relevanceScore,
      'matchedFields': matchedFields,
    };
  }

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      user: UserModel.fromJson(json['user']),
      profile: json['profile'] != null
          ? ProfileModel.fromJson(json['profile'])
          : null,
      relevanceScore: (json['relevanceScore'] ?? 0.0).toDouble(),
      matchedFields: List<String>.from(json['matchedFields'] ?? []),
    );
  }
}

/// Search history item model
class SearchHistoryItem {
  final String id;
  final String query;
  final DateTime searchedAt;
  final int resultCount;
  final List<SearchFilter> appliedFilters;

  SearchHistoryItem({
    required this.id,
    required this.query,
    required this.searchedAt,
    this.resultCount = 0,
    this.appliedFilters = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'query': query,
      'searchedAt': searchedAt.toIso8601String(),
      'resultCount': resultCount,
      'appliedFilters': appliedFilters.map((f) => f.toJson()).toList(),
    };
  }

  factory SearchHistoryItem.fromJson(Map<String, dynamic> json) {
    return SearchHistoryItem(
      id: json['id'] ?? '',
      query: json['query'] ?? '',
      searchedAt: DateTime.parse(json['searchedAt']),
      resultCount: json['resultCount'] ?? 0,
      appliedFilters: (json['appliedFilters'] as List?)
              ?.map((f) => SearchFilter.fromJson(f))
              .toList() ??
          [],
    );
  }
}

/// Search suggestions model
class SearchSuggestion {
  final String text;
  final SearchSuggestionType type;
  final int frequency;

  SearchSuggestion({
    required this.text,
    required this.type,
    this.frequency = 1,
  });

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'type': type.toString(),
      'frequency': frequency,
    };
  }

  factory SearchSuggestion.fromJson(Map<String, dynamic> json) {
    return SearchSuggestion(
      text: json['text'] ?? '',
      type: SearchSuggestionType.values.firstWhere(
        (type) => type.toString() == json['type'],
        orElse: () => SearchSuggestionType.general,
      ),
      frequency: json['frequency'] ?? 1,
    );
  }
}

enum SearchSuggestionType {
  general,
  name,
  skill,
  department,
  program,
}

/// Search configuration model
class SearchConfig {
  final bool enableRealTimeSearch;
  final int searchDebounceMs;
  final int maxSearchHistory;
  final int maxSuggestions;
  final bool enableSearchAnalytics;

  const SearchConfig({
    this.enableRealTimeSearch = true,
    this.searchDebounceMs = 300,
    this.maxSearchHistory = 20,
    this.maxSuggestions = 10,
    this.enableSearchAnalytics = false,
  });
}

/// Filter categories enum
enum FilterCategory {
  role,
  department,
  skills,
  semester,
  program,
  personalAdvisor, // NEW: PAK filter
  kokurikulum, // NEW: Kokurikulum filter
}

/// Search analytics event model
class SearchAnalyticsEvent {
  final String id;
  final SearchEventType type;
  final String? query;
  final int? resultCount;
  final Duration? searchDuration;
  final List<SearchFilter>? appliedFilters;
  final SearchInteractionType? interactionType;
  final String? resultUserId;
  final DateTime timestamp;
  final String? userId;

  SearchAnalyticsEvent({
    required this.id,
    required this.type,
    this.query,
    this.resultCount,
    this.searchDuration,
    this.appliedFilters,
    this.interactionType,
    this.resultUserId,
    required this.timestamp,
    this.userId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'query': query,
      'resultCount': resultCount,
      'searchDuration': searchDuration?.inMilliseconds,
      'appliedFilters': appliedFilters?.map((f) => f.toJson()).toList(),
      'interactionType': interactionType?.name,
      'resultUserId': resultUserId,
      'timestamp': timestamp.toIso8601String(),
      'userId': userId,
    };
  }

  factory SearchAnalyticsEvent.fromJson(Map<String, dynamic> json) {
    return SearchAnalyticsEvent(
      id: json['id'] ?? '',
      type: SearchEventType.values.firstWhere(
        (type) => type.name == json['type'],
        orElse: () => SearchEventType.search,
      ),
      query: json['query'],
      resultCount: json['resultCount'],
      searchDuration: json['searchDuration'] != null
          ? Duration(milliseconds: json['searchDuration'])
          : null,
      appliedFilters: (json['appliedFilters'] as List?)
          ?.map((f) => SearchFilter.fromJson(f))
          .toList(),
      interactionType: json['interactionType'] != null
          ? SearchInteractionType.values.firstWhere(
              (type) => type.name == json['interactionType'],
              orElse: () => SearchInteractionType.view,
            )
          : null,
      resultUserId: json['resultUserId'],
      timestamp: DateTime.parse(json['timestamp']),
      userId: json['userId'],
    );
  }
}

enum SearchEventType {
  search,
  interaction,
  filter,
}

enum SearchInteractionType {
  view,
  message,
  share,
  bookmark,
}

/// Popular search term model
class PopularSearchTerm {
  final String term;
  final int frequency;
  final double averageRelevance;
  final DateTime? lastSearched;

  PopularSearchTerm({
    required this.term,
    required this.frequency,
    required this.averageRelevance,
    this.lastSearched,
  });

  Map<String, dynamic> toJson() {
    return {
      'term': term,
      'frequency': frequency,
      'averageRelevance': averageRelevance,
      'lastSearched': lastSearched?.toIso8601String(),
    };
  }

  factory PopularSearchTerm.fromJson(Map<String, dynamic> json) {
    return PopularSearchTerm(
      term: json['term'] ?? '',
      frequency: json['frequency'] ?? 0,
      averageRelevance: (json['averageRelevance'] ?? 0.0).toDouble(),
      lastSearched: json['lastSearched'] != null
          ? DateTime.parse(json['lastSearched'])
          : null,
    );
  }
}

/// Search performance metrics model
class SearchPerformanceMetrics {
  final int totalSearches;
  final Duration averageSearchDuration;
  final double averageResultCount;
  final double searchSuccessRate;
  final List<String> popularFilters;

  SearchPerformanceMetrics({
    required this.totalSearches,
    required this.averageSearchDuration,
    required this.averageResultCount,
    required this.searchSuccessRate,
    required this.popularFilters,
  });

  Map<String, dynamic> toJson() {
    return {
      'totalSearches': totalSearches,
      'averageSearchDuration': averageSearchDuration.inMilliseconds,
      'averageResultCount': averageResultCount,
      'searchSuccessRate': searchSuccessRate,
      'popularFilters': popularFilters,
    };
  }

  factory SearchPerformanceMetrics.fromJson(Map<String, dynamic> json) {
    return SearchPerformanceMetrics(
      totalSearches: json['totalSearches'] ?? 0,
      averageSearchDuration: Duration(
        milliseconds: json['averageSearchDuration'] ?? 0,
      ),
      averageResultCount: (json['averageResultCount'] ?? 0.0).toDouble(),
      searchSuccessRate: (json['searchSuccessRate'] ?? 0.0).toDouble(),
      popularFilters: List<String>.from(json['popularFilters'] ?? []),
    );
  }
}

/// User engagement metrics model
class UserEngagementMetrics {
  final double clickThroughRate;
  final Duration averageSessionDuration;
  final Map<SearchInteractionType, int> topInteractionTypes;
  final int totalInteractions;

  UserEngagementMetrics({
    required this.clickThroughRate,
    required this.averageSessionDuration,
    required this.topInteractionTypes,
    required this.totalInteractions,
  });

  Map<String, dynamic> toJson() {
    return {
      'clickThroughRate': clickThroughRate,
      'averageSessionDuration': averageSessionDuration.inMilliseconds,
      'topInteractionTypes': topInteractionTypes.map(
        (key, value) => MapEntry(key.name, value),
      ),
      'totalInteractions': totalInteractions,
    };
  }

  factory UserEngagementMetrics.fromJson(Map<String, dynamic> json) {
    final interactionTypes = <SearchInteractionType, int>{};
    final rawTypes = json['topInteractionTypes'] as Map<String, dynamic>? ?? {};

    for (final entry in rawTypes.entries) {
      final type = SearchInteractionType.values.firstWhere(
        (t) => t.name == entry.key,
        orElse: () => SearchInteractionType.view,
      );
      interactionTypes[type] = entry.value as int;
    }

    return UserEngagementMetrics(
      clickThroughRate: (json['clickThroughRate'] ?? 0.0).toDouble(),
      averageSessionDuration: Duration(
        milliseconds: json['averageSessionDuration'] ?? 0,
      ),
      topInteractionTypes: interactionTypes,
      totalInteractions: json['totalInteractions'] ?? 0,
    );
  }
}

extension FilterCategoryExtension on FilterCategory {
  String get displayName {
    switch (this) {
      case FilterCategory.role:
        return 'Role';
      case FilterCategory.department:
        return 'Department';
      case FilterCategory.skills:
        return 'Skills';
      case FilterCategory.semester:
        return 'Semester';
      case FilterCategory.program:
        return 'Program';
      case FilterCategory.personalAdvisor:
        return 'Penasihat Akademik';
      case FilterCategory.kokurikulum:
        return 'Kokurikulum';
    }
  }
}

/// Cached search result model
class CachedSearchResult {
  final String query;
  final List<SearchFilter> filters;
  final List<SearchResult> results;
  final DateTime timestamp;
  final bool isPopular;
  int accessCount;
  DateTime? lastAccessed;

  CachedSearchResult({
    required this.query,
    required this.filters,
    required this.results,
    required this.timestamp,
    this.isPopular = false,
    this.accessCount = 0,
    this.lastAccessed,
  });

  Map<String, dynamic> toJson() {
    return {
      'query': query,
      'filters': filters.map((f) => f.toJson()).toList(),
      'results': results.map((r) => r.toJson()).toList(),
      'timestamp': timestamp.toIso8601String(),
      'isPopular': isPopular,
      'accessCount': accessCount,
      'lastAccessed': lastAccessed?.toIso8601String(),
    };
  }

  factory CachedSearchResult.fromJson(Map<String, dynamic> json) {
    return CachedSearchResult(
      query: json['query'] ?? '',
      filters: (json['filters'] as List?)
              ?.map((f) => SearchFilter.fromJson(f))
              .toList() ??
          [],
      results: (json['results'] as List?)
              ?.map((r) => SearchResult.fromJson(r))
              .toList() ??
          [],
      timestamp: DateTime.parse(json['timestamp']),
      isPopular: json['isPopular'] ?? false,
      accessCount: json['accessCount'] ?? 0,
      lastAccessed: json['lastAccessed'] != null
          ? DateTime.parse(json['lastAccessed'])
          : null,
    );
  }
}

/// Offline search request model
class OfflineSearchRequest {
  final String query;
  final List<SearchFilter> filters;
  final DateTime timestamp;

  OfflineSearchRequest({
    required this.query,
    required this.filters,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'query': query,
      'filters': filters.map((f) => f.toJson()).toList(),
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory OfflineSearchRequest.fromJson(Map<String, dynamic> json) {
    return OfflineSearchRequest(
      query: json['query'] ?? '',
      filters: (json['filters'] as List?)
              ?.map((f) => SearchFilter.fromJson(f))
              .toList() ??
          [],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

/// Cache statistics model
class CacheStatistics {
  final int totalEntries;
  final int totalResults;
  final int popularEntries;
  final int memoryEntries;
  final int queuedSearches;
  final bool isOnline;

  CacheStatistics({
    required this.totalEntries,
    required this.totalResults,
    required this.popularEntries,
    required this.memoryEntries,
    required this.queuedSearches,
    required this.isOnline,
  });

  Map<String, dynamic> toJson() {
    return {
      'totalEntries': totalEntries,
      'totalResults': totalResults,
      'popularEntries': popularEntries,
      'memoryEntries': memoryEntries,
      'queuedSearches': queuedSearches,
      'isOnline': isOnline,
    };
  }

  factory CacheStatistics.fromJson(Map<String, dynamic> json) {
    return CacheStatistics(
      totalEntries: json['totalEntries'] ?? 0,
      totalResults: json['totalResults'] ?? 0,
      popularEntries: json['popularEntries'] ?? 0,
      memoryEntries: json['memoryEntries'] ?? 0,
      queuedSearches: json['queuedSearches'] ?? 0,
      isOnline: json['isOnline'] ?? true,
    );
  }
}
