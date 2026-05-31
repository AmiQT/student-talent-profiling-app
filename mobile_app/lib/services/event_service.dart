import '../config/app_config.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/event_model.dart';
import '../models/event_registration_model.dart';
import '../models/profile_model.dart';
import 'auto_notification_service.dart';
import '../config/supabase_config.dart';

class EventService {
  static const String baseUrl =
      AppConfig.backendUrl; // Use stable cloud backend

  // Get Supabase auth token for authentication
  static Future<String?> _getAuthToken() async {
    try {
      final session = SupabaseConfig.auth.currentSession;
      if (session?.accessToken != null) {
        return session!.accessToken;
      }
      return null;
    } catch (e) {
      debugPrint('EventService: Error getting auth token: $e');
      return null;
    }
  }

  Future<List<EventModel>> getAllEvents() async {
    final stopwatch = Stopwatch()..start();
    try {
      // MOBILE APP OPTIMIZATION: Skip custom backend, use Supabase directly
      // debugPrint(
      //     'EventService: Using Supabase directly for mobile app (no custom backend delays)');
      final result = await _getEventsFromSupabase();
      stopwatch.stop();
      // debugPrint(
      //     'EventService: Direct Supabase completed in ${stopwatch.elapsedMilliseconds}ms');
      return result;
    } catch (e) {
      stopwatch.stop();
      debugPrint(
          '❌ Error loading events from Supabase in ${stopwatch.elapsedMilliseconds}ms: $e');
      return []; // Return empty list on error
    }
  }

  /// Fallback method to get events from Supabase directly
  Future<List<EventModel>> _getEventsFromSupabase() async {
    try {
      final response = await SupabaseConfig.client
          .from('events')
          .select('*')
          .eq('is_active', true) // Only get active events
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 5)); // Prevent hanging

      final events = <EventModel>[];
      for (final eventData in response) {
        // Map Supabase fields to EventModel fields
        final event = EventModel(
          id: eventData['id'] ?? '',
          title: eventData['title'] ?? '',
          description: eventData['description'] ?? '',
          imageUrl: eventData['image_url'] ??
              _getDefaultEventImage(eventData['title'] ?? 'Event') ??
              '', // Use provided image, default image, or empty string
          category: eventData['category'] ??
              _getCategoryFromLocation(eventData[
                  'location']), // Use provided category or derive from location
          favoriteUserIds: [], // Will be populated below
          registerUrl: '', // Events table doesn't have register_url field
          createdAt: eventData['created_at'] != null
              ? DateTime.parse(eventData['created_at'])
              : DateTime.now(),
          updatedAt: eventData['updated_at'] != null
              ? DateTime.parse(eventData['updated_at'])
              : DateTime.now(),
          // Payment fields
          isPaid: eventData['is_paid'] ?? false,
          price: eventData['price'] != null
              ? (eventData['price'] is int
                  ? (eventData['price'] as int).toDouble()
                  : double.tryParse(eventData['price'].toString()))
              : null,
          // Event date & location
          eventDate: eventData['event_date'] != null
              ? DateTime.tryParse(eventData['event_date'])
              : null,
          location: eventData['location'],
          maxParticipants: eventData['max_participants'],
          currentParticipants: eventData['current_participants'],
        );

        events.add(event);
      }

      // Populate favorite data for all events
      await _populateFavoriteData(events);

