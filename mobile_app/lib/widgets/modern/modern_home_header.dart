import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import 'glass_container.dart';

class ModernHomeHeader extends StatelessWidget {
  final VoidCallback onNotificationTap;
  final VoidCallback onChatTap;
  final VoidCallback? onNewPostTap;
  final VoidCallback? onTrendingTap;
  final VoidCallback? onEventsTap;

  const ModernHomeHeader({
    super.key,
    required this.onNotificationTap,
    required this.onChatTap,
    this.onNewPostTap,
    this.onTrendingTap,
    this.onEventsTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final glassColor = isDark ? Colors.white : Colors.black;
    final glassOpacity = isDark ? 0.1 : 0.05;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.2)
        : Colors.black.withValues(alpha: 0.1);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopBar(
              context, textColor, glassColor, glassOpacity, borderColor),
          const SizedBox(height: 24),
          _buildWelcomeSection(context, textColor),
          const SizedBox(height: 24),
          _buildQuickActions(context, textColor, glassColor, glassOpacity),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, Color textColor, Color glassColor,
      double glassOpacity, Color borderColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: glassColor.withValues(alpha: glassOpacity),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: borderColor,
                ),
              ),
              child: const Icon(
                Icons.school_rounded,
                color: AppTheme.primaryLightColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'UTHM',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Talent Hub',
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            _buildGlassIconButton(
              icon: Icons.notifications_outlined,
              onTap: onNotificationTap,
              color: textColor,
              glassColor: glassColor,
              glassOpacity: glassOpacity,
              borderColor: borderColor,
              hasBadge: true,
            ),
            const SizedBox(width: 12),
            _buildGlassIconButton(
              icon: Icons.chat_bubble_outline,
              onTap: onChatTap,
              color: textColor,
              glassColor: glassColor,
              glassOpacity: glassOpacity,
              borderColor: borderColor,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGlassIconButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
    required Color glassColor,
    required double glassOpacity,
    required Color borderColor,
    bool hasBadge = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: glassColor.withValues(alpha: glassOpacity),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: borderColor,
              ),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          if (hasBadge)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppTheme.secondaryColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection(BuildContext context, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hello, Student! 👋',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: textColor,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Discover opportunities & showcase your talent.',
          style: TextStyle(
            fontSize: 15,
            color: textColor.withValues(alpha: 0.7),
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context, Color textColor,
      Color glassColor, double glassOpacity) {
    // Only New Post button - Trending and Events removed for MVP
    final actions = [
      {
        'icon': Icons.add_circle_outline,
        'label': 'New Post',
        'onTap': onNewPostTap,
      },
    ];

    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final action = actions[index];
          final onTap = action['onTap'] as VoidCallback?;

          return SizedBox(
            width: 80,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(18),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GlassContainer(
                    width: 56,
                    height: 56,
                    borderRadius: BorderRadius.circular(18),
                    opacity: glassOpacity,
                    color: glassColor,
                    border: Border.all(
                      color: glassColor.withValues(
                          alpha: glassOpacity * 2), // Slightly clearer border
                      width: 1,
                    ),
                    child: Center(
                      child: Icon(
                        action['icon'] as IconData,
                        color: textColor, // Icon uses text color
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    action['label'] as String,
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
