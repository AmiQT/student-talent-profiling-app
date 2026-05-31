import 'package:flutter/material.dart';
import '../../models/notification_model.dart';
import 'glass_container.dart';

class NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: GlassContainer(
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 8),
        color: notification.isRead
            ? theme.scaffoldBackgroundColor.withValues(alpha: 0.5)
            : theme.colorScheme.primaryContainer.withValues(alpha: 0.1),
        border: notification.isRead
            ? Border.all(color: Colors.transparent)
            : Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.2)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon / Avatar
            _buildLeadingIcon(theme),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: notification.isRead
                                ? FontWeight.w600
                                : FontWeight.bold,
                            color: notification.isRead
                                ? theme.textTheme.bodyMedium?.color
                                : theme.textTheme.bodyLarge?.color,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        notification.timeAgo,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          color: theme.textTheme.bodySmall?.color
                              ?.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 12,
                      color: theme.textTheme.bodyMedium?.color
                          ?.withValues(alpha: 0.8),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Optional Action Buttons (Mock for specific types)
                  if (_isFriendRequest) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildActionButton(context, 'Accept', true),
                        const SizedBox(width: 8),
                        _buildActionButton(context, 'Decline', false),
                      ],
                    )
                  ]
                ],
              ),
            ),
            if (!notification.isRead)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool get _isFriendRequest =>
      notification.type == NotificationType.social &&
      notification.title.toLowerCase().contains('request');

  Widget _buildLeadingIcon(ThemeData theme) {
    if (notification.imageUrl != null) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(notification.imageUrl!),
      );
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: notification.color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        notification.icon,
        color: notification.color,
        size: 20,
      ),
    );
  }

  Widget _buildActionButton(
      BuildContext context, String label, bool isPrimary) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () {
        // Handle friend request action
        onTap(); // Trigger the main tap callback to handle the action
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isPrimary ? 'Request accepted!' : 'Request declined'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isPrimary ? theme.colorScheme.primary : Colors.transparent,
          border: Border.all(
            color: isPrimary ? Colors.transparent : theme.dividerColor,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isPrimary
                ? theme.colorScheme.onPrimary
                : theme.textTheme.bodyMedium?.color,
          ),
        ),
      ),
    );
  }
}
