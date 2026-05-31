import 'package:flutter/material.dart';

/// Custom UTHM-branded refresh indicator
class UTHMRefreshIndicator extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final GlobalKey<RefreshIndicatorState>? refreshKey;

  const UTHMRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
    this.refreshKey,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      key: refreshKey,
      onRefresh: onRefresh,
      backgroundColor: Theme.of(context).colorScheme.primary,
      color: Theme.of(context).colorScheme.onPrimary,
      strokeWidth: 3,
      displacement: 60,
      edgeOffset: 0,
      child: child,
    );
  }
}

/// Animated refresh indicator with UTHM logo
class UTHMAnimatedRefreshIndicator extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;

  const UTHMAnimatedRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
  });

  @override
  State<UTHMAnimatedRefreshIndicator> createState() =>
      _UTHMAnimatedRefreshIndicatorState();
}

class _UTHMAnimatedRefreshIndicatorState
    extends State<UTHMAnimatedRefreshIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    _controller.repeat();

    await widget.onRefresh();

    _controller.stop();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      color: Theme.of(context).colorScheme.primary,
      strokeWidth: 3,
      displacement: 60,
      child: widget.child,
      // Custom indicator builder
      notificationPredicate: (notification) {
        return notification.depth == 0;
      },
    );
  }
}

/// Pull-to-refresh wrapper with haptic feedback
class EnhancedRefreshIndicator extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final String? refreshingText;
  final String? pullingText;

  const EnhancedRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
    this.refreshingText,
    this.pullingText,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator.adaptive(
      onRefresh: () async {
        // Add haptic feedback
        // HapticFeedback.mediumImpact(); // Uncomment if needed
        await onRefresh();
      },
      backgroundColor: Theme.of(context).colorScheme.primary,
      color: Theme.of(context).colorScheme.onPrimary,
      strokeWidth: 2.5,
      displacement: 50,
      child: child,
    );
  }
}
