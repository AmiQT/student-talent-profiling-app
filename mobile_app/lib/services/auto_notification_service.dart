import 'package:flutter/foundation.dart';
import 'notification_service.dart';
import '../models/notification_model.dart';
import '../config/supabase_config.dart';

/// Service for automatically creating notifications based on user actions
/// This provides free-tier alternatives to Cloud Functions
class AutoNotificationService {
  static final NotificationService _notificationService = NotificationService();

  /// Initialize the auto notification service
  static Future<void> initialize(String userId) async {
    await _notificationService.initialize(userId);
  }

  /// Create notification when user adds event to favorites
  static Future<void> onEventFavorited({
    required String userId,
    required String eventTitle,
    required String eventId,
  }) async {
    try {
      await _notificationService.createNotification(
        title: 'Event Added to Favorites',
        message:
            'You\'ve added "$eventTitle" to your favorites. We\'ll notify you of any updates!',
        type: NotificationType.event,
        userId: userId,
        data: {
          'eventId': eventId,
          'eventTitle': eventTitle,
          'action': 'favorited',
        },
        actionUrl: '/event/$eventId',
      );

      debugPrint(
          'AutoNotificationService: Created favorite notification for event $eventTitle');
    } catch (e) {
      debugPrint(
          'AutoNotificationService: Error creating favorite notification: $e');
    }
  }

  /// Create notification when user achieves a milestone
  static Future<void> onMilestoneAchieved({
    required String userId,
    required String milestoneTitle,
    required String description,
  }) async {
    try {
      await _notificationService.createNotification(
        title: 'Milestone Achieved! 🎉',
        message: 'Congratulations! You\'ve achieved: $milestoneTitle',
        type: NotificationType.achievement,
        userId: userId,
        data: {
          'milestoneTitle': milestoneTitle,
          'description': description,
          'achievedAt': DateTime.now().toIso8601String(),
        },
      );

      debugPrint(
          'AutoNotificationService: Created milestone notification for $milestoneTitle');
    } catch (e) {
      debugPrint(
          'AutoNotificationService: Error creating milestone notification: $e');
    }
  }

  /// Create notification when user completes profile
  static Future<void> onProfileCompleted({
    required String userId,
    required String userName,
  }) async {
    try {
      await _notificationService.createNotification(
        title: 'Profile Complete! ✅',
        message:
            'Great job, $userName! Your profile is now complete and visible to others.',
        type: NotificationType.system,
        userId: userId,
        data: {
          'action': 'profile_completed',
          'completedAt': DateTime.now().toIso8601String(),
        },
        actionUrl: '/profile',
      );

      debugPrint(
          'AutoNotificationService: Created profile completion notification');
    } catch (e) {
      debugPrint(
          'AutoNotificationService: Error creating profile completion notification: $e');
    }
  }

  /// Create notification when user posts content
  static Future<void> onContentPosted({
    required String userId,
    required String contentType,
    required String contentTitle,
    String? postId,
  }) async {
    try {
      await _notificationService.createNotification(
        title: 'Content Posted Successfully! 📝',
        message:
            'Your $contentType "$contentTitle" has been posted and is now visible to others.',
        type: NotificationType.social,
        userId: userId,
        data: {
          'contentType': contentType,
          'contentTitle': contentTitle,
          'postId': postId,
          'postedAt': DateTime.now().toIso8601String(),
        },
        actionUrl: postId != null ? '/post/$postId' : null,
      );

      debugPrint(
          'AutoNotificationService: Created content posted notification');
    } catch (e) {
      debugPrint(
          'AutoNotificationService: Error creating content posted notification: $e');
    }
  }

  /// Create welcome notification for new users
  static Future<void> onUserWelcome({
    required String userId,
    required String userName,
  }) async {
    try {
      await _notificationService.createNotification(
        title: 'Welcome to UTHM Talent! 👋',
        message:
            'Hi $userName! Welcome to the Student Talent Profiling app. Start by completing your profile and exploring events.',
        type: NotificationType.system,
        userId: userId,
        data: {
          'action': 'welcome',
          'joinedAt': DateTime.now().toIso8601String(),
        },
        actionUrl: '/profile',
      );

      debugPrint('AutoNotificationService: Created welcome notification');
    } catch (e) {
      debugPrint(
          'AutoNotificationService: Error creating welcome notification: $e');
    }
  }

