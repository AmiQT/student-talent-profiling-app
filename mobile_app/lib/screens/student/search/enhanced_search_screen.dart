import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../../../services/search_service.dart';
import '../../../services/supabase_auth_service.dart';
import '../../../models/search_models.dart';
import '../../../widgets/modern/modern_filter_bottom_sheet.dart';
import '../../../utils/app_theme.dart';
import '../../shared/profile_view_screen.dart';
import '../../shared/notifications_screen.dart';
import '../../../widgets/modern/spotlight_result_card.dart';
import '../../../widgets/modern/glass_container.dart';

class EnhancedSearchScreen extends StatefulWidget {
  const EnhancedSearchScreen({super.key});

  @override
  State<EnhancedSearchScreen> createState() => _EnhancedSearchScreenState();
}

class _EnhancedSearchScreenState extends State<EnhancedSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final SearchService _searchService = SearchService();

  Timer? _debounceTimer;
  bool _isLoading = false;
  bool _isInitialLoad = true;

  List<SearchResult> _searchResults = [];
  List<SearchHistoryItem> _searchHistory = [];
  Map<String, List<SearchFilter>> _availableFilters = {};

  String _currentQuery = '';

  // Range filter values
  RangeValues _semesterRange = const RangeValues(1, 8);
  RangeValues _cgpaRange = const RangeValues(0, 4);

  @override
  void initState() {
    super.initState();
    _initializeSearch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// Get current user ID from AuthService
  String? get _currentUserId {
    final authService =
        Provider.of<SupabaseAuthService>(context, listen: false);
    return authService.currentUserId;
  }

  Future<void> _initializeSearch() async {
    setState(() {
      _isInitialLoad = true;
    });

    try {
      // Initialize search data for better performance
      await _searchService.initializeSearchData();

      // Load search history and available filters
      final history = await _searchService.getSearchHistory();
      final filters = await _searchService.getAvailableFilters();

      // Load saved filter state and merge with available filters
      final savedFilters = await _searchService.loadFilterState();
      final mergedFilters = _mergeFilterStates(filters, savedFilters);

      if (mounted) {
        setState(() {
          _searchHistory = history;
          _availableFilters = mergedFilters;
          _isInitialLoad = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitialLoad = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing search: $e')),
        );
      }
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _currentQuery = query;
    });

    // Cancel previous timer
    _debounceTimer?.cancel();

    // Start new timer for debounced search
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (query.isNotEmpty) {
        _performSearch(query);
      } else {
        setState(() {
          _searchResults = [];
        });
      }
    });
  }

  void _onSearchSubmitted(String query) {
    _debounceTimer?.cancel();
    if (query.isNotEmpty) {
      _performSearch(query);
    }
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final selectedFilters = _availableFilters.values
          .expand((filters) => filters)
          .where((filter) => filter.isSelected)
          .toList();

      // Track filter usage if filters are applied
      if (selectedFilters.isNotEmpty) {
        await _searchService.trackFilterUsage(
          filters: _availableFilters.values.expand((f) => f).toList(),
          query: query,
          userId: _currentUserId,
        );
      }

      final results = await _searchService.searchUsersAndProfiles(
        query: query,
        filters: selectedFilters,
        userId: _currentUserId,
      );

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search error: $e')),
        );
      }
    }
  }

  void _onFilterToggle(SearchFilter filter) {
    setState(() {
      final categoryFilters = _availableFilters[filter.category];
      if (categoryFilters != null) {
        final index = categoryFilters.indexWhere((f) => f.id == filter.id);
        if (index != -1) {
          _availableFilters[filter.category]![index] = filter.copyWith(
            isSelected: !filter.isSelected,
          );
        }
      }
    });

    // Save filter state
    _searchService.saveFilterState(_availableFilters);

    // Re-run search if there's a current query
    if (_currentQuery.isNotEmpty) {
      _performSearch(_currentQuery);
    }
  }

  void _clearAllFilters() {
    setState(() {
      for (final category in _availableFilters.keys) {
        _availableFilters[category] = _availableFilters[category]!
            .map((filter) => filter.copyWith(isSelected: false))
            .toList();
      }
      // Reset range values
      _semesterRange = const RangeValues(1, 8);
      _cgpaRange = const RangeValues(0, 4);
    });

    // Re-run search if there's a current query
    if (_currentQuery.isNotEmpty) {
      _performSearch(_currentQuery);
    }
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ModernFilterBottomSheet(
        availableFilters: _availableFilters,
        onFilterToggle: _onFilterToggle,
        onClearAll: _clearAllFilters,
        semesterRange: _semesterRange,
        cgpaRange: _cgpaRange,
        onSemesterRangeChanged: (range) {
          setState(() {
            _semesterRange = range;
          });
        },
        onCgpaRangeChanged: (range) {
          setState(() {
            _cgpaRange = range;
          });
        },
        onApply: () {
          if (_currentQuery.isNotEmpty) {
            _performSearch(_currentQuery);
          }
        },
      ),
    );
  }

  void _navigateToNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NotificationsScreen(),
      ),
    );
  }

  /// Merge available filters with saved filter states
  Map<String, List<SearchFilter>> _mergeFilterStates(
    Map<String, List<SearchFilter>> availableFilters,
    Map<String, List<SearchFilter>> savedFilters,
  ) {
    final mergedFilters = <String, List<SearchFilter>>{};

    for (final entry in availableFilters.entries) {
      final category = entry.key;
      final available = entry.value;
      final saved = savedFilters[category] ?? [];

      // Create a map of saved filter states
      final savedStates = <String, bool>{};
      for (final savedFilter in saved) {
        savedStates[savedFilter.id] = savedFilter.isSelected;
      }

      // Apply saved states to available filters
      final merged = available.map((filter) {
        final savedState = savedStates[filter.id];
        return savedState != null
            ? filter.copyWith(isSelected: savedState)
            : filter;
      }).toList();

      mergedFilters[category] = merged;
    }

    return mergedFilters;
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoad) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Background - Similar to Home
          Positioned.fill(
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
            ),
          ),
          // Ambient Blobs
          Positioned(
            top: -100,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color:
                        Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    blurRadius: 100,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildGlassHeader(context),
                _buildFilterChips(),
                Expanded(
                  child: _buildSearchContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Discover',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Row(
                children: [
                  IconButton(
                      onPressed: _navigateToNotifications,
                      icon: const Icon(Icons.notifications_outlined)),
                ],
              )
            ],
          ),
          const SizedBox(height: 16),
          // Glass Search Bar
          GlassContainer(
            borderRadius: BorderRadius.circular(30),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: 'Search people, skills, roles...',
                border: InputBorder.none,
                prefixIcon:
                    Icon(Icons.search, color: Theme.of(context).primaryColor),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _currentQuery = '';
                            _searchResults.clear();
                          });
                        },
                      )
                    : null,
              ),
              onChanged: _onSearchChanged,
              onSubmitted: _onSearchSubmitted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final activeFilters = _availableFilters.values
        .expand((filters) => filters)
        .where((filter) => filter.isSelected)
        .toList();

    if (activeFilters.isEmpty) {
      return Container(
        height: 50,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            _buildQuickAccessFilter(
              'Lecturers',
              Icons.school,
              isSelected: _isRoleFilterSelected('lecturer'),
              onTap: () => _toggleRoleFilter('lecturer'),
            ),
            _buildQuickAccessFilter(
              'Students',
              Icons.person,
              isSelected: _isRoleFilterSelected('student'),
              onTap: () => _toggleRoleFilter('student'),
            ),
            // Skills filter opens the filter sheet
            _buildQuickAccessFilter('Skills', Icons.star,
                onTap: _showFilterBottomSheet),
            _buildQuickAccessFilter('More', Icons.tune,
                onTap: _showFilterBottomSheet),
          ],
        ),
      );
    }

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: activeFilters.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                label: const Text('Clear'),
                avatar: const Icon(Icons.close, size: 16),
                onPressed: _clearAllFilters,
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
              ),
            );
          }
          final filter = activeFilters[index - 1];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(filter.name),
              onPressed: () => _onFilterToggle(filter),
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickAccessFilter(String label, IconData icon,
      {VoidCallback? onTap, bool isSelected = false}) {
    final theme = Theme.of(context);
    final isSelectedColor = theme.colorScheme.primaryContainer;
    // Use a slightly more opaque background for better visibility
    final defaultColor = theme.colorScheme.surface.withValues(alpha: 0.7);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap ??
            () {
              _showFilterBottomSheet();
            },
        child: GlassContainer(
          borderRadius: BorderRadius.circular(20),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          // Override color if selected
          color: isSelected
              ? isSelectedColor.withValues(alpha: 0.9)
              : defaultColor,
          child: Row(
            children: [
              Icon(icon,
                  size: 16,
                  color: isSelected
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurface,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  bool _isRoleFilterSelected(String roleId) {
    final filters = _availableFilters['role'];
    if (filters == null) return false;
    return filters.any((f) => f.id == roleId && f.isSelected);
  }

  void _toggleRoleFilter(String roleId) {
    final filters = _availableFilters['role'];
    if (filters != null) {
      try {
        final filter = filters.firstWhere((f) => f.id == roleId);
        _onFilterToggle(filter);
      } catch (e) {
        // Filter not found
      }
    }
  }

  Widget _buildSearchContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_currentQuery.isNotEmpty && _searchResults.isEmpty) {
      return _buildEmptyState();
    }

    if (_searchResults.isNotEmpty) {
      return _buildSearchResults();
    }

    return _buildDiscoverContent();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off,
              size: 64, color: Colors.grey.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Text("No results found",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Text("Try adjusting your filters",
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        // Special Spotlight for the first result
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SpotlightResultCard(
              result: result,
              onTap: () => _navigateToProfile(result),
            ),
          );
        }

        // Standard list for others
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassContainer(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Hero(
                tag: 'avatar_mini_${result.user.id}',
                child: CircleAvatar(
                  // ✅ FIX: Check for null AND empty string
                  backgroundImage: result.profileImageUrl != null &&
                          result.profileImageUrl!.isNotEmpty
                      ? NetworkImage(result.profileImageUrl!)
                      : null,
                  child: result.profileImageUrl == null ||
                          result.profileImageUrl!.isEmpty
                      ? Text(result.displayName[0])
                      : null,
                ),
              ),
              title: Text(result.displayName,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(result.headline ?? result.roleDisplay,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => _navigateToProfile(result),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            ),
          ),
        );
      },
    );
  }

  void _navigateToProfile(SearchResult result) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileViewScreen(userId: result.user.id),
      ),
    );
  }

  Widget _buildDiscoverContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_searchHistory.isNotEmpty) _buildRecentSearches(),
          const SizedBox(height: AppTheme.spaceLg),
          _buildTrendingTopics(),
        ],
      ),
    );
  }

  Widget _buildRecentSearches() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Searches',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
            TextButton(
              onPressed: () async {
                // ✅ FIX: Clear history persisted to storage
                await _searchService.clearSearchHistory();
                setState(() {
                  _searchHistory.clear();
                });
              },
              child: const Text('Clear All'),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spaceSm),
        ...(_searchHistory.take(5).map((item) => _buildRecentSearchItem(item))),
      ],
    );
  }

  Widget _buildRecentSearchItem(SearchHistoryItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceXs),
      child: ListTile(
        leading: Icon(
          Icons.history_rounded,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        title: Text(item.query),
        subtitle: Text('${item.resultCount} results'),
        trailing: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () async {
            // ✅ FIX: Remove from local state and persist
            // Note: Full removal from storage requires clearing all history
            // For individual removal, we just update local state
            setState(() {
              _searchHistory.remove(item);
            });
          },
        ),
        onTap: () {
          _searchController.text = item.query;
          _onSearchSubmitted(item.query);
        },
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
      ),
    );
  }

  Widget _buildTrendingTopics() {
    final trendingTopics = [
      'Web Development',
      'Mobile Apps',
      'Data Science',
      'UI/UX Design',
      'Machine Learning',
      'Cybersecurity',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Trending Topics',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
        ),
        const SizedBox(height: AppTheme.spaceMd),
        Wrap(
          spacing: AppTheme.spaceSm,
          runSpacing: AppTheme.spaceSm,
          children:
              trendingTopics.map((topic) => _buildTrendingChip(topic)).toList(),
        ),
      ],
    );
  }

  Widget _buildTrendingChip(String topic) {
    return GestureDetector(
      onTap: () {
        _searchController.text = topic;
        _onSearchSubmitted(topic);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMd,
          vertical: AppTheme.spaceSm,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.trending_up_rounded,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: AppTheme.spaceXs),
            Text(
              topic,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
