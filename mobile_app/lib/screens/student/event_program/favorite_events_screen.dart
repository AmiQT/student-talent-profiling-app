import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/event_model.dart';
import '../../../services/event_service.dart';
import '../../../services/supabase_auth_service.dart';
import '../../../utils/app_theme.dart';
import '../../../widgets/modern/modern_event_card.dart';
import 'modern_event_detail_screen.dart';

class FavoriteEventsScreen extends StatefulWidget {
  const FavoriteEventsScreen({super.key});

  @override
  State<FavoriteEventsScreen> createState() => _FavoriteEventsScreenState();
}

class _FavoriteEventsScreenState extends State<FavoriteEventsScreen>
    with RouteAware {
  final EventService _eventService = EventService();
  List<EventModel> _favoriteEvents = [];
  bool _isLoading = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Register for route changes to refresh when returning to this screen
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      // RouteObserver subscription would go here if we had one globally
    }
  }

  @override
  void didPopNext() {
    // Refresh when returning from another screen
    _loadFavoriteEvents();
  }

  Future<void> _initializeData() async {
    final authService =
        Provider.of<SupabaseAuthService>(context, listen: false);
    _userId = authService.currentUser?.id;

    if (_userId != null) {
      await _loadFavoriteEvents();
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadFavoriteEvents() async {
    if (_userId == null) return;

    try {
      // OPTIMIZED: Direct Supabase query instead of filtering client-side
      final events = await _eventService.getFavoriteEventsWithDetails(_userId!);

      if (mounted) {
        setState(() {
          _favoriteEvents = events;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading favorite events: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _toggleFavorite(EventModel event) async {
    if (_userId == null) return;

    try {
      final isFavorite = event.favoriteUserIds.contains(_userId);
      await _eventService.toggleFavorite(
        eventId: event.id,
        userId: _userId!,
        isFavorite: !isFavorite,
      );

      // Update local state
      setState(() {
        if (isFavorite) {
          event.favoriteUserIds.remove(_userId);
          _favoriteEvents.removeWhere((e) => e.id == event.id);
        } else {
          event.favoriteUserIds.add(_userId!);
        }
      });

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
            content: Text('Error updating favorites: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _navigateToEventDetail(EventModel event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ModernEventDetailScreen(event: event),
      ),
    );
  }

  void _shareEvent(EventModel event) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share functionality coming soon!'),
        backgroundColor: AppTheme.infoColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        title: const Text(
          'Favorite Events',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
              ),
            )
          : _userId == null
              ? _buildLoginPrompt()
              : _favoriteEvents.isEmpty
                  ? _buildEmptyState()
                  : _buildFavoritesList(),
    );
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.login_rounded,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: AppTheme.spaceLg),
            Text(
              'Please login to view favorites',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spaceLg),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceLg,
                  vertical: AppTheme.spaceMd,
                ),
              ),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border_rounded,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: AppTheme.spaceLg),
            Text(
              'No favorite events',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            Text(
              'Start exploring events and add them to your favorites!',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[500],
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spaceLg),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceLg,
                  vertical: AppTheme.spaceMd,
                ),
              ),
              child: const Text('Explore Events'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoritesList() {
    return RefreshIndicator(
      onRefresh: _loadFavoriteEvents,
      color: AppTheme.primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        itemCount: _favoriteEvents.length,
        itemBuilder: (context, index) {
          final event = _favoriteEvents[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spaceMd),
            child: ModernEventCard(
              event: event,
              currentUserId: _userId,
              onTap: (event) => _navigateToEventDetail(event),
              onFavoriteToggle: (event) => _toggleFavorite(event),
              onShare: (event) => _shareEvent(event),
            ),
          );
        },
      ),
    );
  }
}
