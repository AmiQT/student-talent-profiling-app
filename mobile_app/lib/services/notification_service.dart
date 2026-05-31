import '../config/app_config.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_model.dart';
import 'notification_preferences_service.dart';
import '../config/supabase_config.dart';

/// Service for managing in-app notifications
class NotificationService {
  static String get baseUrl => AppConfig.backendUrl; // Use stable backend URL
  static const String _notificationsKey = 'app_notifications';
  static const String _unreadCountKey = 'unread_notifications_count';
  static const int _maxStoredNotifications = 100;

  final List<AppNotification> _notifications = [];
  final List<Function(List<AppNotification>)> _listeners = [];
  final NotificationPreferencesService _preferencesService =
      NotificationPreferencesService();

  int _unreadCount = 0;
  String? _currentUserId;

  /// Get current unread count
  int get unreadCount => _unreadCount;

  /// Get all notifications
  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  /// Get notification preferences service
  NotificationPreferencesService get preferencesService => _preferencesService;

  /// Initialize notification service
  Future<void> initialize(String userId) async {
    _currentUserId = userId;
    await _preferencesService.initialize();
    await _loadStoredNotifications();
    await _loadUnreadCount();
    _startListeningToFirestore(userId);
  }

  /// Add a listener for notification updates
  void addListener(Function(List<AppNotification>) listener) {
    _listeners.add(listener);
  }

  /// Remove a listener
  void removeListener(Function(List<AppNotification>) listener) {
    _listeners.remove(listener);
  }

  /// Notify all listeners
  void _notifyListeners() {
    for (final listener in _listeners) {
      listener(_notifications);
    }
  }

  /// Start listening to Firestore for real-time notifications
  void _startListeningToFirestore(String userId) {
    // Supabase does not have a direct real-time listener for collections
    // This method will be removed or refactored if real-time functionality is needed
    debugPrint(
        'NotificationService: Supabase does not support real-time listeners for collections.');
  }

  /// Create a notification (saves both locally and to Firestore)
  Future<void> createNotification({
    required String title,
    required String message,
    required NotificationType type,
    String? userId,
    Map<String, dynamic>? data,
    String? actionUrl,
  }) async {
    // Check if this notification type is enabled and if notifications should be shown
    if (!_preferencesService.isTypeEnabled(type) ||
        !_preferencesService.shouldShowNotification()) {
      debugPrint(
          'NotificationService: Notification blocked by preferences - $title');
      return;
    }

    final notificationId = DateTime.now().millisecondsSinceEpoch.toString();
    final notification = AppNotification(
      id: notificationId,
      title: title,
      message: message,
      type: type,
      isRead: false,
      createdAt: DateTime.now(),
      data: data,
      actionUrl: actionUrl,
    );

    // Add to local list
    _notifications.insert(0, notification);

    // Keep only the most recent notifications
    if (_notifications.length > _maxStoredNotifications) {
      _notifications.removeRange(
          _maxStoredNotifications, _notifications.length);
    }

    _updateUnreadCount();
    await _saveNotifications();
    _notifyListeners();

    // Save to Firestore if userId is provided
    if (userId != null) {
      try {
        await SupabaseConfig.from('notifications').insert({
          'userId': userId,
          'title': title,
          'body':
              message, // Changed from 'message' to 'body' to match Supabase schema
          'type': type.toString().split('.').last,
          'isRead': false,
          'createdAt': DateTime.now().toIso8601String(),
          'data': data,
          'actionUrl': actionUrl,
        });
        debugPrint(
            'NotificationService: Saved notification to Supabase - $title');
      } catch (e) {
        debugPrint('Failed to save notification to Supabase: $e');
      }
    }

    debugPrint('NotificationService: Created notification - $title');
  }

  /// Create a local-only notification (backward compatibility)
  Future<void> createLocalNotification({
    required String title,
    required String message,
    required NotificationType type,
    Map<String, dynamic>? data,
    String? actionUrl,
  }) async {
    await createNotification(
      title: title,
      message: message,
      type: type,
      userId: _currentUserId ?? 'local_user',
      data: data,
      actionUrl: actionUrl,
    );
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1 && !_notifications[index].isRead) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      _updateUnreadCount();
      await _saveNotifications();
      _notifyListeners();