  /// Create reminder notification for incomplete profiles
  static Future<void> onProfileReminder({
    required String userId,
    required String userName,
  }) async {
    try {
      await _notificationService.createNotification(
        title: 'Complete Your Profile 📋',
        message:
            'Hi $userName! Don\'t forget to complete your profile to get the most out of the app.',
        type: NotificationType.reminder,
        userId: userId,
        data: {
          'action': 'profile_reminder',
          'reminderAt': DateTime.now().toIso8601String(),
        },
        actionUrl: '/profile',
      );

      debugPrint(
          'AutoNotificationService: Created profile reminder notification');
    } catch (e) {
      debugPrint(
          'AutoNotificationService: Error creating profile reminder notification: $e');
    }
  }

  /// Create notification when user receives likes/comments
  static Future<void> onSocialInteraction({
    required String userId,
    required String interactionType, // 'like', 'comment', 'share'
    required String fromUserName,
    required String contentTitle,
    String? postId,
  }) async {
    try {
      String title = '';
      String message = '';

      switch (interactionType) {
        case 'like':
          title = 'Someone liked your post! ❤️';
          message = '$fromUserName liked your post "$contentTitle"';
          break;
        case 'comment':
          title = 'New comment on your post! 💬';
          message = '$fromUserName commented on your post "$contentTitle"';
          break;
        case 'share':
          title = 'Your post was shared! 🔄';
          message = '$fromUserName shared your post "$contentTitle"';
          break;
        default:
          title = 'New interaction! 👋';
          message = '$fromUserName interacted with your post "$contentTitle"';
      }

      await _notificationService.createNotification(
        title: title,
        message: message,
        type: NotificationType.social,
        userId: userId,
        data: {
          'interactionType': interactionType,
          'fromUserName': fromUserName,
          'contentTitle': contentTitle,
          'postId': postId,
          'interactionAt': DateTime.now().toIso8601String(),
        },
        actionUrl: postId != null ? '/post/$postId' : null,
      );

      debugPrint(
          'AutoNotificationService: Created social interaction notification');
    } catch (e) {
      debugPrint(
          'AutoNotificationService: Error creating social interaction notification: $e');
    }
  }

  /// Create notification for system announcements
  static Future<void> createSystemAnnouncement({
    required String title,
    required String message,
    List<String>? targetUserIds,
    String? actionUrl,
  }) async {
    try {
      List<String> userIds = targetUserIds ?? [];

      // If no specific users, get all active users
      if (userIds.isEmpty) {
        final usersSnapshot = await SupabaseConfig.from('users')
            .select('id')
            .eq('isActive', true);

        userIds = (usersSnapshot as List<dynamic>?)
                ?.map((item) => item['id'] as String)
                .toList() ??
            [];
      }

      // Create notifications for all target users
      for (final userId in userIds) {
        await SupabaseConfig.from('notifications').insert({
          'userId': userId,
          'title': title,
          'message': message,
          'type': 'system',
          'isRead': false,
          'createdAt': DateTime.now().toIso8601String(),
          'data': {
            'announcement': true,
            'createdAt': DateTime.now().toIso8601String(),
          },
          'actionUrl': actionUrl,
        });
      }

      debugPrint(
          'AutoNotificationService: Created system announcement for ${userIds.length} users');
    } catch (e) {
      debugPrint(
          'AutoNotificationService: Error creating system announcement: $e');
    }
  }

  // ==================== EVENT REGISTRATION NOTIFICATIONS ====================

  /// Create notification when user successfully registers for an event
  static Future<void> sendEventRegistrationConfirmation({
    required String eventTitle,
    required DateTime eventDate,
    String? eventLocation,
  }) async {
    try {
      final userId = SupabaseConfig.auth.currentUser?.id;
      if (userId == null) return;

      final formattedDate = _formatEventDate(eventDate);
      final locationText = eventLocation != null ? ' at $eventLocation' : '';

      await _notificationService.createNotification(
        title: '✅ Registration Confirmed',
        message:
            'You\'re registered for "$eventTitle" on $formattedDate$locationText. See you there!',
        type: NotificationType.event,
        userId: userId,
        data: {
          'eventTitle': eventTitle,
          'eventDate': eventDate.toIso8601String(),
          'eventLocation': eventLocation ?? '',
          'notificationType': 'registration_confirmation',
        },
      );

      debugPrint('AutoNotificationService: Sent registration confirmation for $eventTitle');
    } catch (e) {
      debugPrint('AutoNotificationService: Error sending registration confirmation: $e');
    }
  }

