import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../models/event_model.dart';
import '../../../services/event_service.dart';
import '../../../utils/app_theme.dart';
import '../../../widgets/modern/modern_event_header.dart';
import '../../../widgets/modern/modern_event_card.dart';
import '../../../widgets/modern/event_filter_widget.dart';
import 'modern_event_detail_screen.dart';
import 'favorite_events_screen.dart';
import '../../shared/notifications_screen.dart';
import '../../../config/supabase_config.dart';

class ModernEventProgramScreen extends StatefulWidget {
  const ModernEventProgramScreen({super.key});

  @override
  State<ModernEventProgramScreen> createState() =>
      _ModernEventProgramScreenState();
}

class _ModernEventProgramScreenState extends State<ModernEventProgramScreen>
    with TickerProviderStateMixin {
  final EventService _eventService = EventService();
  final ScrollController _scrollController = ScrollController();

  // Animation controllers
  late AnimationController _fadeAnimationController;
  late AnimationController _slideAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // State variables
  List<EventModel> _allEvents = [];
  List<EventModel> _filteredEvents = [];
  List<String> _selectedCategories = [];
  String _searchQuery = '';
  String? _userId;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _userId = SupabaseConfig.auth.currentUser?.id;
    _initializeAnimations();
    _loadEvents();
  }

  void _initializeAnimations() {
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeAnimationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideAnimationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _fadeAnimationController.dispose();
    _slideAnimationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final events = await _eventService.streamAllEvents().first;
      setState(() {
        _allEvents = events;
        _filteredEvents = events;
        _isLoading = false;
      });

      // Start animations
      _fadeAnimationController.forward();
      _slideAnimationController.forward();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterEvents() {
    setState(() {
      _filteredEvents = _allEvents.where((event) {
        // Search filter
        final matchesSearch = _searchQuery.isEmpty ||
            event.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            event.description
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            event.category.toLowerCase().contains(_searchQuery.toLowerCase());

        // Category filter
        final matchesCategory = _selectedCategories.isEmpty ||
            _selectedCategories.contains(event.category);

        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          ModernEventHeader(
            searchQuery: _searchQuery,
            favoriteCount: _getFavoriteCount(),
            onSearchChanged: (query) {
              setState(() {
                _searchQuery = query;
              });
              _filterEvents();
            },
            onFilterTap: _showFilterBottomSheet,
            onFavoritesTap: _showFavoriteEvents,
            onNotificationTap: () => _navigateToNotifications(),
            onProfileTap: () {
              // Navigate to profile
            },
          ),
          Expanded(
            child: _buildEventsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsList() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_filteredEvents.isEmpty) {
      return _buildEmptyState();
    }

    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: RefreshIndicator(
              onRefresh: _loadEvents,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.only(
                  top: AppTheme.spaceMd,
                  bottom: AppTheme.space2xl,
                ),
                itemCount: _filteredEvents.length,
                itemBuilder: (context, index) {
                  final event = _filteredEvents[index];
                  return ModernEventCard(
                    event: event,
                    currentUserId: _userId,
                    onTap: (event) => _navigateToEventDetail(event),
                    onFavoriteToggle: (event) => _toggleFavorite(event),
                    onShare: (event) => _shareEvent(event),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceLg),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark
                  ? Colors.white
                  : theme.cardColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
            ),
          ),
          const SizedBox(height: AppTheme.spaceLg),
          Text(
            'Loading amazing events...',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.brightness == Brightness.dark
                  ? Colors.black
                  : theme.textTheme.bodyLarge?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.space2xl),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? Colors.red[800]?.withValues(alpha: 0.8)
                    : theme.colorScheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: theme.brightness == Brightness.dark
                    ? Colors.white
                    : theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: AppTheme.spaceLg),
            Text(
              'Oops! Something went wrong',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.brightness == Brightness.dark
                    ? Colors.white
                    : theme.textTheme.headlineSmall?.color,
              ),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            Text(
              _error ?? 'Unknown error occurred',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.brightness == Brightness.dark
                    ? Colors.white70
                    : theme.textTheme.bodyLarge?.color,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppTheme.spaceLg),
            Container(
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _loadEvents,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceLg,
                    vertical: AppTheme.spaceMd,
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                label: const Text(
                  'Try Again',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final hasFilters =
        _selectedCategories.isNotEmpty || _searchQuery.isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.space2xl),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? Colors.white
                    : theme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
              child: Icon(
                hasFilters
                    ? Icons.search_off_rounded
                    : Icons.event_busy_rounded,
                size: 64,
                color: theme.brightness == Brightness.dark
                    ? Colors.grey[600]
                    : theme.primaryColor,
              ),
            ),
            const SizedBox(height: AppTheme.spaceLg),
            Text(
              hasFilters ? 'No events found' : 'No events available',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.brightness == Brightness.dark
                    ? Colors.black
                    : theme.textTheme.headlineSmall?.color,
              ),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            Text(
              hasFilters
                  ? 'Try adjusting your search or filters to find events'
                  : 'Check back later for exciting events at UTHM!',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.brightness == Brightness.dark
                    ? Colors.grey[600]
                    : theme.textTheme.bodyLarge?.color,
                height: 1.5,
              ),
            ),
            if (hasFilters) ...[
              const SizedBox(height: AppTheme.spaceLg),
              Container(
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _clearFilters,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceLg,
                      vertical: AppTheme.spaceMd,
                    ),
                  ),
                  icon:
                      const Icon(Icons.clear_all_rounded, color: Colors.white),
                  label: const Text(
                    'Clear Filters',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Action methods
  void _navigateToEventDetail(EventModel event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ModernEventDetailScreen(event: event),
      ),
    );
  }

  Future<void> _toggleFavorite(EventModel event) async {
    if (_userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to add favorites'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    try {
      final isFavorite = event.favoriteUserIds.contains(_userId);
      await _eventService.toggleFavorite(
        eventId: event.id,
        userId: _userId!,
        isFavorite: !isFavorite,
      );

      // Update local state
      setState(() {
        final index = _allEvents.indexWhere((e) => e.id == event.id);
        if (index != -1) {
          final updatedEvent = _allEvents[index];
          if (isFavorite) {
            updatedEvent.favoriteUserIds.remove(_userId);
          } else {
            updatedEvent.favoriteUserIds.add(_userId!);
          }
          _allEvents[index] = updatedEvent;
        }
      });
      _filterEvents();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isFavorite ? 'Removed from favorites' : 'Added to favorites',
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating favorites: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _shareEvent(EventModel event) {
    Share.share(
      'Check out this event: ${event.title}\n\n${event.description}',
      subject: event.title,
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EventFilterWidget(
        selectedCategories: _selectedCategories,
        onCategoriesChanged: (categories) {
          setState(() {
            _selectedCategories = categories;
          });
          _filterEvents();
        },
        onClearAll: () {
          setState(() {
            _selectedCategories.clear();
          });
          _filterEvents();
        },
      ),
    );
  }

  void _showFavoriteEvents() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FavoriteEventsScreen(),
      ),
    );
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _selectedCategories.clear();
    });
    _filterEvents();
  }

  int _getFavoriteCount() {
    if (_userId == null) return 0;
    return _allEvents
        .where((event) => event.favoriteUserIds.contains(_userId))
        .length;
  }

  void _navigateToNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NotificationsScreen(),
      ),
    );
  }
}