      // Update in Supabase if it's a Supabase notification
      try {
        await SupabaseConfig.from('notifications')
            .update({'isRead': true}).eq('id', notificationId);
      } catch (e) {
        // Ignore errors for local notifications
        debugPrint('Failed to update notification in Supabase: $e');
      }
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    bool hasChanges = false;
    for (int i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].isRead) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
        hasChanges = true;
      }
    }

    if (hasChanges) {
      _updateUnreadCount();
      await _saveNotifications();
      _notifyListeners();

      // Update Supabase notifications
      try {
        await SupabaseConfig.client.rpc('mark_all_notifications_read', params: {
          'p_user_id': _currentUserId,
        });
      } catch (e) {
        debugPrint('Failed to mark all notifications as read in Supabase: $e');
      }
    }
  }

  /// Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    _notifications.removeWhere((n) => n.id == notificationId);
    _updateUnreadCount();
    await _saveNotifications();
    _notifyListeners();

    // Delete from Supabase if it exists
    try {
      await SupabaseConfig.from('notifications')
          .delete()
          .eq('id', notificationId);
    } catch (e) {
      // Ignore errors for local notifications
      debugPrint('Failed to delete notification from Supabase: $e');
    }
  }

  /// Clear all notifications
  Future<void> clearAllNotifications() async {
    _notifications.clear();
    _unreadCount = 0;
    await _saveNotifications();
    await _saveUnreadCount();
    _notifyListeners();
  }

  /// Update unread count
  void _updateUnreadCount() {
    _unreadCount = _notifications.where((n) => !n.isRead).length;
    _saveUnreadCount();
  }

  /// Load notifications from local storage
  Future<void> _loadStoredNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = prefs.getString(_notificationsKey);

      if (notificationsJson != null) {
        final List<dynamic> notificationsList = jsonDecode(notificationsJson);
        _notifications.clear();
        _notifications.addAll(
          notificationsList.map((json) => AppNotification.fromJson(json)),
        );
      }
    } catch (e) {
      debugPrint('NotificationService: Error loading stored notifications: $e');
    }
  }

  /// Save notifications to local storage
  Future<void> _saveNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = jsonEncode(
        _notifications.map((n) => n.toJson()).toList(),
      );
      await prefs.setString(_notificationsKey, notificationsJson);
    } catch (e) {
      debugPrint('NotificationService: Error saving notifications: $e');
    }
  }

  /// Load unread count from local storage
  Future<void> _loadUnreadCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _unreadCount = prefs.getInt(_unreadCountKey) ?? 0;
    } catch (e) {
      debugPrint('NotificationService: Error loading unread count: $e');
    }
  }

  /// Save unread count to local storage
  Future<void> _saveUnreadCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_unreadCountKey, _unreadCount);
    } catch (e) {
      debugPrint('NotificationService: Error saving unread count: $e');
    }
  }

  /// Get notifications by type
  List<AppNotification> getNotificationsByType(NotificationType type) {
    return _notifications.where((n) => n.type == type).toList();
  }

  /// Get unread notifications
  List<AppNotification> getUnreadNotifications() {
    return _notifications.where((n) => !n.isRead).toList();
  }

  /// Create achievement verification notification
  Future<void> createAchievementVerificationNotification({
    required String achievementTitle,
    required bool isApproved,
    String? verifierName,
    String? userId,
  }) async {
    await createNotification(
      title: isApproved ? 'Achievement Verified!' : 'Achievement Rejected',
      message: isApproved
          ? 'Your achievement "$achievementTitle" has been verified${verifierName != null ? ' by $verifierName' : ''}.'
          : 'Your achievement "$achievementTitle" was not approved. Please review and resubmit.',
      type: NotificationType.achievement,
      userId: userId,
      data: {
        'achievementTitle': achievementTitle,
        'isApproved': isApproved,
        'verifierName': verifierName,
      },
    );
  }

  /// Create event notification
  Future<void> createEventNotification({
    required String eventTitle,
    required String message,
    String? eventId,
    String? userId,
  }) async {
    await createNotification(
      title: 'Event Update',
      message: message,
      type: NotificationType.event,
      userId: userId,
      data: {
        'eventTitle': eventTitle,
        'eventId': eventId,
      },
      actionUrl: eventId != null ? '/event/$eventId' : null,
    );
  }

  /// Create message notification
  Future<void> createMessageNotification({
    required String senderName,
    required String messagePreview,
    String? conversationId,
    String? userId,
  }) async {
    await createNotification(
      title: 'New Message from $senderName',
      message: messagePreview,
      type: NotificationType.message,
      userId: userId,
      data: {
        'senderName': senderName,
        'conversationId': conversationId,
      },
      actionUrl: conversationId != null ? '/chat/$conversationId' : null,
    );
  }

  /// Dispose resources
  void dispose() {
    _listeners.clear();
  }
}
