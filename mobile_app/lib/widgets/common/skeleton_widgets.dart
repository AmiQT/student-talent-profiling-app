import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Shimmer base color and highlight color
class SkeletonColors {
  static Color baseColor(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerHighest;

  static Color highlightColor(BuildContext context) =>
      Theme.of(context).colorScheme.surface;
}

/// Base shimmer wrapper
class SkeletonShimmer extends StatelessWidget {
  final Widget child;

  const SkeletonShimmer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: SkeletonColors.baseColor(context),
      highlightColor: SkeletonColors.highlightColor(context),
      child: child,
    );
  }
}

/// Skeleton box for rectangular placeholders
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Skeleton circle for avatars
class SkeletonCircle extends StatelessWidget {
  final double size;

  const SkeletonCircle({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Skeleton for a single post card
class SkeletonPostCard extends StatelessWidget {
  const SkeletonPostCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const SkeletonShimmer(
      child: Card(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row - avatar + name
              Row(
                children: [
                  SkeletonCircle(size: 40),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 120, height: 14),
                        SizedBox(height: 6),
                        SkeletonBox(width: 80, height: 10),
                      ],
                    ),
                  ),
                  SkeletonBox(width: 24, height: 24, borderRadius: 12),
                ],
              ),
              SizedBox(height: 16),

              // Content lines
              SkeletonBox(width: double.infinity, height: 14),
              SizedBox(height: 8),
              SkeletonBox(width: double.infinity, height: 14),
              SizedBox(height: 8),
              SkeletonBox(width: 200, height: 14),
              SizedBox(height: 16),

              // Image placeholder
              SkeletonBox(
                width: double.infinity,
                height: 180,
                borderRadius: 12,
              ),
              SizedBox(height: 16),

              // Action buttons row
              Row(
                children: [
                  SkeletonBox(width: 60, height: 28, borderRadius: 14),
                  SizedBox(width: 12),
                  SkeletonBox(width: 60, height: 28, borderRadius: 14),
                  SizedBox(width: 12),
                  SkeletonBox(width: 60, height: 28, borderRadius: 14),
                  Spacer(),
                  SkeletonBox(width: 28, height: 28, borderRadius: 14),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton for profile header
class SkeletonProfileHeader extends StatelessWidget {
  const SkeletonProfileHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Avatar
            const SkeletonCircle(size: 100),
            const SizedBox(height: 16),

            // Name
            const SkeletonBox(width: 150, height: 24),
            const SizedBox(height: 8),

            // Bio/title
            const SkeletonBox(width: 200, height: 14),
            const SizedBox(height: 24),

            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatSkeleton(),
                _buildStatSkeleton(),
                _buildStatSkeleton(),
              ],
            ),
            const SizedBox(height: 24),

            // Buttons
            const Row(
              children: [
                Expanded(child: SkeletonBox(height: 44, borderRadius: 22)),
                SizedBox(width: 12),
                Expanded(child: SkeletonBox(height: 44, borderRadius: 22)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatSkeleton() {
    return const Column(
      children: [
        SkeletonBox(width: 40, height: 20),
        SizedBox(height: 4),
        SkeletonBox(width: 60, height: 12),
      ],
    );
  }
}

/// Skeleton for event card
class SkeletonEventCard extends StatelessWidget {
  const SkeletonEventCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const SkeletonShimmer(
      child: Card(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            SkeletonBox(
              width: double.infinity,
              height: 150,
              borderRadius: 0,
            ),
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  SkeletonBox(width: double.infinity, height: 18),
                  SizedBox(height: 8),

                  // Date & location
                  Row(
                    children: [
                      SkeletonBox(width: 16, height: 16),
                      SizedBox(width: 8),
                      SkeletonBox(width: 100, height: 12),
                    ],
                  ),
                  SizedBox(height: 6),
                  Row(
                    children: [
                      SkeletonBox(width: 16, height: 16),
                      SizedBox(width: 8),
                      SkeletonBox(width: 120, height: 12),
                    ],
                  ),
                  SizedBox(height: 12),

                  // Button
                  SkeletonBox(width: 100, height: 36, borderRadius: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for chat message
class SkeletonChatMessage extends StatelessWidget {
  final bool isUser;

  const SkeletonChatMessage({super.key, this.isUser = false});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        child: Row(
          mainAxisAlignment:
              isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser) ...[
              const SkeletonCircle(size: 32),
              const SizedBox(width: 8),
            ],
            Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: const [
                SkeletonBox(
                  width: 200,
                  height: 60,
                  borderRadius: 18,
                ),
                SizedBox(height: 4),
                SkeletonBox(width: 60, height: 10),
              ],
            ),
            if (isUser) ...[
              const SizedBox(width: 8),
              const SkeletonCircle(size: 32),
            ],
          ],
        ),
      ),
    );
  }
}

/// Skeleton list for feed
class SkeletonFeedList extends StatelessWidget {
  final int itemCount;

  const SkeletonFeedList({super.key, this.itemCount = 3});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: itemCount,
      itemBuilder: (context, index) => const SkeletonPostCard(),
    );
  }
}

/// Skeleton for achievement card
class SkeletonAchievementCard extends StatelessWidget {
  const SkeletonAchievementCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const SkeletonShimmer(
      child: Card(
        margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              // Badge icon
              SkeletonBox(width: 50, height: 50, borderRadius: 25),
              SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 120, height: 16),
                    SizedBox(height: 6),
                    SkeletonBox(width: 180, height: 12),
                    SizedBox(height: 4),
                    SkeletonBox(width: 80, height: 10),
                  ],
                ),
              ),

              SkeletonBox(width: 24, height: 24, borderRadius: 12),
            ],
          ),
        ),
      ),
    );
  }
}
