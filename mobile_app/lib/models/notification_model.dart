import 'package:flutter/material.dart';

/// Enum for different types of notifications
enum NotificationType {
  achievement,
  event,
  message,
  system,
  reminder,
  social,
}

/// Model for app notifications
class AppNotification {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic>? data;
  final String? actionUrl;
  final String? imageUrl;

  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.data,
    this.actionUrl,
    this.imageUrl,
  });

  /// Create a copy with updated fields
  AppNotification copyWith({
    String? id,
    String? title,
    String? message,
    NotificationType? type,
    bool? isRead,
    DateTime? createdAt,
    Map<String, dynamic>? data,
    String? actionUrl,
    String? imageUrl,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      data: data ?? this.data,
      actionUrl: actionUrl ?? this.actionUrl,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type.name,
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(),
      'data': data,
      'actionUrl': actionUrl,
      'imageUrl': imageUrl,
    };
  }

  /// Create from JSON
  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => NotificationType.system,
      ),
      isRead: json['isRead'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      data: json['data'] as Map<String, dynamic>?,
      actionUrl: json['actionUrl'],
      imageUrl: json['imageUrl'],
    );
  }

  /// Get icon for notification type
  IconData get icon {
    switch (type) {
      case NotificationType.achievement:
        return Icons.emoji_events_rounded;
      case NotificationType.event:
        return Icons.event_rounded;
      case NotificationType.message:
        return Icons.message_rounded;
      case NotificationType.system:
        return Icons.info_rounded;
      case NotificationType.reminder:
        return Icons.alarm_rounded;
      case NotificationType.social:
        return Icons.people_rounded;
    }
  }

  /// Get color for notification type
  Color get color {
    switch (type) {
      case NotificationType.achievement:
        return Colors.amber;
      case NotificationType.event:
        return Colors.blue;
      case NotificationType.message:
        return Colors.green;
      case NotificationType.system:
        return const Color(0xFF6B7280); // Neutral grey
      case NotificationType.reminder:
        return Colors.orange;
      case NotificationType.social:
        return Colors.purple;
    }
  }

  /// Get formatted time ago string
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppNotification && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'AppNotification(id: $id, title: $title, type: $type, isRead: $isRead)';
  }
}

/// Extension for notification type display names
extension NotificationTypeExtension on NotificationType {
  String get displayName {
    switch (this) {
      case NotificationType.achievement:
        return 'Achievement';
      case NotificationType.event:
        return 'Event';
      case NotificationType.message:
        return 'Message';
      case NotificationType.system:
        return 'System';
      case NotificationType.reminder:
        return 'Reminder';
      case NotificationType.social:
        return 'Social';
    }
  }

  String get description {
    switch (this) {
      case NotificationType.achievement:
        return 'Achievement verifications and updates';
      case NotificationType.event:
        return 'Event announcements and reminders';
      case NotificationType.message:
        return 'New messages and conversations';
      case NotificationType.system:
        return 'System updates and announcements';
      case NotificationType.reminder:
        return 'Important reminders and deadlines';
      case NotificationType.social:
        return 'Social interactions and updates';
    }
  }

  /// Get icon for notification type
  IconData get icon {
    switch (this) {
      case NotificationType.achievement:
        return Icons.emoji_events_rounded;
      case NotificationType.event:
        return Icons.event_rounded;
      case NotificationType.message:
        return Icons.message_rounded;
      case NotificationType.system:
        return Icons.info_rounded;
      case NotificationType.reminder:
        return Icons.alarm_rounded;
      case NotificationType.social:
        return Icons.people_rounded;
    }
  }

  /// Get color for notification type
  Color get color {
    switch (this) {
      case NotificationType.achievement:
        return Colors.amber;
      case NotificationType.event:
        return Colors.blue;
      case NotificationType.message:
        return Colors.green;
      case NotificationType.system:
        return const Color(0xFF6B7280); // Neutral grey
      case NotificationType.reminder:
        return Colors.orange;
      case NotificationType.social:
        return Colors.purple;
    }
  }
}
