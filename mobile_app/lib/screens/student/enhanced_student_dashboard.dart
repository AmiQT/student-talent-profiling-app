import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/supabase_auth_service.dart';
import '../../services/profile_service.dart';

import '../../utils/app_theme.dart';
import '../../widgets/modern/floating_dock.dart';
import 'showcase/showcase_screen.dart';
import 'search/enhanced_search_screen.dart';
import 'event_program/event_program_screen.dart';
import 'profile/student_profile_screen.dart';
import '../chat/chat_screen.dart';

class EnhancedStudentDashboard extends StatefulWidget {
  const EnhancedStudentDashboard({super.key});

  @override
  State<EnhancedStudentDashboard> createState() =>
      _EnhancedStudentDashboardState();
}

class _EnhancedStudentDashboardState extends State<EnhancedStudentDashboard>
    with TickerProviderStateMixin {
  int _currentIndex = 0;

  late TabController _tabController;
  late AnimationController _animationController;

  bool _isLoading = true;

  final List<Widget> _pages = [
    const ShowcaseScreen(),
    const EnhancedSearchScreen(),
    const EventProgramScreen(),
    const StudentProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 100), // FAST: Reduced from 300ms
      vsync: this,
    );

    _loadUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final authService =
          Provider.of<SupabaseAuthService>(context, listen: false);
      final profileService =
          Provider.of<ProfileService>(context, listen: false);

      final user = authService.currentUser;
      if (user != null) {
        // Load user data if needed in the future
        await authService.getUserData(user.uid);
        await profileService.getProfileByUserId(user.uid);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading dashboard: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
      _animationController.forward();
    }
  }

  void _onTabTapped(int index) {
    // Index 2 is the AI Orb (Middle)
    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ChatScreen(),
        ),
      );
      return;
    }

    if (_currentIndex == index) return;

    // Adjust index for internal pages list (skip index 2)
    // Dock Indices: 0 (Home), 1 (Search), 2 (AI), 3 (Events), 4 (Profile)
    // Page Indices: 0 (Home), 1 (Search),     2 (Events), 3 (Profile)
    int internalIndex = index;
    if (index > 2) {
      internalIndex = index - 1;
    }

    setState(() {
      _currentIndex =
          internalIndex; // Note: Floating Dock needs to know real index, but we map it visually
    });

    // Haptic feedback
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spaceLg),
                decoration: BoxDecoration(
                  color: Colors.white, // Always white for better visibility
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black.withValues(alpha: 0.1), // Lighter shadow
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spaceLg),
              Text(
                'Loading your dashboard...',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
          Colors.transparent, // Background handled by Stack or Container
      body: Stack(
        children: [
          // Main Body Content
          SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                      CurvedAnimation(parent: animation, curve: Curves.easeOut),
                    ),
                    child: child,
                  ),
                );
              },
              child: IndexedStack(
                key: ValueKey<int>(_currentIndex),
                index: _currentIndex,
                children: _pages,
              ),
            ),
          ),

          // Floating Dock Navigation
          Align(
            alignment: Alignment.bottomCenter,
            child: FloatingDock(
              // Map internal index back to dock index
              // Page: 0 -> Dock: 0
              // Page: 1 -> Dock: 1
              // Page: 2 -> Dock: 3
              // Page: 3 -> Dock: 4
              currentIndex:
                  _currentIndex >= 2 ? _currentIndex + 1 : _currentIndex,
              onTap: _onTabTapped,
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildChatbotButton() {
    // Kept for reference but not used with FloatingDock
    return Container();
  }
}

class NavigationItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Color color;

  NavigationItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.color,
  });
}
