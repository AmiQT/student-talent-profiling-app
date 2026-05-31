import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/event_model.dart';
import '../../../models/event_registration_model.dart';
import '../../../services/event_service.dart';
import '../../../utils/app_theme.dart';
import '../../../config/supabase_config.dart';
import 'modern_event_detail_screen.dart';

class MyRegisteredEventsScreen extends StatefulWidget {
  const MyRegisteredEventsScreen({super.key});

  @override
  State<MyRegisteredEventsScreen> createState() =>
      _MyRegisteredEventsScreenState();
}

class _MyRegisteredEventsScreenState extends State<MyRegisteredEventsScreen>
    with SingleTickerProviderStateMixin {
  final EventService _eventService = EventService();
  List<EventRegistrationWithEvent> _registrations = [];
  bool _isLoading = true;
  String? _userId;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _userId = SupabaseConfig.auth.currentUser?.id;
    _tabController = TabController(length: 3, vsync: this);
    _loadRegisteredEvents();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRegisteredEvents() async {
    if (_userId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // OPTIMIZED: Single query instead of N+1 loop
      final results =
          await _eventService.getRegisteredEventsWithDetails(_userId!);

      // Convert to EventRegistrationWithEvent objects
      final registrationsWithEvents = <EventRegistrationWithEvent>[];
      for (final item in results) {
        final eventData = item['events'] as Map<String, dynamic>?;
        if (eventData == null) continue;

        // Create EventModel from embedded event data
        final event = EventModel(
          id: eventData['id'] ?? '',
          title: eventData['title'] ?? '',
          description: eventData['description'] ?? '',
          imageUrl: eventData['image_url'] ?? '',
          category: eventData['category'] ?? 'General',
          favoriteUserIds: [],
          registerUrl: '',
          createdAt: eventData['created_at'] != null
              ? DateTime.tryParse(eventData['created_at']) ?? DateTime.now()
              : DateTime.now(),
          updatedAt: eventData['updated_at'] != null
              ? DateTime.tryParse(eventData['updated_at']) ?? DateTime.now()
              : DateTime.now(),
          eventDate: eventData['event_date'] != null
              ? DateTime.tryParse(eventData['event_date'])
              : null,
          location: eventData['location'],
          price: (eventData['price'] as num?)?.toDouble(),
          maxParticipants: eventData['max_participants'],
          currentParticipants: eventData['current_participants'],
          registrationOpen: eventData['registration_open'],
          registrationDeadline: eventData['registration_deadline'] != null
              ? DateTime.tryParse(eventData['registration_deadline'])
              : null,
        );

        // Create EventRegistrationModel from registration data
        final registration = EventRegistrationModel.fromJson(item);

        registrationsWithEvents.add(
          EventRegistrationWithEvent(
            registration: registration,
            event: event,
          ),
        );
      }

      if (mounted) {
        setState(() {
          _registrations = registrationsWithEvents;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading registered events: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<EventRegistrationWithEvent> get _upcomingEvents {
    final now = DateTime.now();
    return _registrations
        .where((r) =>
            r.event.eventDate != null &&
            r.event.eventDate!.isAfter(now) &&
            r.registration.attendanceStatus != 'cancelled')
        .toList()
      ..sort((a, b) => a.event.eventDate!.compareTo(b.event.eventDate!));
  }

  List<EventRegistrationWithEvent> get _pastEvents {
    final now = DateTime.now();
    return _registrations
        .where((r) =>
            r.event.eventDate != null &&
            r.event.eventDate!.isBefore(now) &&
            r.registration.attendanceStatus != 'cancelled')
        .toList()
      ..sort((a, b) => b.event.eventDate!.compareTo(a.event.eventDate!));
  }

  List<EventRegistrationWithEvent> get _cancelledEvents {
    return _registrations
        .where((r) => r.registration.attendanceStatus == 'cancelled')
        .toList()
      ..sort((a, b) => b.registration.registrationDate
          .compareTo(a.registration.registrationDate));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('My Registered Events'),
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.upcoming_rounded, size: 18),
                  const SizedBox(width: 4),
                  Text('Upcoming (${_upcomingEvents.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.history_rounded, size: 18),
                  const SizedBox(width: 4),
                  Text('Past (${_pastEvents.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cancel_rounded, size: 18),
                  const SizedBox(width: 4),
                  Text('Cancelled (${_cancelledEvents.length})'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildEventsList(_upcomingEvents, isUpcoming: true),
                _buildEventsList(_pastEvents, isPast: true),
                _buildEventsList(_cancelledEvents, isCancelled: true),
              ],
            ),
    );
  }

  Widget _buildEventsList(
    List<EventRegistrationWithEvent> events, {
    bool isUpcoming = false,
    bool isPast = false,
    bool isCancelled = false,
  }) {
    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isCancelled
                  ? Icons.cancel_rounded
                  : (isPast
                      ? Icons.event_busy_rounded
                      : Icons.event_available_rounded),
              size: 64,
              color: AppTheme.textSecondaryColor.withValues(alpha: 0.3),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            Text(
              isCancelled
                  ? 'No cancelled registrations'
                  : (isPast ? 'No past events yet' : 'No upcoming events'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textSecondaryColor,
                  ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRegisteredEvents,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        itemCount: events.length,
        itemBuilder: (context, index) {
          final item = events[index];
          return _buildEventCard(
            item,
            isUpcoming: isUpcoming,
            isPast: isPast,
            isCancelled: isCancelled,
          );
        },
      ),
    );
  }

  Widget _buildEventCard(
    EventRegistrationWithEvent item, {
    bool isUpcoming = false,
    bool isPast = false,
    bool isCancelled = false,
  }) {
    final event = item.event;
    final registration = item.registration;

    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMd),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ModernEventDetailScreen(event: event),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Badge
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceMd),
              decoration: BoxDecoration(
                color: _getStatusColor(registration.attendanceStatus)
                    .withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppTheme.radiusMd),
                  topRight: Radius.circular(AppTheme.radiusMd),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _getStatusIcon(registration.attendanceStatus),
                    size: 20,
                    color: _getStatusColor(registration.attendanceStatus),
                  ),
                  const SizedBox(width: AppTheme.spaceSm),
                  Text(
                    _getStatusLabel(registration.attendanceStatus),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _getStatusColor(registration.attendanceStatus),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const Spacer(),
                  if (event.eventDate != null && isUpcoming)
                    _buildCountdown(event.eventDate!),
                ],
              ),
            ),

            // Event Info
            Padding(
              padding: const EdgeInsets.all(AppTheme.spaceMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: AppTheme.spaceSm),
                  if (event.eventDate != null) ...[
                    _buildInfoRow(
                      Icons.calendar_today_rounded,
                      DateFormat('EEE, dd MMM yyyy, hh:mm a')
                          .format(event.eventDate!),
                    ),
                    const SizedBox(height: AppTheme.spaceXs),
                  ],
                  if (event.location != null) ...[
                    _buildInfoRow(
                      Icons.location_on_rounded,
                      event.location!,
                    ),
                    const SizedBox(height: AppTheme.spaceXs),
                  ],
                  _buildInfoRow(
                    Icons.confirmation_number_rounded,
                    'Registered on ${DateFormat('dd MMM yyyy').format(registration.registrationDate)}',
                  ),

                  // Action Buttons
                  if (isPast &&
                      registration.attendanceStatus == 'attended' &&
                      (registration.feedbackRating == null ||
                          registration.feedbackRating != null)) ...[
                    const SizedBox(height: AppTheme.spaceSm),
                    if (registration.feedbackRating == null)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showFeedbackForm(registration),
                          icon: const Icon(Icons.star_rounded, size: 18),
                          label: const Text('Give Feedback'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.secondaryColor,
                          ),
                        ),
                      ),
                    if (registration.feedbackRating != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spaceSm,
                          vertical: AppTheme.spaceXs,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryColor.withValues(alpha: 0.1),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: AppTheme.secondaryColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Rated ${registration.feedbackRating!.toStringAsFixed(1)}',
                              style: const TextStyle(
                                color: AppTheme.secondaryColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondaryColor),
        const SizedBox(width: AppTheme.spaceXs),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondaryColor,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildCountdown(DateTime eventDate) {
    final now = DateTime.now();
    final difference = eventDate.difference(now);

    String countdownText;
    if (difference.inDays > 0) {
      countdownText = '${difference.inDays}d left';
    } else if (difference.inHours > 0) {
      countdownText = '${difference.inHours}h left';
    } else if (difference.inMinutes > 0) {
      countdownText = '${difference.inMinutes}m left';
    } else {
      countdownText = 'Starting soon!';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceSm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppTheme.warningColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusXs),
      ),
      child: Text(
        countdownText,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'confirmed':
        return AppTheme.infoColor;
      case 'attended':
        return AppTheme.successColor;
      case 'cancelled':
        return AppTheme.errorColor;
      default:
        return AppTheme.warningColor;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'confirmed':
        return Icons.check_circle_outline_rounded;
      case 'attended':
        return Icons.verified_rounded;
      case 'cancelled':
        return Icons.cancel_rounded;
      default:
        return Icons.pending_rounded;
    }
  }

  String _getStatusLabel(String? status) {
    switch (status) {
      case 'confirmed':
        return 'Confirmed';
      case 'attended':
        return 'Attended';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Pending';
    }
  }

  void _showFeedbackForm(EventRegistrationModel registration) {
    double rating = 0;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Event Feedback'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('How would you rate this event?'),
                const SizedBox(height: AppTheme.spaceSm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      icon: Icon(
                        index < rating
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: AppTheme.secondaryColor,
                        size: 36,
                      ),
                      onPressed: () {
                        setState(() {
                          rating = (index + 1).toDouble();
                        });
                      },
                    );
                  }),
                ),
                const SizedBox(height: AppTheme.spaceMd),
                TextField(
                  controller: commentController,
                  decoration: const InputDecoration(
                    labelText: 'Comments (optional)',
                    hintText: 'Share your experience...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: rating > 0
                  ? () async {
                      final success = await _eventService.submitEventFeedback(
                        eventId: registration.eventId,
                        userId: _userId!,
                        rating: rating,
                        comment: commentController.text.trim(),
                      );

                      if (context.mounted) {
                        Navigator.pop(context);
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Thank you for your feedback!'),
                              backgroundColor: AppTheme.successColor,
                            ),
                          );
                          _loadRegisteredEvents();
                        }
                      }
                    }
                  : null,
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper class to combine registration and event data
class EventRegistrationWithEvent {
  final EventRegistrationModel registration;
  final EventModel event;

  EventRegistrationWithEvent({
    required this.registration,
    required this.event,
  });
}
