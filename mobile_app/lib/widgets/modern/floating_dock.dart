import 'package:flutter/material.dart';
import 'glass_container.dart';
import '../../utils/app_theme.dart';

class FloatingDock extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const FloatingDock({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
      child: GlassContainer(
        borderRadius: BorderRadius.circular(32),
        blur: 20,
        opacity: 0.2, // Slightly more opaque for better visibility
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildDockIcon(context, 0, Icons.home_rounded, Icons.home_outlined),
            _buildDockIcon(context, 1, Icons.search_rounded, Icons.search),
            // AI Center Orb - Highlighted with gradient
            GestureDetector(
              onTap: () => onTap(2),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.4),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: Colors.white, size: 28),
              ),
            ),
            _buildDockIcon(context, 3, Icons.calendar_today_rounded,
                Icons.calendar_today_outlined),
            _buildDockIcon(
                context, 4, Icons.person_rounded, Icons.person_outline_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildDockIcon(BuildContext context, int index, IconData activeIcon,
      IconData inactiveIcon) {
    final isSelected = currentIndex == index;
    final color = isSelected
        ? AppTheme.primaryColor
        : Theme.of(context).iconTheme.color?.withValues(alpha: 0.6);

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        child: AnimatedScale(
          scale: isSelected ? 1.1 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          child: Icon(
            isSelected ? activeIcon : inactiveIcon,
            color: color,
            size: 26,
          ),
        ),
      ),
    );
  }
}
