import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/supabase_auth_service.dart';
import '../../../services/achievement_service.dart';
import '../../../services/profile_service.dart';
import '../../../models/user_model.dart';
import '../../../models/achievement_model.dart';
import '../../../widgets/feedback_list_widget.dart';
import '../chat/chat_screen.dart';
import '../settings/settings_screen.dart';

class LecturerDashboard extends StatefulWidget {
  const LecturerDashboard({super.key});

  @override
  State<LecturerDashboard> createState() => _LecturerDashboardState();
}

class _LecturerDashboardState extends State<LecturerDashboard> {
  UserModel? _currentUser;
  bool _isLoading = true;

  Map<String, dynamic> _stats = {};
  List<AchievementModel> _recentAchievements = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final authService =
          Provider.of<SupabaseAuthService>(context, listen: false);
      final achievementService =
          Provider.of<AchievementService>(context, listen: false);
      final profileService =
          Provider.of<ProfileService>(context, listen: false);

      final user = authService.currentUser;
      if (user != null) {
        _currentUser = await authService.getUserData(user.uid);
      }

      // Load real statistics
      await _loadStatistics(achievementService, profileService);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading dashboard: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadStatistics(AchievementService achievementService,
      ProfileService profileService) async {
    try {
      // Get all achievements
      final allAchievements = await achievementService.getAllAchievements();
      final pendingAchievements =
          await achievementService.getPendingVerifications();
      final verifiedAchievements =
          allAchievements.where((a) => a.isVerified).toList();

      // Get all profiles to count students
      final allProfiles = await profileService.getAllProfiles();

      // Get recent achievements (last 10)
      final recentAchievements = allAchievements.take(10).toList();

      setState(() {
        _stats = {
          'totalStudents': allProfiles.length,
          'pendingVerifications': pendingAchievements.length,
          'verifiedAchievements': verifiedAchievements.length,
          'departmentEvents': 0, // This would need an events service
        };

        _recentAchievements = recentAchievements;
      });
    } catch (e) {
      debugPrint('Error loading statistics: $e');
    }
  }

  void _navigateToFeature(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature feature coming soon!')),
    );
  }

  void _viewAchievementDetails(AchievementModel achievement) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(achievement.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Description: ${achievement.description}'),
            const SizedBox(height: 8),
            Text('Type: ${achievement.type.toString().split('.').last}'),
            const SizedBox(height: 8),
            Text('Points: ${achievement.points ?? 0}'),
            const SizedBox(height: 8),
            Text('Status: ${achievement.isVerified ? 'Verified' : 'Pending'}'),
            const SizedBox(height: 8),
            Text('Created: ${achievement.createdAt.toString().split(' ')[0]}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (!achievement.isVerified)
            ElevatedButton(
              onPressed: () async {
                // Implement achievement verification logic
                // Store context references before async operations
                final navigator = Navigator.of(context);
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                
                try {
                  // Show confirmation dialog
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Verify Achievement'),
                      content: Text(
                          'Are you sure you want to verify "${achievement.title}"?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Verify'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    // Here you would call an achievement service to verify
                    // await achievementService.verifyAchievement(achievement.id);
                    
                    if (mounted) {
                      navigator.pop();
                      scaffoldMessenger.showSnackBar(
                        const SnackBar(
                          content: Text('Achievement verified successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('Error verifying achievement: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Verify'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService =
        Provider.of<SupabaseAuthService>(context, listen: false);
    final userRole = authService.currentUser?.role;
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (userRole == null) {
      return const Scaffold(
        body: Center(child: Text('No user role found.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lecturer Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notifications coming soon!')),
              );
            },
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person),
                    SizedBox(width: 8),
                    Text('Profile'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings),
                    SizedBox(width: 8),
                    Text('Settings'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'logout') {
                Provider.of<SupabaseAuthService>(context, listen: false)
                    .signOut();
              } else if (value == 'settings') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$value feature coming soon!')),
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          child: Text(
                            _currentUser?.name[0] ?? 'L',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome back,',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                              ),
                              Text(
                                _currentUser?.name ?? 'Lecturer',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              Text(
                                _currentUser?.department ?? 'Department',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Statistics Section
            Text(
              'Overview',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: [
                _buildStatCard(
                  'Total Students',
                  _stats['totalStudents'].toString(),
                  Icons.people,
                  Colors.blue,
                ),
                _buildStatCard(
                  'Pending Verifications',
                  _stats['pendingVerifications'].toString(),
                  Icons.pending_actions,
                  Colors.orange,
                ),
                _buildStatCard(
                  'Verified Achievements',
                  _stats['verifiedAchievements'].toString(),
                  Icons.verified,
                  Colors.green,
                ),
                _buildStatCard(
                  'Department Events',
                  _stats['departmentEvents'].toString(),
                  Icons.event,
                  Colors.purple,
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Quick Actions
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
              children: [
                _buildActionCard(
                  'Verify Achievements',
                  Icons.verified_user,
                  Colors.green,
                  () => _navigateToFeature('Achievement Verification'),
                ),
                _buildActionCard(
                  'Student Management',
                  Icons.people_outline,
                  Colors.blue,
                  () => _navigateToFeature('Student Management'),
                ),
                _buildActionCard(
                  'Analytics & Reports',
                  Icons.analytics,
                  Colors.purple,
                  () => _navigateToFeature('Analytics'),
                ),
                _buildActionCard(
                  'Department Events',
                  Icons.event_note,
                  Colors.orange,
                  () => _navigateToFeature('Department Events'),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Recent Achievements
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Achievements',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                TextButton(
                  onPressed: () => _navigateToFeature('View All Achievements'),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Card(
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _recentAchievements.length,
                itemBuilder: (context, index) {
                  final achievement = _recentAchievements[index];
                  final status =
                      achievement.isVerified ? 'Verified' : 'Pending';
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getStatusColor(status),
                      child: Icon(
                        _getStatusIcon(status),
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      achievement
                          .userId, // This would need to be resolved to student name
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(achievement.title),
                        Text(
                          '${achievement.type.toString().split('.').last} • ${achievement.createdAt.toString().split(' ')[0]}',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                _getStatusColor(status).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _getStatusColor(status),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          achievement.createdAt.toString().split(' ')[0],
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    onTap: () => _viewAchievementDetails(achievement),
                  );
                },
              ),
            ),

            const SizedBox(height: 32),

            // Department News & Updates
            Text(
              'Department Updates',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.newspaper, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Latest Updates',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildUpdateItem(
                      'New achievement verification guidelines have been published',
                      '2 hours ago',
                    ),
                    const Divider(),
                    _buildUpdateItem(
                      'Department meeting scheduled for next Friday',
                      '1 day ago',
                    ),
                    const Divider(),
                    _buildUpdateItem(
                      'Student showcase event registration is now open',
                      '3 days ago',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            const Text('Student Showcase Feedback',
                style: TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            const Expanded(child: FeedbackListWidget(feedbackList: [])),
          ],
        ),
      ),
      floatingActionButton:
          (userRole == UserRole.student || userRole == UserRole.lecturer)
              ? FloatingActionButton(
                  heroTag: "lecturer_dashboard_chat_fab",
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ChatScreen()),
                    );
                  },
                  tooltip: 'Chatbot',
                  child: const Icon(Icons.chat),
                )
              : null,
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: color,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 32,
                color: color,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpdateItem(String text, String time) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            time,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'verified':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'verified':
        return Icons.check_circle;
      case 'pending':
        return Icons.pending;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }
}
