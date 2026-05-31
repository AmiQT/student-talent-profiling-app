import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'showcase_feed_screen.dart';
import 'post_creation_screen.dart';
import '../../chat/conversation_list_screen.dart';
import '../../../widgets/modern/modern_home_header.dart';
import '../../../widgets/talent_recommendations_widget.dart';
import '../../shared/notifications_screen.dart';
import '../enhanced_student_dashboard.dart';

class ShowcaseScreen extends StatefulWidget {
  const ShowcaseScreen({super.key});

  @override
  State<ShowcaseScreen> createState() => _ShowcaseScreenState();
}

class _ShowcaseScreenState extends State<ShowcaseScreen> {
  final GlobalKey<State<ShowcaseFeedScreen>> _feedScreenKey =
      GlobalKey<State<ShowcaseFeedScreen>>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          ModernHomeHeader(
            onNotificationTap: () => _navigateToNotifications(context),
            onChatTap: () => _navigateToChat(context),
            // Quick Action Callbacks
            onNewPostTap: () => _navigateToNewPost(context),
            onTrendingTap: () => _switchToTab(1), // Search/Trending tab
            onEventsTap: () => _switchToTab(2), // Events tab
          ),
          Expanded(
            child: CustomScrollView(
              slivers: [
                // Talent Discovery Banner & Recommendations
                const SliverToBoxAdapter(
                  child: TalentRecommendationsWidget(
                    showDiscoverBanner: true,
                    showSimilarStudents: true,
                  ),
                ),
                // Feed content
                SliverFillRemaining(
                  child: ShowcaseFeedScreen(key: _feedScreenKey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Switch to a specific tab in the parent dashboard
  void _switchToTab(int pageIndex) {
    // Find the parent dashboard state
    final dashboardState =
        context.findAncestorStateOfType<State<EnhancedStudentDashboard>>();

    if (dashboardState != null) {
      // Access the dashboard state and call its tab switching method
      // The dashboard uses internal page indices: 0=Home, 1=Search, 2=Events, 3=Profile
      // But the dock indices are: 0=Home, 1=Search, 2=AI, 3=Events, 4=Profile
      int dockIndex = pageIndex;
      if (pageIndex >= 2) {
        dockIndex = pageIndex + 1; // Skip AI index
      }

      // Use setState on the dashboard to switch tabs
      (dashboardState as dynamic)._onTabTapped(dockIndex);
      HapticFeedback.lightImpact();
    }
  }

  void _navigateToNotifications(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NotificationsScreen(),
      ),
    );
  }

  /// Navigate to Chat List
  void _navigateToChat(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ConversationListScreen(),
      ),
    );
  }

  /// Navigate to Post Creation screen
  Future<void> _navigateToNewPost(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PostCreationScreen(),
      ),
    );

    // If post was created successfully, refresh the feed
    if (result == true) {
      debugPrint('ShowcaseScreen: Post created, triggering feed refresh...');
      // Access the ShowcaseFeedScreen state via GlobalKey and refresh
      final feedState = _feedScreenKey.currentState;
      if (feedState != null) {
        (feedState as dynamic).forceRefreshFeed();
      }
    }
  }
}