      return events;
    } catch (e) {
      debugPrint('❌ Error loading events from Supabase: $e');
      return []; // Return empty list if both backend and Supabase fail
    }
  }

  /// Populate favorite data for events
  Future<void> _populateFavoriteData(List<EventModel> events) async {
    try {
      // Get all favorite relationships
      final favoritesResponse = await SupabaseConfig.client
          .from('event_favorites')
          .select('event_id, user_id');

      // Group favorites by event_id
      final Map<String, List<String>> favoritesMap = {};
      for (final favorite in favoritesResponse) {
        final eventId = favorite['event_id'] as String;
        final userId = favorite['user_id'] as String;

        if (!favoritesMap.containsKey(eventId)) {
          favoritesMap[eventId] = [];
        }
        favoritesMap[eventId]!.add(userId);
      }

      // Update events with favorite data
      for (int i = 0; i < events.length; i++) {
        final event = events[i];
        final favoriteUserIds = favoritesMap[event.id] ?? [];

        // Create new event with updated favorite data
        events[i] = event.copyWith(favoriteUserIds: favoriteUserIds);
      }
    } catch (e) {
      debugPrint('EventService: Error populating favorite data: $e');
      // Don't throw error, just log it - events will still work without favorite data
    }
  }

  /// Helper method to derive category from location
  String _getCategoryFromLocation(String? location) {
    if (location == null || location.isEmpty) return 'General';

    final locationLower = location.toLowerCase();
    if (locationLower.contains('computer') || locationLower.contains('lab')) {
      return 'Technology';
    } else if (locationLower.contains('engineering') ||
        locationLower.contains('workshop')) {
      return 'Engineering';
    } else if (locationLower.contains('dewan') ||
        locationLower.contains('hall')) {
      return 'Conference';
    } else {
      return 'General';
    }
  }

  /// Get default event image based on event title
  String? _getDefaultEventImage(String title) {
    // Return null for all events - let users upload their own images
    // No more hardcoded Unsplash images
    return null;
  }

  Future<EventModel?> getEventById(String eventId) async {
    try {
      // debugPrint('EventService: Getting event by ID: $eventId');

      // SUPABASE-FIRST: Direct DB query is faster and more reliable
      // Backend calls are slow due to Render cold starts
      return await _getEventFromSupabase(eventId);
    } catch (e) {
      debugPrint('❌ Error loading event: $e');
      return null;
    }
  }

  /// Get single event from Supabase
  Future<EventModel?> _getEventFromSupabase(String eventId) async {
    try {
      // debugPrint('EventService: Getting event from Supabase: $eventId');

      final response = await SupabaseConfig.client
          .from('events')
          .select('*')
          .eq('id', eventId)
          .eq('is_active', true)
          .maybeSingle();

      if (response != null) {
        // debugPrint(
        //     'EventService: Event found in Supabase: ${response['title']}');

        final event = EventModel(
          id: response['id'] ?? eventId,
          title: response['title'] ?? '',
          description: response['description'] ?? '',
          imageUrl: response['image_url'] ??
              _getDefaultEventImage(response['title'] ?? 'Event') ??
              '', // Use provided image, default image, or empty string
          category: response['category'] ??
              _getCategoryFromLocation(response['location'] ?? ''),
          favoriteUserIds: [], // Will be populated below
          registerUrl: '', // Not available in Supabase events table
          createdAt: response['created_at'] != null
              ? DateTime.parse(response['created_at'])
              : DateTime.now(),
          updatedAt: response['updated_at'] != null
              ? DateTime.parse(response['updated_at'])
              : DateTime.now(),
          // Payment fields
          isPaid: response['is_paid'] ?? false,
          price: response['price'] != null
              ? (response['price'] is int
                  ? (response['price'] as int).toDouble()
                  : double.tryParse(response['price'].toString()))
              : null,
          // Event date & location
          eventDate: response['event_date'] != null
              ? DateTime.tryParse(response['event_date'])
              : null,
          location: response['location'],
          maxParticipants: response['max_participants'],
          currentParticipants: response['current_participants'],
        );

        // Populate favorite data for this single event
        await _populateFavoriteData([event]);

        return event;
      } else {
        debugPrint('EventService: Event not found in Supabase: $eventId');
        return null;
      }
    } catch (e) {
      debugPrint('EventService: Error getting event from Supabase: $e');
      return null;
    }
  }

  Future<void> addEvent(EventModel event) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('No authentication token available');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/events'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'title': event.title,
          'description': event.description,
          'category': event.category,
          'image_url': event.imageUrl,
          'register_url': event.registerUrl,
        }),
      );

      if (response.statusCode != 201) {
        throw Exception('Failed to create event: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error creating event: $e');
      throw Exception('Failed to create event: $e');
    }
  }

  Future<void> updateEvent(EventModel event) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('No authentication token available');
      }

      final response = await http.put(
        Uri.parse('$baseUrl/api/events/${event.id}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'title': event.title,
          'description': event.description,
          'category': event.category,
          'image_url': event.imageUrl,
          'register_url': event.registerUrl,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update event: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error updating event: $e');
      throw Exception('Failed to update event: $e');
    }
  }

  Future<void> deleteEvent(String eventId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('No authentication token available');
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/api/events/$eventId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete event: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error deleting event: $e');
      throw Exception('Failed to delete event: $e');
    }
  }

  Future<void> toggleFavorite({
    required String eventId,
    required String userId,
    required bool isFavorite,
  }) async {
    try {
      // Validate inputs
      if (eventId.isEmpty) {
        throw Exception('Event ID cannot be empty');
      }
      if (userId.isEmpty) {
        throw Exception('User ID cannot be empty');
      }

      // debugPrint(
      //     'EventService: Toggling favorite for event $eventId, user $userId, favorite: $isFavorite');

      // Try backend first
      try {
        final token = await _getAuthToken();
        if (token != null) {
          final response = await http.post(
            Uri.parse('$baseUrl/api/events/$eventId/favorite'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'is_favorite': isFavorite,
            }),
          );

          if (response.statusCode == 200) {
            // debugPrint(
            //     'EventService: Favorite toggled successfully via backend');
            await _handleFavoriteNotification(eventId, userId, isFavorite);
            return;
          } else {
            debugPrint(
                'EventService: Backend favorite toggle failed: ${response.statusCode}');
          }
        }
      } catch (e) {
        debugPrint('EventService: Backend favorite toggle error: $e');
      }

      // Fallback to Supabase or local storage
      // debugPrint('EventService: Using fallback for favorite toggle');
      await _toggleFavoriteFallback(eventId, userId, isFavorite);
      await _handleFavoriteNotification(eventId, userId, isFavorite);
    } catch (e) {
      debugPrint('❌ Error toggling favorite: $e');
      throw Exception('Failed to toggle favorite: $e');
    }
  }

  /// Fallback method for favorite toggle using Supabase or local storage
  Future<void> _toggleFavoriteFallback(
      String eventId, String userId, bool isFavorite) async {
    try {
      // Try Supabase first
      try {
        // debugPrint('EventService: Attempting Supabase favorite toggle...');

        if (isFavorite) {
          // Add to favorites
          await SupabaseConfig.client.from('event_favorites').upsert({
            'user_id': userId,
            'event_id': eventId,
            'created_at': DateTime.now().toIso8601String(),
          });
          // debugPrint('EventService: Supabase upsert result: $result');
        } else {
          // Remove from favorites
          await SupabaseConfig.client
              .from('event_favorites')
              .delete()
              .eq('user_id', userId)
              .eq('event_id', eventId);
          // debugPrint('EventService: Supabase delete result: $result');
        }
        // debugPrint('EventService: Favorite toggled successfully via Supabase');
        return;
      } catch (e) {
        debugPrint('EventService: Supabase favorite toggle failed: $e');
        // Check if it's a table not found error
        if (e.toString().contains('event_favorites') &&
            e.toString().contains('Not Found')) {
          debugPrint(
              'EventService: event_favorites table not found, please create it in Supabase');
        }
      }

      // Fallback to local storage (SharedPreferences)
      // debugPrint('EventService: Falling back to local storage...');
      await _toggleFavoriteLocal(eventId, userId, isFavorite);
    } catch (e) {
      debugPrint('EventService: Fallback favorite toggle error: $e');
      // Don't throw error, just log it - favorite is not critical functionality
    }
  }

  /// Local storage fallback for favorites
  Future<void> _toggleFavoriteLocal(
      String eventId, String userId, bool isFavorite) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'favorite_events_$userId';
      final favoriteEvents = prefs.getStringList(key) ?? [];

      if (isFavorite) {
        if (!favoriteEvents.contains(eventId)) {
          favoriteEvents.add(eventId);
        }
      } else {
        favoriteEvents.remove(eventId);
      }

      await prefs.setStringList(key, favoriteEvents);
      // debugPrint(
      //     'EventService: Favorite toggled successfully via local storage');
    } catch (e) {
      debugPrint('EventService: Local storage favorite toggle error: $e');
    }
  }

  /// Handle favorite notification
  Future<void> _handleFavoriteNotification(
      String eventId, String userId, bool isFavorite) async {
    try {
      if (isFavorite) {
        // Quick title-only query instead of slow getEventById
        final result = await SupabaseConfig.client
            .from('events')
            .select('title')
            .eq('id', eventId)
            .maybeSingle();

        if (result != null) {
          await AutoNotificationService.onEventFavorited(
            userId: userId,
            eventTitle: result['title'] ?? 'Event',
            eventId: eventId,
          );
        }
      }
    } catch (e) {
      debugPrint('EventService: Error handling favorite notification: $e');
    }
  }

  /// Check if event is favorited by user
  Future<bool> isEventFavorited(String eventId, String userId) async {
    try {
      // debugPrint(
      //     'EventService: Checking favorite status for event $eventId, user $userId');

      // Try Supabase first
      try {
        final response = await SupabaseConfig.client
            .from('event_favorites')
            .select('id')
            .eq('user_id', userId)
            .eq('event_id', eventId)
            .maybeSingle();

        if (response != null) {
          // debugPrint('EventService: Event is favorited in Supabase');
          return true;
        } else {
          // debugPrint('EventService: Event not found in Supabase favorites');
        }
      } catch (e) {
        debugPrint('EventService: Supabase favorite check failed: $e');
        if (e.toString().contains('event_favorites') &&
            e.toString().contains('Not Found')) {
          debugPrint(
              'EventService: event_favorites table not found, using local storage');
        }
      }

      // Fallback to local storage
      final prefs = await SharedPreferences.getInstance();
      final key = 'favorite_events_$userId';
      final favoriteEvents = prefs.getStringList(key) ?? [];
      final isLocalFavorite = favoriteEvents.contains(eventId);
      // debugPrint(
      //     'EventService: Local storage favorite status: $isLocalFavorite');
      return isLocalFavorite;
    } catch (e) {
      debugPrint('EventService: Error checking favorite status: $e');
      return false;
    }
  }

  /// Get all favorited events for a user
  Future<List<String>> getFavoriteEventIds(String userId) async {
    try {
      // debugPrint('EventService: Getting favorite events for user $userId');

      // Try Supabase first
      try {
        final response = await SupabaseConfig.client
            .from('event_favorites')
            .select('event_id')
            .eq('user_id', userId);

        if (response.isNotEmpty) {
          final eventIds =
              response.map((item) => item['event_id'] as String).toList();
          // debugPrint(
          //     'EventService: Found ${eventIds.length} favorites in Supabase');
          return eventIds;
        } else {
          // debugPrint('EventService: No favorites found in Supabase');
        }
      } catch (e) {
        debugPrint('EventService: Supabase favorite list failed: $e');
        if (e.toString().contains('event_favorites') &&
            e.toString().contains('Not Found')) {
          debugPrint(
              'EventService: event_favorites table not found, using local storage');
        }
      }

      // Fallback to local storage
      final prefs = await SharedPreferences.getInstance();
      final key = 'favorite_events_$userId';
      final localFavorites = prefs.getStringList(key) ?? [];
      // debugPrint(
      //     'EventService: Found ${localFavorites.length} favorites in local storage');
      return localFavorites;
    } catch (e) {
      debugPrint('EventService: Error getting favorite events: $e');
      return [];
    }
  }

  /// OPTIMIZED: Get favorite events with full details in SINGLE query
  Future<List<EventModel>> getFavoriteEventsWithDetails(String userId) async {
    try {
      // debugPrint('🔵 getFavoriteEventsWithDetails: Fetching for user $userId');

      // Single query with embedded relation
      final response =
          await SupabaseConfig.client.from('event_favorites').select('''
            event_id,
            events!event_id (
              id,
              title,
              description,
              image_url,
              category,
              location,
              event_date,
              created_at,
              updated_at,
              is_active,
              price,
              max_participants,
              current_participants,
              registration_open,
              registration_deadline
            )
          ''').eq('user_id', userId);

      // debugPrint(
      //     '🔵 getFavoriteEventsWithDetails: Got ${(response as List).length} favorites');

      final events = <EventModel>[];
      for (final item in response) {
        final eventData = item['events'] as Map<String, dynamic>?;
        if (eventData == null || eventData['is_active'] != true) continue;

        events.add(EventModel(
          id: eventData['id'] ?? '',
          title: eventData['title'] ?? '',
          description: eventData['description'] ?? '',
          imageUrl: eventData['image_url'] ?? '',
          category: eventData['category'] ?? 'General',
          favoriteUserIds: [
            userId
          ], // Since this is from favorites, user has favorited it
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
        ));
      }

      // Sort by creation date
      events.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // debugPrint(
      //     '🔵 getFavoriteEventsWithDetails: Returning ${events.length} valid events');
      return events;
    } catch (e) {
      debugPrint(
          '❌ EventService: Error getting favorite events with details: $e');
      return [];
    }
  }

  /// TRUE Real-time stream using Supabase Realtime subscription
  Stream<List<EventModel>> streamAllEvents() {
    final controller = StreamController<List<EventModel>>();
    List<EventModel> lastEvents = [];

    // Helper function to load and emit events with favorite data
    Future<void> loadAndEmitEvents() async {
      try {
        final events = await getAllEvents();

        // Only emit if data has changed
        if (lastEvents.isEmpty ||
            events.length != lastEvents.length ||
            events.asMap().entries.any((entry) {
              final i = entry.key;
              final newEvent = entry.value;
              final oldEvent = i < lastEvents.length ? lastEvents[i] : null;
              return oldEvent == null ||
                  newEvent.id != oldEvent.id ||
                  newEvent.currentParticipants !=
                      oldEvent.currentParticipants ||
                  newEvent.favoriteUserIds.length !=
                      oldEvent.favoriteUserIds.length;
            })) {
          lastEvents = events;
          if (!controller.isClosed) {
            controller.add(events);
          }
        }
      } catch (e) {
        debugPrint('❌ Error loading events for realtime: $e');
        if (!controller.isClosed && lastEvents.isEmpty) {
          controller.add(<EventModel>[]);
        }
      }
    }

    // 1. IMMEDIATE: Load initial data
    loadAndEmitEvents();

    // 2. TRUE REAL-TIME: Set up Supabase Realtime subscription
    final subscription = SupabaseConfig.client
        .from('events')
        .stream(primaryKey: ['id'])
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .listen((data) {
          // When real-time update comes, reload full data with favorites
          loadAndEmitEvents();
        }, onError: (error) {
          debugPrint('❌ EventService: Realtime subscription error: $error');
        });

    // Clean up subscription when stream is cancelled
    controller.onCancel = () {
      subscription.cancel();
      controller.close();
    };

    return controller.stream;
  }

  // Helper method to get events with polling
  Stream<List<EventModel>> streamEventsWithPolling({Duration? interval}) {
    return Stream.periodic(interval ?? const Duration(seconds: 30),
            (_) async => await getAllEvents())
        .asyncMap((future) => future)
        .handleError((error) {
      debugPrint('❌ Error in event polling: $error');
      return <EventModel>[];
    });
  }

  // ==================== EVENT REGISTRATION METHODS ====================

  Future<EventRegistrationModel?> registerForEvent({
    required String eventId,
    required ProfileModel userProfile,
  }) async {
    try {
      // debugPrint('========================================');
      // debugPrint('🔵 EventService: REGISTER FOR EVENT CALLED');
      // debugPrint('🔵 Event ID: $eventId');
      // debugPrint('========================================');

      final userId = SupabaseConfig.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('❌ EventService: No authenticated user');
        return null;
      }

      // debugPrint('🔵 Step 1: User ID: $userId');

      // Check if already registered
      // debugPrint('🔵 Step 2: Checking if already registered...');
      final alreadyRegistered = await isRegisteredForEvent(eventId, userId);
      // debugPrint(
      //     '🔵 Step 2.1: isRegisteredForEvent returned: $alreadyRegistered');
      if (alreadyRegistered) {
        debugPrint(
            '⚠️ EventService: User already registered for event $eventId');
        return null;
      }

      // debugPrint('🔵 Step 3: User not registered yet, proceeding...');

      // SKIP getEventById - it's causing timeout due to backend being slow
      // Capacity check is already done in the UI before calling this function
      // The event object is already available at the caller side
      // debugPrint(
      //     '🔵 Step 4: Skipping event fetch (optimization) - proceeding directly...');

      // Auto-fill registration data from profile
      // debugPrint(
      //     '🔵 EventService: Creating registration with auto-filled data...');
      final registration = EventRegistrationModel(
        eventId: eventId,
        userId: userId,
        registrationDate: DateTime.now(),
        attendanceStatus: 'pending',
        fullName: userProfile.fullName,
        studentId: userProfile.academicInfo?.studentId ?? '',
        phone: userProfile.phoneNumber ?? '',
        email: SupabaseConfig.auth.currentUser?.email ?? '',
        program: userProfile.academicInfo?.program ?? '',
        department: userProfile.academicInfo?.department ?? '',
        faculty: userProfile.academicInfo?.faculty ?? '',
        relevantSkills: userProfile.skills,
      );

      // debugPrint('🔵 EventService: Registration data prepared');
      final dataToInsert = registration.toJsonForInsert();
      // debugPrint('🔵 EventService: Data to insert: $dataToInsert');

      // debugPrint('🔵 Step 5: Inserting into database...');

      // Insert into database
      final response = await SupabaseConfig.client
          .from('event_participations')
          .insert(dataToInsert)
          .select()
          .single();

      // debugPrint('✅ EventService: Successfully registered for event $eventId');
      // debugPrint('🔵 EventService: Response: $response');

      // Update current participants count in events table
      // debugPrint('🔵 Step 6: Updating participant count...');
      await _incrementParticipantCount(eventId);

      // Send confirmation notification
      // debugPrint('🔵 Step 7: Sending confirmation notification...');
      await AutoNotificationService.sendEventRegistrationConfirmation(
        eventTitle: 'Event Registration',
        eventDate: DateTime.now(),
      );

      return EventRegistrationModel.fromJson(response);
    } on PostgrestException catch (e) {
      debugPrint(
          '❌ EventService: PostgrestException - Code: ${e.code}, Message: ${e.message}');
      debugPrint('❌ EventService: Details: ${e.details}');
      debugPrint('❌ EventService: Hint: ${e.hint}');
      return null;
    } catch (e, stackTrace) {
      debugPrint('❌ EventService: Error registering for event: $e');
      debugPrint('❌ EventService: Stack trace: $stackTrace');
      return null;
    }
  }

  /// Check if user is registered for an event
  Future<bool> isRegisteredForEvent(String eventId, String userId) async {
    try {
      final response = await SupabaseConfig.client
          .from('event_participations')
          .select('id')
          .eq('event_id', eventId)
          .eq('user_id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('❌ EventService: Error checking registration: $e');
      return false;
    }
  }

  /// Get all events the user has registered for
  Future<List<EventRegistrationModel>> getRegisteredEvents(
      String userId) async {
    try {
      final response = await SupabaseConfig.client
          .from('event_participations')
          .select()
          .eq('user_id', userId)
          .order('registration_date', ascending: false);

      return (response as List)
          .map((json) => EventRegistrationModel.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('❌ EventService: Error fetching registered events: $e');
      return [];
    }
  }

  /// OPTIMIZED: Get registered events with full event details in SINGLE query
  /// This avoids the N+1 query problem of calling getEventById() for each registration
  Future<List<Map<String, dynamic>>> getRegisteredEventsWithDetails(
      String userId) async {
    try {
      debugPrint(
          '🔵 getRegisteredEventsWithDetails: Fetching for user $userId');

      // Single query with embedded relation - MUCH faster than loop
      final response = await SupabaseConfig.client
          .from('event_participations')
          .select('''
            *,
            events!event_id (
              id,
              title,
              description,
              image_url,
              category,
              location,
              event_date,
              created_at,
              updated_at,
              is_active,
              price,
              max_participants,
              current_participants,
              registration_open,
              registration_deadline
            )
          ''')
          .eq('user_id', userId)
          .order('registration_date', ascending: false);

      debugPrint(
          '🔵 getRegisteredEventsWithDetails: Got ${(response as List).length} registrations');

      // Filter out registrations where event is null or inactive
      final validResults = (response as List)
          .where((item) =>
              item['events'] != null && item['events']['is_active'] == true)
          .toList();

      debugPrint(
          '🔵 getRegisteredEventsWithDetails: ${validResults.length} valid registrations');

      return List<Map<String, dynamic>>.from(validResults);
    } catch (e) {
      debugPrint(
          '❌ EventService: Error fetching registered events with details: $e');
      return [];
    }
  }

  /// Get registration details for a specific event
  Future<EventRegistrationModel?> getRegistrationDetails(
      String eventId, String userId) async {
    try {
      final response = await SupabaseConfig.client
          .from('event_participations')
          .select()
          .eq('event_id', eventId)
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;

      return EventRegistrationModel.fromJson(response);
    } catch (e) {
      debugPrint('❌ EventService: Error fetching registration details: $e');
      return null;
    }
  }

  /// Cancel event registration
  Future<bool> cancelRegistration(String eventId, String userId) async {
    try {
      await SupabaseConfig.client
          .from('event_participations')
          .delete()
          .eq('event_id', eventId)
          .eq('user_id', userId);

      debugPrint('✅ EventService: Successfully cancelled registration');

      // Decrement participant count
      await _decrementParticipantCount(eventId);

      return true;
    } catch (e) {
      debugPrint('❌ EventService: Error cancelling registration: $e');
      return false;
    }
  }

  /// Submit feedback for attended event
  Future<bool> submitEventFeedback({
    required String eventId,
    required String userId,
    required double rating,
    String? comment,
  }) async {
    try {
      await SupabaseConfig.client
          .from('event_participations')
          .update({
            'feedback_rating': rating,
            'feedback_comment': comment,
          })
          .eq('event_id', eventId)
          .eq('user_id', userId);

      debugPrint('✅ EventService: Successfully submitted feedback');
      return true;
    } catch (e) {
      debugPrint('❌ EventService: Error submitting feedback: $e');
      return false;
    }
  }

  /// Update attendance status (for organizers/admins)
  Future<bool> updateAttendanceStatus({
    required String eventId,
    required String userId,
    required String status, // 'confirmed', 'attended', 'cancelled'
  }) async {
    try {
      await SupabaseConfig.client
          .from('event_participations')
          .update({'attendance_status': status})
          .eq('event_id', eventId)
          .eq('user_id', userId);

      debugPrint('✅ EventService: Successfully updated attendance status');
      return true;
    } catch (e) {
      debugPrint('❌ EventService: Error updating attendance status: $e');
      return false;
    }
  }

  /// Get participant count for an event
  Future<int> getParticipantCount(String eventId) async {
    try {
      final response = await SupabaseConfig.client
          .from('event_participations')
          .select('id')
          .eq('event_id', eventId);

      return (response as List).length;
    } catch (e) {
      debugPrint('❌ EventService: Error getting participant count: $e');
      return 0;
    }
  }

  /// Helper: Increment participant count in events table
  Future<void> _incrementParticipantCount(String eventId) async {
    try {
      debugPrint(
          '🔵 Step 6.1: Getting current participant count directly from Supabase...');

      // Direct query to get current count - MUCH faster than getEventById
      final result = await SupabaseConfig.client
          .from('events')
          .select('current_participants')
          .eq('id', eventId)
          .maybeSingle();

      debugPrint('🔵 Step 6.2: Current count result: $result');

      if (result == null) {
        debugPrint(
            '⚠️ EventService: Event not found for participant count update');
        return;
      }

      final currentCount = result['current_participants'] ?? 0;
      final newCount = currentCount + 1;

      debugPrint(
          '🔵 Step 6.3: Updating count from $currentCount to $newCount...');

      await SupabaseConfig.client
          .from('events')
          .update({'current_participants': newCount}).eq('id', eventId);

      debugPrint('✅ Step 6.4: Incremented participant count to $newCount');
    } catch (e) {
      debugPrint('❌ EventService: Error incrementing participant count: $e');
      // Don't throw - this is non-critical
    }
  }

  /// Helper: Decrement participant count in events table
  Future<void> _decrementParticipantCount(String eventId) async {
    try {
      debugPrint('🔵 Decrement: Getting current participant count...');

      // Direct query - MUCH faster than getEventById
      final result = await SupabaseConfig.client
          .from('events')
          .select('current_participants')
          .eq('id', eventId)
          .maybeSingle();

      if (result == null) {
        debugPrint(
            '⚠️ EventService: Event not found for participant count update');
        return;
      }

      final currentCount = result['current_participants'] ?? 1;
      final newCount = currentCount - 1;
      final finalCount = newCount < 0 ? 0 : newCount;

      debugPrint(
          '🔵 Decrement: Updating count from $currentCount to $finalCount...');

      await SupabaseConfig.client
          .from('events')
          .update({'current_participants': finalCount}).eq('id', eventId);

      debugPrint('✅ Decrement: Done - count is now $finalCount');
    } catch (e) {
      debugPrint('❌ EventService: Error decrementing participant count: $e');
      // Don't throw - this is non-critical
    }
  }
}
