import 'package:flutter_test/flutter_test.dart';
import 'package:student_talent_profiling_app/models/event_model.dart';
import 'package:student_talent_profiling_app/services/event_service.dart';

/// Quick test file untuk verify Event features
/// Run: flutter test mobile_app/test/event_features_test.dart
void main() {
  group('Event Model Tests', () {
    test('EventModel should parse from JSON correctly', () {
      final json = {
        'id': 'test-id-123',
        'title': 'Tech Conference 2025',
        'description': 'Annual tech conference for students',
        'imageUrl': 'https://example.com/image.jpg',
        'category': 'Technology',
        'favoriteUserIds': ['user1', 'user2'],
        'registerUrl': 'https://register.example.com',
        'createdAt': '2025-01-01T10:00:00.000Z',
        'updatedAt': '2025-01-02T10:00:00.000Z',
      };

      final event = EventModel.fromJson(json);

      expect(event.id, 'test-id-123');
      expect(event.title, 'Tech Conference 2025');
      expect(event.description, 'Annual tech conference for students');
      expect(event.category, 'Technology');
      expect(event.favoriteUserIds.length, 2);
      expect(event.registerUrl, 'https://register.example.com');
    });

    test('EventModel should convert to JSON correctly', () {
      final event = EventModel(
        id: 'test-id-456',
        title: 'Workshop Flutter',
        description: 'Learn Flutter development',
        imageUrl: 'https://example.com/flutter.jpg',
        category: 'Workshop',
        favoriteUserIds: ['user3'],
        registerUrl: 'https://register.flutter.com',
        createdAt: DateTime.parse('2025-02-01T10:00:00.000Z'),
        updatedAt: DateTime.parse('2025-02-02T10:00:00.000Z'),
      );

      final json = event.toJson();

      expect(json['id'], 'test-id-456');
      expect(json['title'], 'Workshop Flutter');
      expect(json['category'], 'Workshop');
      expect(json['favoriteUserIds'], ['user3']);
    });

    test('EventModel copyWith should work correctly', () {
      final originalEvent = EventModel(
        id: 'event-1',
        title: 'Original Title',
        description: 'Original Description',
        imageUrl: '',
        category: 'General',
        favoriteUserIds: [],
        registerUrl: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final updatedEvent = originalEvent.copyWith(
        title: 'Updated Title',
        favoriteUserIds: ['user1', 'user2'],
      );

      expect(updatedEvent.id, originalEvent.id); // Same ID
      expect(updatedEvent.title, 'Updated Title'); // Updated
      expect(updatedEvent.description, originalEvent.description); // Same
      expect(updatedEvent.favoriteUserIds.length, 2); // Updated
    });
  });

  group('Event Service Tests', () {
    test('EventService should be instantiable', () {
      final service = EventService();
      expect(service, isNotNull);
    });

    // Note: Integration tests below require actual Supabase connection
    // These are marked as skip for unit testing
    
    test('getAllEvents should return list', () async {
      final service = EventService();
      
      // This would require actual Supabase connection
      // Just verify method exists and returns Future<List<EventModel>>
      expect(
        service.getAllEvents(),
        isA<Future<List<EventModel>>>(),
      );
    }, skip: 'Requires Supabase connection');

    test('getEventById should return single event or null', () async {
      final service = EventService();
      
      expect(
        service.getEventById('test-id'),
        isA<Future<EventModel?>>(),
      );
    }, skip: 'Requires Supabase connection');

    test('toggleFavorite should complete without error', () async {
      final service = EventService();
      
      expect(
        service.toggleFavorite(
          eventId: 'event-1',
          userId: 'user-1',
          isFavorite: true,
        ),
        completes,
      );
    }, skip: 'Requires Supabase connection');

    test('isEventFavorited should return boolean', () async {
      final service = EventService();
      
      expect(
        service.isEventFavorited('event-1', 'user-1'),
        isA<Future<bool>>(),
      );
    }, skip: 'Requires Supabase connection');

    test('getFavoriteEventIds should return list of IDs', () async {
      final service = EventService();
      
      expect(
        service.getFavoriteEventIds('user-1'),
        isA<Future<List<String>>>(),
      );
    }, skip: 'Requires Supabase connection');
  });

  group('Event Data Validation', () {
    test('EventModel should handle empty values gracefully', () {
      final json = {
        'id': '',
        'title': '',
        'description': '',
        'imageUrl': '',
        'category': '',
        'favoriteUserIds': [],
        'registerUrl': '',
        'createdAt': 0,
        'updatedAt': 0,
      };

      final event = EventModel.fromJson(json);

      expect(event.id, '');
      expect(event.title, '');
      expect(event.favoriteUserIds, isEmpty);
    });

    test('EventModel should handle missing fields', () {
      final json = {
        'id': 'test-id',
        'title': 'Test Event',
        // Missing description, imageUrl, etc.
      };

      final event = EventModel.fromJson(json);

      expect(event.id, 'test-id');
      expect(event.title, 'Test Event');
      expect(event.description, ''); // Default to empty
      expect(event.favoriteUserIds, isEmpty); // Default to empty list
    });
  });
}