  /// Create notification 24 hours before event
  static Future<void> sendEventReminder24h({
    required String userId,
    required String eventTitle,
    required DateTime eventDate,
    required String eventId,
    String? eventLocation,
  }) async {
    try {
      final formattedDate = _formatEventDate(eventDate);
      final locationText = eventLocation != null ? ' at $eventLocation' : '';

      await _notificationService.createNotification(
        title: '📅 Event Tomorrow',
        message:
            'Reminder: "$eventTitle" is tomorrow ($formattedDate)$locationText. Don\'t forget to attend!',
        type: NotificationType.event,
        userId: userId,
        data: {
          'eventId': eventId,
          'eventTitle': eventTitle,
          'eventDate': eventDate.toIso8601String(),
          'eventLocation': eventLocation ?? '',
          'notificationType': 'reminder_24h',
        },
        actionUrl: '/event/$eventId',
      );

      debugPrint('AutoNotificationService: Sent 24h reminder for $eventTitle');
    } catch (e) {
      debugPrint('AutoNotificationService: Error sending 24h reminder: $e');
    }
  }

  /// Create notification 1 hour before event
  static Future<void> sendEventReminder1h({
    required String userId,
    required String eventTitle,
    required DateTime eventDate,
    required String eventId,
    String? eventLocation,
  }) async {
    try {
      final formattedTime = _formatEventTime(eventDate);
      final locationText = eventLocation != null ? ' at $eventLocation' : '';

      await _notificationService.createNotification(
        title: '⏰ Event Starting Soon',
        message:
            '"$eventTitle" starts in 1 hour ($formattedTime)$locationText. Get ready!',
        type: NotificationType.event,
        userId: userId,
        data: {
          'eventId': eventId,
          'eventTitle': eventTitle,
          'eventDate': eventDate.toIso8601String(),
          'eventLocation': eventLocation ?? '',
          'notificationType': 'reminder_1h',
        },
        actionUrl: '/event/$eventId',
      );

      debugPrint('AutoNotificationService: Sent 1h reminder for $eventTitle');
    } catch (e) {
      debugPrint('AutoNotificationService: Error sending 1h reminder: $e');
    }
  }

  /// Create notification for event check-in
  static Future<void> sendEventCheckInReminder({
    required String userId,
    required String eventTitle,
    required String eventId,
  }) async {
    try {
      await _notificationService.createNotification(
        title: '📍 Event Check-In',
        message:
            'Don\'t forget to check in at "$eventTitle" for attendance verification!',
        type: NotificationType.event,
        userId: userId,
        data: {
          'eventId': eventId,
          'eventTitle': eventTitle,
          'notificationType': 'check_in_reminder',
        },
        actionUrl: '/event/$eventId',
      );

      debugPrint('AutoNotificationService: Sent check-in reminder for $eventTitle');
    } catch (e) {
      debugPrint('AutoNotificationService: Error sending check-in reminder: $e');
    }
  }

  /// Create notification for event feedback request
  static Future<void> sendEventFeedbackRequest({
    required String userId,
    required String eventTitle,
    required String eventId,
  }) async {
    try {
      await _notificationService.createNotification(
        title: '⭐ Share Your Feedback',
        message:
            'How was "$eventTitle"? Your feedback helps us improve future events!',
        type: NotificationType.event,
        userId: userId,
        data: {
          'eventId': eventId,
          'eventTitle': eventTitle,
          'notificationType': 'feedback_request',
        },
        actionUrl: '/event/$eventId/feedback',
      );

      debugPrint('AutoNotificationService: Sent feedback request for $eventTitle');
    } catch (e) {
      debugPrint('AutoNotificationService: Error sending feedback request: $e');
    }
  }

  /// Create notification when registration is cancelled
  static Future<void> sendRegistrationCancellation({
    required String eventTitle,
    required String eventId,
  }) async {
    try {
      final userId = SupabaseConfig.auth.currentUser?.id;
      if (userId == null) return;

      await _notificationService.createNotification(
        title: '❌ Registration Cancelled',
        message:
            'Your registration for "$eventTitle" has been cancelled. You can register again anytime!',
        type: NotificationType.event,
        userId: userId,
        data: {
          'eventId': eventId,
          'eventTitle': eventTitle,
          'notificationType': 'cancellation',
        },
        actionUrl: '/event/$eventId',
      );

      debugPrint('AutoNotificationService: Sent cancellation notification for $eventTitle');
    } catch (e) {
      debugPrint('AutoNotificationService: Error sending cancellation notification: $e');
    }
  }

  // ==================== HELPER METHODS ====================

  /// Format event date for display
  static String _formatEventDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  /// Format event time for display
  static String _formatEventTime(DateTime date) {
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}

