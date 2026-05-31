import 'package:flutter/material.dart';
import 'glass_container.dart';

class BentoCard extends StatelessWidget {
  final Widget child;
  final String? title;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback? onTap;
  final double? height;
  final Color? glassColor;
  final double glassOpacity;
  final bool isDark;
  final CrossAxisAlignment crossAxisAlignment;

  const BentoCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.icon,
    this.onTap,
    this.height,
    this.glassColor,
    this.glassOpacity = 0.05,
    this.isDark = false,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    // Adaptive colors
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Use provided values or adaptive defaults
    final effectiveGlassColor =
        glassColor ?? (isDarkMode ? Colors.white : Colors.black);
    final effectiveOpacity = isDarkMode ? 0.08 : 0.03;
    final effectiveBorderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.black.withValues(alpha: 0.05);
    final effectiveTextColor = isDarkMode ? Colors.white : Colors.black87;

    Widget cardContent = Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null || icon != null) ...[
          Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 18,
                  color: theme.primaryColor,
                ),
                const SizedBox(width: 8),
              ],
              if (title != null)
                Expanded(
                  child: Text(
                    title!,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: effectiveTextColor.withValues(alpha: 0.8),
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
          if (child is! SizedBox) const SizedBox(height: 12),
        ],
        if (subtitle != null) ...[
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: 12,
              color: effectiveTextColor.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Flexible(child: child),
      ],
    );

    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        height: height,
        color: effectiveGlassColor,
        opacity: effectiveOpacity, // Slightly more opaque for cards
        border: Border.all(color: effectiveBorderColor),
        borderRadius: BorderRadius.circular(24), // Softer corners for Bento
        padding: const EdgeInsets.all(20),
        child: cardContent,
      ),
    );
  }
}
