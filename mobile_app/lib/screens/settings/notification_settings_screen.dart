import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/notification_preferences_service.dart';
import '../../models/notification_model.dart';
import '../../utils/app_theme.dart';
import '../../widgets/settings_widgets.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  late NotificationPreferencesService _preferencesService;

  @override
  void initState() {
    super.initState();
    _preferencesService = NotificationPreferencesService();
    _preferencesService.initialize();
  }

  @override
  void dispose() {
    _preferencesService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _preferencesService,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('Notifications'),
          backgroundColor: AppTheme.surfaceColor,
          foregroundColor: AppTheme.textPrimaryColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            color: AppTheme.textPrimaryColor,
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            Consumer<NotificationPreferencesService>(
              builder: (context, service, child) {
                return PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: (value) {
                    switch (value) {
                      case 'enable_all':
                        service.toggleAllTypes(true);
                        _showSnackBar('All notification types enabled');
                        break;
                      case 'disable_all':
                        service.toggleAllTypes(false);
                        _showSnackBar('All notification types disabled');
                        break;
                      case 'reset':
                        _showResetDialog();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'enable_all',
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline_rounded),
                          SizedBox(width: 8),
                          Text('Enable All'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'disable_all',
                      child: Row(
                        children: [
                          Icon(Icons.cancel_outlined),
                          SizedBox(width: 8),
                          Text('Disable All'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'reset',
                      child: Row(
                        children: [
                          Icon(Icons.restore_rounded),
                          SizedBox(width: 8),
                          Text('Reset to Defaults'),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        body: Consumer<NotificationPreferencesService>(
          builder: (context, service, child) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spaceMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Global Settings Section
                  const SettingsSectionHeader(
                    title: 'General Settings',
                    subtitle: 'Control overall notification behavior',
                  ),
                  SettingsCard(
                    child: Column(
                      children: [
                        SettingsToggleItem(
                          icon: Icons.notifications_rounded,
                          title: 'Enable Notifications',
                          subtitle: 'Turn all notifications on or off',
                          value: service.globallyEnabled,
                          onChanged: service.setGloballyEnabled,
                          iconColor: service.globallyEnabled
                              ? AppTheme.successColor
                              : AppTheme.grayColor,
                        ),
                        if (service.globallyEnabled) ...[
                          SettingsToggleItem(
                            icon: Icons.volume_up_rounded,
                            title: 'Sound',
                            subtitle: 'Play sound for notifications',
                            value: service.soundEnabled,
                            onChanged: service.setSoundEnabled,
                            iconColor: AppTheme.infoColor,
                          ),
                          SettingsToggleItem(
                            icon: Icons.vibration_rounded,
                            title: 'Vibration',
                            subtitle: 'Vibrate for notifications',
                            value: service.vibrationEnabled,
                            onChanged: service.setVibrationEnabled,
                            iconColor: AppTheme.warningColor,
                            showDivider: false,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Quiet Hours Section
                  if (service.globallyEnabled) ...[
                    const SettingsSectionHeader(
                      title: 'Quiet Hours',
                      subtitle: 'Silence notifications during specific times',
                    ),
                    SettingsCard(
                      child: Column(
                        children: [
                          SettingsToggleItem(
                            icon: Icons.bedtime_rounded,
                            title: 'Enable Quiet Hours',
                            subtitle: 'Silence notifications during set hours',
                            value: service.quietHoursEnabled,
                            onChanged: service.setQuietHoursEnabled,
                            iconColor: AppTheme.primaryColor,
                          ),
                          if (service.quietHoursEnabled) ...[
                            _buildTimePickerItem(
                              icon: Icons.nightlight_round,
                              title: 'Start Time',
                              subtitle: 'When quiet hours begin',
                              time: service.quietHoursStart,
                              onTimeChanged: service.setQuietHoursStart,
                            ),
                            _buildTimePickerItem(
                              icon: Icons.wb_sunny_rounded,
                              title: 'End Time',
                              subtitle: 'When quiet hours end',
                              time: service.quietHoursEnd,
                              onTimeChanged: service.setQuietHoursEnd,
                              showDivider: false,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  // Notification Types Section
                  if (service.globallyEnabled) ...[
                    const SettingsSectionHeader(
                      title: 'Notification Types',
                      subtitle:
                          'Choose which types of notifications to receive',
                    ),
                    SettingsCard(
                      child: Column(
                        children: NotificationType.values.map((type) {
                          final isLast = type == NotificationType.values.last;
                          return SettingsToggleItem(
                            icon: type.icon,
                            title: type.displayName,
                            subtitle: type.description,
                            value: service.isTypeEnabled(type),
                            onChanged: (enabled) =>
                                service.setTypeEnabled(type, enabled),
                            iconColor: type.color,
                            showDivider: !isLast,
                          );
                        }).toList(),
                      ),
                    ),
                  ],

                  // Status Summary
                  if (service.globallyEnabled) ...[
                    const SizedBox(height: AppTheme.spaceLg),
                    _buildStatusSummary(service),
                  ],

                  const SizedBox(height: AppTheme.spaceXl),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTimePickerItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String time,
    required Function(String) onTimeChanged,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: AppTheme.primaryColor,
              size: 20,
            ),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              time,
              style: const TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          onTap: () => _showTimePicker(time, onTimeChanged),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        ),
        if (showDivider) const Divider(height: 1, indent: 56),
      ],
    );
  }

  Widget _buildStatusSummary(NotificationPreferencesService service) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: AppTheme.primaryColor,
                size: 20,
              ),
              SizedBox(width: AppTheme.spaceSm),
              Text(
                'Notification Status',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Text(
            '${service.enabledTypesCount} of ${NotificationType.values.length} notification types enabled',
            style: const TextStyle(
              color: AppTheme.textSecondaryColor,
              fontSize: 14,
            ),
          ),
          if (service.quietHoursEnabled)
            Text(
              'Quiet hours: ${service.quietHoursStart} - ${service.quietHoursEnd}',
              style: const TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 14,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showTimePicker(
      String currentTime, Function(String) onTimeChanged) async {
    final timeParts = currentTime.split(':');
    final initialTime = TimeOfDay(
      hour: int.parse(timeParts[0]),
      minute: int.parse(timeParts[1]),
    );

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (picked != null) {
      final formattedTime =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      onTimeChanged(formattedTime);
    }
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Defaults'),
        content: const Text(
          'This will reset all notification preferences to their default values. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _preferencesService.resetToDefaults();
              _showSnackBar('Notification preferences reset to defaults');
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }
}
