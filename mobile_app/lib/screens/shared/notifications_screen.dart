import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/notification_service.dart';
import '../../services/supabase_auth_service.dart';
import '../../models/notification_model.dart';
import '../../widgets/modern/notification_tile.dart';
import '../../widgets/modern/glass_container.dart';
import '../settings/notification_settings_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  @override
  void dispose() {
    _notificationService.removeListener(_onNotificationsUpdated);
    super.dispose();
  }

  Future<void> _initializeNotifications() async {
    final authService =
        Provider.of<SupabaseAuthService>(context, listen: false);
    final userId = authService.currentUserId;

    if (userId != null) {
      await _notificationService.initialize(userId);
      _notificationService.addListener(_onNotificationsUpdated);
      _onNotificationsUpdated(_notificationService.notifications);
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _onNotificationsUpdated(List<AppNotification> notifications) {
    if (mounted) {
      setState(() {
        // Just trigger rebuild, data comes from service
      });
    }
  }

  Map<String, List<AppNotification>> get _groupedNotifications {
    final grouped = <String, List<AppNotification>>{};
    final notifications = _notificationService.notifications;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (var notification in notifications) {
      final date = notification.createdAt;
      final justDate = DateTime(date.year, date.month, date.day);

      String key;
      if (justDate == today) {
        key = 'Today';
      } else if (justDate == yesterday) {
        key = 'Yesterday';
      } else {
        key = 'Earlier';
      }

      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(notification);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notifications = _notificationService.notifications;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Notifications'),
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        actions: [
          if (notifications.isNotEmpty)
            TextButton(
              onPressed: _notificationService.markAllAsRead,
              child: const Text('Mark all read'),
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationSettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : notifications.isEmpty
              ? _buildEmptyState(theme)
              : RefreshIndicator(
                  onRefresh: () async => await _initializeNotifications(),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      ..._buildGroup('Today'),
                      ..._buildGroup('Yesterday'),
                      ..._buildGroup('Earlier'),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
    );
  }

  List<Widget> _buildGroup(String title) {
    final group = _groupedNotifications[title];
    if (group == null || group.isEmpty) return [];

    return [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            )),
      ),
      ...group.map((n) => NotificationTile(
            notification: n,
            onTap: () {
              if (!n.isRead) _notificationService.markAsRead(n.id);
              // Handle deeper navigation if needed
            },
          )),
    ];
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GlassContainer(
            width: 120,
            height: 120,
            borderRadius: BorderRadius.circular(60),
            color: theme.primaryColor.withValues(alpha: 0.1),
            child: Icon(Icons.notifications_none_rounded,
                size: 50, color: theme.primaryColor),
          ),
          const SizedBox(height: 24),
          Text(
            'All caught up!',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'No new notifications at the moment.',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
