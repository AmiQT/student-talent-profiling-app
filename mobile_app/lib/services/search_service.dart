import '../config/app_config.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/profile_model.dart';
import '../models/search_models.dart';
import '../models/academic_info_model.dart';
import '../models/experience_model.dart';
import '../models/project_model.dart';
import '../services/profile_service.dart';
import '../services/supabase_auth_service.dart';
import 'search_analytics_service.dart';
import 'search_cache_service.dart';
import '../config/supabase_config.dart';

class SearchService {
  static String get baseUrl => AppConfig.backendUrl; // Use stable backend URL

  final ProfileService _profileService = ProfileService();
  final SupabaseAuthService _authService = SupabaseAuthService();
  final SearchAnalyticsService _analyticsService = SearchAnalyticsService();
  final SearchCacheService _cacheService = SearchCacheService();

  static const String _searchHistoryKey = 'search_history';
  static const String _savedFiltersKey = 'saved_filters';

  final SearchConfig config = const SearchConfig();

  // Cache for search results and suggestions
  final Map<String, List<SearchResult>> _searchCache = {};
  final Map<String, List<SearchSuggestion>> _suggestionCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};

  // Cache duration (5 minutes)
  static const Duration _cacheDuration = Duration(minutes: 5);

  // Popular search terms for suggestions
  List<String> _popularSearchTerms = [];
  List<String> _allUserNames = [];
  List<String> _allSkills = [];
  List<String> _allDepartments = [];

  /// Search users and profiles with advanced filtering
  Future<List<SearchResult>> searchUsersAndProfiles({
    required String query,
    List<SearchFilter> filters = const [],
    int limit = 50,
    String? userId,
  }) async {
    final startTime = DateTime.now();

    try {
      // Check cache first
      final cachedResults = await _cacheService.getCachedResults(
        query: query,
        filters: filters,
      );

      if (cachedResults != null) {
        return cachedResults;
      }

      // Check if online for fresh search
      final isOnline = await _cacheService.isOnline();
      if (!isOnline) {
        // Queue search for when back online
        await _cacheService.queueOfflineSearch(
          query: query,
          filters: filters,
        );

        // Return popular results for offline experience
        final popularResults = await _cacheService.getPopularResults();
        debugPrint(
            'SearchService: Offline - returning ${popularResults.length} popular results');
        return popularResults;
      }

      // Check authentication state
      final currentUser = SupabaseConfig.auth.currentUser;
      if (currentUser == null) {
        debugPrint(
            'SearchService: User not authenticated, cannot search users');
        return [];
      }
      debugPrint('SearchService: User authenticated as: ${currentUser.id}');

      // Minimal delay for auth state propagation
      await Future.delayed(const Duration(milliseconds: 50));

      // Get all profiles directly (optimized - single query)
      debugPrint(
          'SearchService: Attempting to get all profiles via AuthService...');
      final allProfiles = await _authService.getAllUsersWithProfiles();
      debugPrint(
          'SearchService: Successfully retrieved ${allProfiles.length} profiles');

      if (allProfiles.isEmpty) {
        debugPrint(
            'SearchService: No profiles returned from backend. Check profiles table or RLS policies.');
      }

      List<SearchResult> results = [];

      // Filter profiles to only include students and lecturers
      final filteredProfiles = allProfiles
          .where((profileData) {
            // Ensure we have at least a name or valid profile
            if (profileData['full_name'] == null ||
                profileData['full_name'].toString().isEmpty) {
              // If no name, check if we have a user_id at least
              if (profileData['user_id'] == null) return false;
            }
            return true;
          })
          .take(limit)
          .toList();

      debugPrint(
          'SearchService: Processing ${filteredProfiles.length} profiles after initial filtering');

      for (final profileData in filteredProfiles) {
        try {
          // Convert profile data to UserModel
          final user = UserModel(
            id: profileData['user_id'] ?? '',
            uid: profileData['user_id'] ?? '',
            email: profileData['email'] ?? '',
            name: profileData['full_name'] ?? 'User',
            role: _getRoleFromProfileData(profileData),
            studentId: profileData['academic_info']?['studentId'] ??
                profileData['academic_info']?['student_id'],
            department: profileData['academic_info']?['department'] ??
                profileData['academic_info']?['faculty'],
            createdAt: profileData['created_at'] != null
                ? DateTime.parse(profileData['created_at'])
                : DateTime.now(),
            lastLoginAt: null,
            isActive: true,
            profileCompleted: profileData['is_profile_complete'] ?? false,
          );

          // Create profile object from data (no additional API calls)
          final profile = _createProfileFromData(profileData);

          // Calculate relevance score
          final relevanceScore = _calculateRelevanceScore(query, user, profile);
          final matchedFields = _getMatchedFields(query, user, profile);

          // Apply filters
          if (_passesFilters(user, profile, filters)) {
            // Only add if it matches the query (score > 0) OR query is empty (showing all)
            if (query.isEmpty || relevanceScore > 0) {
              // Debug: Log when we add a result
              if (query.isNotEmpty) {
                debugPrint(
                    'SearchService: Match found - User: ${user.name}, Score: $relevanceScore');
              }

              results.add(SearchResult(
                user: user,
                profile: profile,
                relevanceScore: relevanceScore,
                matchedFields: matchedFields,
              ));
            } else {
              // Debug: Log why it was skipped
              // debugPrint('SearchService: Skipped user ${user.name} - Score: 0');
            }
          }
        } catch (e) {
          debugPrint(
              'SearchService: Error processing profile ${profileData['full_name']}: $e');
          continue;
        }
      }

      // Sort by relevance score (highest first)
      results.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));

      // Debug: Log final results for troubleshooting
      if (query.toLowerCase().contains('web') ||
          query.toLowerCase().contains('development')) {
        debugPrint('SearchService: Final results count: ${results.length}');
        for (final result in results) {
          debugPrint(
              'SearchService: Result - User: ${result.user.name}, Score: ${result.relevanceScore}, Fields: ${result.matchedFields}');
        }
      }

      // Save search to history
      if (query.isNotEmpty) {
        await _saveSearchToHistory(query, results.length, filters);
      }

      // Cache results for future use
      await _cacheService.cacheSearchResults(
        query: query,
        filters: filters,
        results: results,
        isPopular: results.length > 5, // Consider popular if many results
      );

      // Track analytics
      final searchDuration = DateTime.now().difference(startTime);
      await _analyticsService.trackSearch(
        query: query,
        results: results,
        searchDuration: searchDuration,
        appliedFilters: filters,
        userId: userId,
      );

      debugPrint(
          'SearchService: Found ${results.length} results in ${searchDuration.inMilliseconds}ms');
      return results;
    } catch (e) {
      // Handle permission errors gracefully - these are expected with security rules
      if (e.toString().contains('permission-denied')) {
        debugPrint(
            'SearchService: Permission denied - security rules working correctly');
        return []; // Return empty results instead of showing error to user
      }
      debugPrint('SearchService: Error searching: $e');
      return [];
    }
  }

  /// Initialize search data for better performance
  Future<void> initializeSearchData() async {
    try {
      // Load popular search terms and user data for suggestions
      await _loadPopularSearchTerms();
      await _loadUserDataForSuggestions();

      // Initialize analytics
      await _analyticsService.loadAnalyticsData();

      // Initialize cache
      await _cacheService.loadOfflineQueue();

      // Cache popular results for offline use
      await _cachePopularResultsForOffline();
    } catch (e) {
      debugPrint('SearchService: Error initializing search data: $e');
    }
  }

  /// Get real-time search suggestions as user types
  Future<List<SearchSuggestion>> getSearchSuggestions(String query) async {
    if (query.isEmpty) return [];

    final cacheKey = 'suggestions_$query';

    // Check cache first
    if (_suggestionCache.containsKey(cacheKey) && _isCacheValid(cacheKey)) {
      return _suggestionCache[cacheKey]!;
    }

    try {
      final suggestions = <SearchSuggestion>[];
      final q = query.toLowerCase();

      // Name suggestions
      for (final name in _allUserNames) {
        if (name.toLowerCase().contains(q) && suggestions.length < 5) {
          suggestions.add(SearchSuggestion(
            text: name,
            type: SearchSuggestionType.name,
            frequency: _getSearchFrequency(name),
          ));
        }
      }

      // Skill suggestions
      for (final skill in _allSkills) {
        if (skill.toLowerCase().contains(q) && suggestions.length < 8) {
          suggestions.add(SearchSuggestion(
            text: skill,
            type: SearchSuggestionType.skill,
            frequency: _getSearchFrequency(skill),
          ));
        }
      }

      // Department suggestions
      for (final dept in _allDepartments) {
        if (dept.toLowerCase().contains(q) && suggestions.length < 10) {
          suggestions.add(SearchSuggestion(
            text: dept,
            type: SearchSuggestionType.department,
            frequency: _getSearchFrequency(dept),
          ));
        }
      }

      // Sort by frequency and relevance
      suggestions.sort((a, b) => b.frequency.compareTo(a.frequency));

      // Cache the results
      _suggestionCache[cacheKey] = suggestions;
      _cacheTimestamps[cacheKey] = DateTime.now();

      return suggestions;
    } catch (e) {
      debugPrint('SearchService: Error getting suggestions: $e');
      return [];
    }
  }

  /// Calculate fuzzy match score between query and target string
  /// Returns a score between 0.0 and 1.0 based on word overlap
  double _fuzzyMatchScore(String query, String target) {
    if (query.isEmpty || target.isEmpty) return 0.0;

    // Normalize strings: lowercase and split into words
    final queryWords = query.toLowerCase().split(RegExp(r'[\s\-_/]+'));
    final targetWords = target.toLowerCase().split(RegExp(r'[\s\-_/]+'));

    if (queryWords.isEmpty || targetWords.isEmpty) return 0.0;

    int matchingWords = 0;
    int partialMatches = 0;

    for (final qWord in queryWords) {
      if (qWord.length < 2) continue; // Skip very short words

      for (final tWord in targetWords) {
        // Exact word match
        if (qWord == tWord) {
          matchingWords += 2;
          break;
        }
        // Word starts with query word (e.g., "web" matches "webdev")
        else if (tWord.startsWith(qWord) || qWord.startsWith(tWord)) {
          matchingWords += 1;
          break;
        }
        // Word contains query word (partial match)
        else if (tWord.contains(qWord) || qWord.contains(tWord)) {
          partialMatches += 1;
          break;
        }
      }
    }

    // Calculate score based on matches
    final totalQueryWords = queryWords.where((w) => w.length >= 2).length;
    if (totalQueryWords == 0) return 0.0;

    // Full matches worth more than partial
    double score =
        (matchingWords * 1.0 + partialMatches * 0.5) / (totalQueryWords * 2);
    return score.clamp(0.0, 1.0);
  }

  /// Calculate relevance score for search result - IMPROVED with fuzzy matching
  double _calculateRelevanceScore(
      String query, UserModel user, ProfileModel? profile) {
    if (query.isEmpty) return 1.0;

    final q = query.toLowerCase();
    double score = 0.0;

    // Name matches (highest priority)
    if (user.name.toLowerCase().contains(q)) score += 10.0;
    if (profile?.fullName.toLowerCase().contains(q) == true) score += 10.0;

    // Exact name match bonus
    if (user.name.toLowerCase() == q) score += 20.0;
    if (profile?.fullName.toLowerCase() == q) score += 20.0;

    // Bio and headline matches - use fuzzy matching
    if (profile?.bio != null) {
      final bioScore = _fuzzyMatchScore(q, profile!.bio!);
      score += bioScore * 8.0; // Up to 8 points for bio match
    }
    if (profile?.headline != null) {
      final headlineScore = _fuzzyMatchScore(q, profile!.headline!);
      score += headlineScore * 10.0; // Up to 10 points for headline match
    }

    // ✅ IMPROVED: Skills matches with fuzzy matching
    double skillScore = 0.0;
    if (profile?.skills.isNotEmpty == true) {
      for (final skill in profile!.skills) {
        final fuzzyScore = _fuzzyMatchScore(q, skill);

        // Also check if any query word matches skill
        final queryWords = q.split(RegExp(r'[\s\-_/]+'));
        bool hasDirectMatch = false;
        for (final word in queryWords) {
          if (word.length >= 3 && skill.toLowerCase().contains(word)) {
            hasDirectMatch = true;
            break;
          }
        }

        if (fuzzyScore > 0.3) {
          // Good fuzzy match
          skillScore += fuzzyScore * 8.0;
        } else if (hasDirectMatch) {
          // Direct word match
          skillScore += 4.0;
        }
      }
    }
    score += skillScore;

    // ✅ IMPROVED: Interests matches with fuzzy matching
    double interestScore = 0.0;
    if (profile?.interests.isNotEmpty == true) {
      for (final interest in profile!.interests) {
        final fuzzyScore = _fuzzyMatchScore(q, interest);
        if (fuzzyScore > 0.3) {
          interestScore += fuzzyScore * 6.0;
        }
      }
    }
    score += interestScore;

    // Department matches
    if (user.department?.toLowerCase().contains(q) == true) score += 4.0;
    if (profile?.academicInfo?.department.toLowerCase().contains(q) == true) {
      score += 4.0;
    }

    // Program matches
    if (profile?.academicInfo?.program.toLowerCase().contains(q) == true) {
      score += 3.0;
    }

    // Student ID matches
    if (user.studentId?.toLowerCase().contains(q) == true) score += 6.0;
    if (profile?.academicInfo?.studentId.toLowerCase().contains(q) == true) {
      score += 6.0;
    }

    // PAK (Personal Advisor) matches - NEW
    if (profile?.academicInfo?.personalAdvisor?.toLowerCase().contains(q) ==
        true) {
      score += 8.0; // High priority for PAK search
    }
    // Check for "PAK" keyword in query
    if (q.contains('pak ') || q.startsWith('pak')) {
      final pakQuery =
          q.replaceFirst('pak ', '').replaceFirst('pak', '').trim();
      if (pakQuery.isNotEmpty &&
          profile?.academicInfo?.personalAdvisor
                  ?.toLowerCase()
                  .contains(pakQuery) ==
              true) {
        score += 15.0; // Very high priority when explicitly searching for PAK
      }
    }

    // Experience and project matches with fuzzy matching
    if (profile?.experiences.isNotEmpty == true) {
      for (final exp in profile!.experiences) {
        final titleScore = _fuzzyMatchScore(q, exp.title);
        final descScore = _fuzzyMatchScore(q, exp.description);
        score += (titleScore + descScore) * 3.0;
      }
    }

    if (profile?.projects.isNotEmpty == true) {
      for (final proj in profile!.projects) {
        final titleScore = _fuzzyMatchScore(q, proj.title);
        final descScore = _fuzzyMatchScore(q, proj.description);
        score += (titleScore + descScore) * 3.0;
      }
    }

    // Profile completeness bonus
    if (profile != null) {
      final completeness = _getProfileCompleteness(profile);
      score += completeness * 0.1; // Small bonus for complete profiles
    }

    return score;
  }

  /// Get fields that matched the search query
  List<String> _getMatchedFields(
      String query, UserModel user, ProfileModel? profile) {
    if (query.isEmpty) return [];

    final q = query.toLowerCase();
    List<String> matchedFields = [];

    if (user.name.toLowerCase().contains(q)) matchedFields.add('name');
    if (profile?.fullName.toLowerCase().contains(q) == true) {
      matchedFields.add('fullName');
    }
    if (profile?.bio?.toLowerCase().contains(q) == true) {
      matchedFields.add('bio');
    }
    if (profile?.headline?.toLowerCase().contains(q) == true) {
      matchedFields.add('headline');
    }
    if (user.department?.toLowerCase().contains(q) == true) {
      matchedFields.add('department');
    }
    if (user.studentId?.toLowerCase().contains(q) == true) {
      matchedFields.add('studentId');
    }

    // PAK (Personal Advisor) matches - NEW
    if (profile?.academicInfo?.personalAdvisor?.toLowerCase().contains(q) ==
        true) {
      matchedFields.add('personalAdvisor');
    }
    // Check for "PAK" keyword in query
    if (q.contains('pak ') || q.startsWith('pak')) {
      final pakQuery =
          q.replaceFirst('pak ', '').replaceFirst('pak', '').trim();
      if (pakQuery.isNotEmpty &&
          profile?.academicInfo?.personalAdvisor
                  ?.toLowerCase()
                  .contains(pakQuery) ==
              true) {
        matchedFields.add('personalAdvisor');
      }
    }

    // Check skills - improved matching logic
    if (profile?.skills.isNotEmpty == true) {
      for (final skill in profile!.skills) {
        final skillLower = skill.toLowerCase();
        final qLower = q.toLowerCase();

        // Check for exact match, contains match, or partial word match
        if (skillLower == qLower ||
            skillLower.contains(qLower) ||
            qLower.split(' ').any((word) => skillLower.contains(word))) {
          matchedFields.add('skills');
          break; // Found a match, no need to check more skills
        }
      }
    }

    // Check interests
    if (profile?.interests
            .any((interest) => interest.toLowerCase().contains(q)) ==
        true) {
      matchedFields.add('interests');
    }

    return matchedFields;
  }

  /// Check if result passes all applied filters
  bool _passesFilters(
      UserModel user, ProfileModel? profile, List<SearchFilter> filters) {
    // Debug: Log filter checking
    final selectedFilters = filters.where((f) => f.isSelected).toList();
    if (selectedFilters.isNotEmpty) {
      debugPrint(
          'SearchService: Checking filters for user ${user.name}: ${selectedFilters.map((f) => '${f.category}:${f.name}').join(', ')}');
    }

    for (final filter in selectedFilters) {
      switch (filter.category) {
        case 'role':
          if (user.role.toString().split('.').last != filter.id) return false;
          break;
        case 'department':
          final userDept = user.department ?? '';
          final profileDept = profile?.academicInfo?.department ?? '';
          if (!userDept.contains(filter.name) &&
              !profileDept.contains(filter.name)) {
            return false;
          }
          break;
        case 'skills':
          // Use case-insensitive matching for skills
          final hasMatchingSkill = profile?.skills.any((skill) =>
                  skill.toLowerCase() == filter.name.toLowerCase() ||
                  skill.toLowerCase().contains(filter.name.toLowerCase()) ||
                  filter.name
                      .toLowerCase()
                      .split(' ')
                      .any((word) => skill.toLowerCase().contains(word))) ??
              false;

          // Debug: Log skills filter checking
          debugPrint(
              'SearchService: Skills filter - User: ${user.name}, Filter: ${filter.name}, Skills: ${profile?.skills}, Match: $hasMatchingSkill');

          if (!hasMatchingSkill) return false;
          break;
        case 'semester':
          if (profile?.academicInfo?.currentSemester.toString() != filter.id) {
            return false;
          }
          break;
        case 'program':
          if (profile?.academicInfo?.program != filter.name) return false;
          break;
      }
    }
    return true;
  }

  /// Get profile completeness percentage
  double _getProfileCompleteness(ProfileModel profile) {
    int totalFields = 10;
    int completedFields = 0;

    if (profile.fullName.isNotEmpty) completedFields++;
    if (profile.bio != null && profile.bio!.isNotEmpty) completedFields++;
    if (profile.headline != null && profile.headline!.isNotEmpty) {
      completedFields++;
    }
    if (profile.profileImageUrl != null &&
        profile.profileImageUrl!.isNotEmpty) {
      completedFields++;
    }
    if (profile.skills.isNotEmpty) completedFields++;
    if (profile.interests.isNotEmpty) completedFields++;
    if (profile.experiences.isNotEmpty) completedFields++;
    if (profile.projects.isNotEmpty) completedFields++;
    if (profile.achievements.isNotEmpty) completedFields++;
    if (profile.academicInfo != null) completedFields++;

    return (completedFields / totalFields) * 100;
  }

  /// Save search to history
  Future<void> _saveSearchToHistory(
      String query, int resultCount, List<SearchFilter> filters) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_searchHistoryKey) ?? '[]';
      final historyList = jsonDecode(historyJson) as List;

      final historyItems =
          historyList.map((item) => SearchHistoryItem.fromJson(item)).toList();

      // Remove existing entry with same query
      historyItems.removeWhere((item) => item.query == query);

      // Add new entry at the beginning
      historyItems.insert(
          0,
          SearchHistoryItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            query: query,
            searchedAt: DateTime.now(),
            resultCount: resultCount,
            appliedFilters: filters.where((f) => f.isSelected).toList(),
          ));

      // Keep only recent items
      if (historyItems.length > config.maxSearchHistory) {
        historyItems.removeRange(config.maxSearchHistory, historyItems.length);
      }

      // Save back to preferences
      final updatedJson =
          jsonEncode(historyItems.map((item) => item.toJson()).toList());
      await prefs.setString(_searchHistoryKey, updatedJson);
    } catch (e) {
      debugPrint('SearchService: Error saving search history: $e');
    }
  }

  /// Get search history
  Future<List<SearchHistoryItem>> getSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_searchHistoryKey) ?? '[]';
      final historyList = jsonDecode(historyJson) as List;

      return historyList
          .map((item) => SearchHistoryItem.fromJson(item))
          .toList();
    } catch (e) {
      debugPrint('SearchService: Error loading search history: $e');
      return [];
    }
  }

  /// Clear search history
  Future<void> clearSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_searchHistoryKey);
    } catch (e) {
      debugPrint('SearchService: Error clearing search history: $e');
    }
  }

  /// Get available filters
  Future<Map<String, List<SearchFilter>>> getAvailableFilters() async {
    try {
      // Get all profiles to extract filter options
      final profiles = await _profileService.getAllProfiles();
      final users = await _getAllUsers();

      Map<String, List<SearchFilter>> filters = {};

      // Role filters
      filters['role'] = [
        SearchFilter(id: 'student', name: 'Student', category: 'role'),
        SearchFilter(id: 'lecturer', name: 'Lecturer', category: 'role'),
      ];

      // Department filters
      final departments = <String>{};
      for (final user in users) {
        if (user.department != null) departments.add(user.department!);
      }
      for (final profile in profiles) {
        if (profile.academicInfo?.department != null) {
          departments.add(profile.academicInfo!.department);
        }
      }
      filters['department'] = departments
          .map((dept) =>
              SearchFilter(id: dept, name: dept, category: 'department'))
          .toList();

      // Skills filters (top 20 most common)
      final skillCounts = <String, int>{};
      for (final profile in profiles) {
        for (final skill in profile.skills) {
          skillCounts[skill] = (skillCounts[skill] ?? 0) + 1;
        }
      }
      final topSkills = skillCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      filters['skills'] = topSkills
          .take(20)
          .map((entry) =>
              SearchFilter(id: entry.key, name: entry.key, category: 'skills'))
          .toList();

      // Semester filters
      final semesters = <int>{};
      for (final profile in profiles) {
        if (profile.academicInfo?.currentSemester != null) {
          semesters.add(profile.academicInfo!.currentSemester);
        }
      }
      filters['semester'] = semesters
          .map((sem) => SearchFilter(
              id: sem.toString(), name: 'Semester $sem', category: 'semester'))
          .toList()
        ..sort((a, b) => int.parse(a.id).compareTo(int.parse(b.id)));

      // Program filters
      final programs = <String>{};
      for (final profile in profiles) {
        if (profile.academicInfo?.program != null) {
          programs.add(profile.academicInfo!.program);
        }
      }
      filters['program'] = programs
          .map(
              (prog) => SearchFilter(id: prog, name: prog, category: 'program'))
          .toList();

      return filters;
    } catch (e) {
      debugPrint('SearchService: Error getting available filters: $e');
      return {};
    }
  }

  /// Get all users (students and lecturers only)
  Future<List<UserModel>> _getAllUsers() async {
    try {
      // Use AuthService which has working permissions

      final allUsers = await _authService.getAllUsers();

      // Filter users to only include students and lecturers who are active
      final filteredUsers = allUsers.where((user) {
        final role = user.role.toString().split('.').last;
        return user.isActive && (role == 'student' || role == 'lecturer');
      }).toList();

      return filteredUsers;
    } catch (e) {
      debugPrint('SearchService: Error getting all users: $e');
      return [];
    }
  }

  /// Load popular search terms from history
  Future<void> _loadPopularSearchTerms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_searchHistoryKey);
      if (historyJson != null) {
        final List<dynamic> historyList = json.decode(historyJson);
        final history = historyList
            .map((item) => SearchHistoryItem.fromJson(item))
            .toList();

        // Extract popular terms
        final termFrequency = <String, int>{};
        for (final item in history) {
          termFrequency[item.query] = (termFrequency[item.query] ?? 0) + 1;
        }

        _popularSearchTerms = termFrequency.entries
            .where((entry) => entry.value > 1)
            .map((entry) => entry.key)
            .toList();
      }
    } catch (e) {
      debugPrint('SearchService: Error loading popular search terms: $e');
    }
  }

  /// Load user data for suggestions
  Future<void> _loadUserDataForSuggestions() async {
    try {
      final users = await _getAllUsers();
      final profiles = await _profileService.getAllProfiles();

      // Extract names
      _allUserNames = users.map((user) => user.name).toList();
      for (final profile in profiles) {
        if (profile.fullName.isNotEmpty) {
          _allUserNames.add(profile.fullName);
        }
      }

      // Extract skills
      final skillsSet = <String>{};
      for (final profile in profiles) {
        skillsSet.addAll(profile.skills);
      }
      _allSkills = skillsSet.toList();

      // Extract departments
      final deptSet = <String>{};
      for (final user in users) {
        if (user.department != null) {
          deptSet.add(user.department!);
        }
      }
      for (final profile in profiles) {
        if (profile.academicInfo?.department != null) {
          deptSet.add(profile.academicInfo!.department);
        }
      }
      _allDepartments = deptSet.toList();
    } catch (e) {
      debugPrint('SearchService: Error loading user data for suggestions: $e');
    }
  }

  /// Check if cache is still valid
  bool _isCacheValid(String cacheKey) {
    final timestamp = _cacheTimestamps[cacheKey];
    if (timestamp == null) return false;

    return DateTime.now().difference(timestamp) < _cacheDuration;
  }

  /// Get search frequency for a term
  int _getSearchFrequency(String term) {
    // Simple frequency based on popular terms
    if (_popularSearchTerms.contains(term)) {
      return _popularSearchTerms.indexOf(term) + 5;
    }
    return 1;
  }

  /// Clear search cache
  void clearCache() {
    _searchCache.clear();
    _suggestionCache.clear();
    _cacheTimestamps.clear();
  }

  /// Track user interaction with search result
  Future<void> trackResultInteraction({
    required String query,
    required SearchResult result,
    required SearchInteractionType interactionType,
    String? userId,
  }) async {
    await _analyticsService.trackResultInteraction(
      query: query,
      result: result,
      interactionType: interactionType,
      userId: userId,
    );
  }

  /// Track filter usage
  Future<void> trackFilterUsage({
    required List<SearchFilter> filters,
    required String query,
    String? userId,
  }) async {
    await _analyticsService.trackFilterUsage(
      filters: filters,
      query: query,
      userId: userId,
    );
  }

  /// Get popular search terms
  List<PopularSearchTerm> getPopularSearchTerms({int limit = 10}) {
    return _analyticsService.getPopularSearchTerms(limit: limit);
  }

  /// Get search performance metrics
  SearchPerformanceMetrics getSearchPerformanceMetrics() {
    return _analyticsService.getPerformanceMetrics();
  }

  /// Get user engagement metrics
  UserEngagementMetrics getUserEngagementMetrics() {
    return _analyticsService.getUserEngagementMetrics();
  }

  /// Cache popular results for offline use
  Future<void> _cachePopularResultsForOffline() async {
    try {
      // Get popular search terms and cache their results
      final popularTerms = getPopularSearchTerms(limit: 5);
      final allPopularResults = <SearchResult>[];

      for (final term in popularTerms) {
        final results = await searchUsersAndProfiles(
          query: term.term,
          filters: [],
          limit: 10,
        );
        allPopularResults.addAll(results);
      }

      // Remove duplicates and cache
      final uniqueResults = <String, SearchResult>{};
      for (final result in allPopularResults) {
        uniqueResults[result.user.id] = result;
      }

      await _cacheService.cachePopularResults(uniqueResults.values.toList());
    } catch (e) {
      debugPrint('SearchService: Error caching popular results: $e');
    }
  }

  /// Get cache statistics
  Future<CacheStatistics> getCacheStatistics() async {
    return await _cacheService.getCacheStatistics();
  }

  /// Check if device is online
  Future<bool> isOnline() async {
    return await _cacheService.isOnline();
  }

  /// Clear all cache data
  Future<void> clearAllCache() async {
    await _cacheService.clearCache();
    clearCache(); // Clear existing search cache
  }

  /// Save current filter state
  Future<void> saveFilterState(Map<String, List<SearchFilter>> filters) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final filterData = <String, dynamic>{};

      for (final entry in filters.entries) {
        filterData[entry.key] = entry.value.map((f) => f.toJson()).toList();
      }

      await prefs.setString(_savedFiltersKey, json.encode(filterData));
      debugPrint('SearchService: Filter state saved');
    } catch (e) {
      debugPrint('SearchService: Error saving filter state: $e');
    }
  }

  /// Load saved filter state
  Future<Map<String, List<SearchFilter>>> loadFilterState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final filterJson = prefs.getString(_savedFiltersKey);

      if (filterJson != null) {
        final Map<String, dynamic> filterData = json.decode(filterJson);
        final Map<String, List<SearchFilter>> filters = {};

        for (final entry in filterData.entries) {
          final List<dynamic> filterList = entry.value;
          filters[entry.key] =
              filterList.map((f) => SearchFilter.fromJson(f)).toList();
        }

        return filters;
      }
    } catch (e) {
      debugPrint('SearchService: Error loading filter state: $e');
    }

    return {};
  }

  /// Clear saved filter state
  Future<void> clearSavedFilters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_savedFiltersKey);
      debugPrint('SearchService: Saved filters cleared');
    } catch (e) {
      debugPrint('SearchService: Error clearing saved filters: $e');
    }
  }

  /// Get filter presets (commonly used filter combinations)
  List<Map<String, dynamic>> getFilterPresets() {
    return [
      {
        'name': 'Computer Science Students',
        'description': 'Students in Computer Science department',
        'filters': {
          'role': ['student'],
          'department': ['Computer Science'],
        },
      },
      {
        'name': 'Final Year Students',
        'description': 'Students in semester 7-8',
        'filters': {
          'role': ['student'],
          'semester': ['7', '8'],
        },
      },
      {
        'name': 'Programming Skills',
        'description': 'People with programming skills',
        'filters': {
          'skills': ['Python', 'Java', 'JavaScript', 'C++', 'Flutter'],
        },
      },
      {
        'name': 'Lecturers Only',
        'description': 'All lecturers in the system',
        'filters': {
          'role': ['lecturer'],
        },
      },
    ];
  }

  // Helper method to determine role from profile data
  UserRole _getRoleFromProfileData(Map<String, dynamic> profileData) {
    final academicInfo = profileData['academic_info'];
    if (academicInfo != null) {
      if (academicInfo['studentId'] != null ||
          academicInfo['student_id'] != null) {
        return UserRole.student;
      } else if (academicInfo['position'] != null) {
        return UserRole.lecturer;
      }
    }
    // Default to student if can't determine
    return UserRole.student;
  }

  // Helper method to create profile from profile data (optimized)
  ProfileModel? _createProfileFromData(Map<String, dynamic> profileData) {
    try {
      return ProfileModel(
        id: profileData['id'] ?? '',
        userId: profileData['user_id'] ?? '',
        fullName: profileData['full_name'] ?? '',
        bio: profileData['bio'] ?? '',
        phoneNumber: profileData['phone_number'] ?? '',
        address: profileData['address'] ?? '',
        headline: profileData['headline'] ?? '',
        profileImageUrl: profileData['profile_image_url'] ?? '',
        academicInfo: profileData['academic_info'] != null
            ? AcademicInfoModel.fromJson(profileData['academic_info'])
            : null,
        skills: List<String>.from(profileData['skills'] ?? []),
        interests: List<String>.from(profileData['interests'] ?? []),
        experiences: (profileData['experiences'] as List?)
                ?.map((exp) => ExperienceModel.fromJson(exp))
                .toList() ??
            [],
        projects: (profileData['projects'] as List?)
                ?.map((proj) => ProjectModel.fromJson(proj))
                .toList() ??
            [],
        isProfileComplete: profileData['is_profile_complete'] ?? false,
        createdAt: profileData['created_at'] != null
            ? DateTime.parse(profileData['created_at'])
            : DateTime.now(),
        updatedAt: profileData['updated_at'] != null
            ? DateTime.parse(profileData['updated_at'])
            : DateTime.now(),
      );
    } catch (e) {
      debugPrint('SearchService: Error creating profile from data: $e');
      return null;
    }
  }
}
