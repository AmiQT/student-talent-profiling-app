import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/supabase_auth_service.dart';
import '../../models/user_model.dart';
import '../../widgets/settings_widgets.dart';
import '../../widgets/settings/language_selector.dart';
import '../../widgets/settings/theme_selector.dart';

import 'account_settings_screen.dart';
import 'security_settings_screen.dart';
import 'notification_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  UserModel? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Show any pending error messages after the widget tree is built
    if (!_isLoading && _currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                  'No user data found. Please try logging out and back in.'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      });
    }
  }

  Future<void> _loadUserData() async {
    try {
      final authService =
          Provider.of<SupabaseAuthService>(context, listen: false);
      final currentUser = authService.currentUser;

      if (currentUser != null && mounted) {
        setState(() {
          _currentUser = currentUser;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // Don't show snackbar here - let didChangeDependencies handle it
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // Show error message after the widget tree is built
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error loading user data: ${e.toString()}'),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        });
      }
    }
  }

  void _navigateToAccountSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AccountSettingsScreen(),
      ),
    );
  }

  void _navigateToSecuritySettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SecuritySettingsScreen(),
      ),
    );
  }

  void _navigateToNotificationSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NotificationSettingsScreen(),
      ),
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'Student Talent Profiling',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.school, size: 48),
      children: [
        const Text(
          'A comprehensive platform for managing student profiles, achievements, and talent development.',
        ),
      ],
    );
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await Provider.of<SupabaseAuthService>(context, listen: false)
            .signOut();
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/login',
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error signing out: ${e.toString()}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: 0.5,
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: theme.primaryColor,
              ),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 16),

                  // User Profile Header
                  if (_currentUser != null)
                    SettingsCard(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: theme.colorScheme.primary
                                  .withValues(alpha: 0.1),
                              child: Text(
                                _currentUser!.name.isNotEmpty
                                    ? _currentUser!.name[0].toUpperCase()
                                    : 'U',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _currentUser!.name,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: theme.brightness == Brightness.dark
                                          ? Colors.black
                                          : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _currentUser!.email,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: theme.brightness == Brightness.dark
                                          ? Colors.grey[600]
                                          : theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _currentUser!.role
                                          .toString()
                                          .split('.')
                                          .last
                                          .toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Account Section
                  const SettingsSectionHeader(
                    title: 'Account',
                    subtitle: 'Manage your account',
                  ),
                  SettingsCard(
                    child: Column(
                      children: [
                        SettingsItem(
                          icon: Icons.person,
                          title: 'Account Information',
                          subtitle: 'Update personal details',
                          onTap: _navigateToAccountSettings,
                        ),
                        SettingsItem(
                          icon: Icons.security,
                          title: 'Security',
                          subtitle: 'Password and security',
                          onTap: _navigateToSecuritySettings,
                          showDivider: false,
                        ),
                      ],
                    ),
                  ),

                  // Preferences Section
                  const SettingsSectionHeader(
                    title: 'Preferences',
                    subtitle: 'Customize your experience',
                  ),

                  // Theme Selector
                  const ThemeSelector(),

                  SettingsCard(
                    child: Column(
                      children: [
                        SettingsItem(
                          icon: Icons.notifications,
                          title: 'Notifications',
                          subtitle: 'Manage notification preferences',
                          onTap: _navigateToNotificationSettings,
                        ),
                        const LanguageSelector(),
                      ],
                    ),
                  ),

                  // Support Section
                  const SettingsSectionHeader(
                    title: 'Support',
                    subtitle: 'Get help and information',
                  ),
                  SettingsCard(
                    child: Column(
                      children: [
                        SettingsItem(
                          icon: Icons.help,
                          title: 'Help & Support',
                          subtitle: 'Get help with app',
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Help & Support coming soon!'),
                              ),
                            );
                          },
                        ),
                        SettingsItem(
                          icon: Icons.info,
                          title: 'About',
                          subtitle: 'App version and information',
                          onTap: _showAboutDialog,
                        ),
                        SettingsItem(
                          icon: Icons.privacy_tip,
                          title: 'Privacy Policy',
                          subtitle: 'Read privacy policy',
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Privacy Policy coming soon!'),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  // Sign Out
                  const SizedBox(height: 16),
                  SettingsActionButton(
                    text: 'Logout',
                    icon: Icons.logout,
                    onPressed: _handleSignOut,
                    isDestructive: true,
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}
