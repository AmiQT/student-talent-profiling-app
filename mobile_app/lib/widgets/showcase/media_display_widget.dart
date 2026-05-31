import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/showcase_models.dart';

class MediaDisplayWidget extends StatelessWidget {
  final List<MediaModel> media;
  final Function(int index)? onMediaTap;
  final double? height;
  final BorderRadius? borderRadius;

  const MediaDisplayWidget({
    super.key,
    required this.media,
    this.onMediaTap,
    this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) return const SizedBox.shrink();

    if (media.length == 1) {
      return _buildSingleMedia(context, media.first, 0);
    } else if (media.length == 2) {
      return _buildTwoMedia(context);
    } else if (media.length == 3) {
      return _buildThreeMedia(context);
    } else {
      return _buildMultipleMedia(context);
    }
  }

  Widget _buildSingleMedia(
      BuildContext context, MediaModel mediaItem, int index) {
    return GestureDetector(
      onTap: () => onMediaTap?.call(index),
      child: Container(
        height: height ?? _calculateOptimalHeight(mediaItem),
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: borderRadius ?? BorderRadius.circular(12),
          color: Colors.white, // Always white for showcase cards
        ),
        child: ClipRRect(
          borderRadius: borderRadius ?? BorderRadius.circular(12),
          child: _buildMediaContent(mediaItem, context),
        ),
      ),
    );
  }

  Widget _buildTwoMedia(BuildContext context) {
    return SizedBox(
      height: height ?? 200,
      child: Row(
        children: [
          Expanded(
            child: _buildMediaThumbnail(media[0], 0, context),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: _buildMediaThumbnail(media[1], 1, context),
          ),
        ],
      ),
    );
  }

  Widget _buildThreeMedia(BuildContext context) {
    return SizedBox(
      height: height ?? 200,
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: _buildMediaThumbnail(media[0], 0, context),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: _buildMediaThumbnail(media[1], 1, context),
                ),
                const SizedBox(height: 2),
                Expanded(
                  child: _buildMediaThumbnail(media[2], 2, context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultipleMedia(BuildContext context) {
    return SizedBox(
      height: height ?? 200,
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: _buildMediaThumbnail(media[0], 0, context),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: _buildMediaThumbnail(media[1], 1, context),
                ),
                const SizedBox(height: 2),
                Expanded(
                  child: Stack(
                    children: [
                      _buildMediaThumbnail(media[2], 2, context),
                      if (media.length > 3)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius:
                                borderRadius ?? BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '+${media.length - 3}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaThumbnail(
      MediaModel mediaItem, int index, BuildContext context) {
    return GestureDetector(
      onTap: () => onMediaTap?.call(index),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: borderRadius ?? BorderRadius.circular(8),
          color: Colors.white, // Always white for showcase cards
        ),
        child: ClipRRect(
          borderRadius: borderRadius ?? BorderRadius.circular(8),
          child: _buildMediaContent(mediaItem, context),
        ),
      ),
    );
  }

  Widget _buildMediaContent(MediaModel mediaItem, BuildContext context) {
    // Removed excessive logging to reduce console spam

    // Check for invalid URLs first
    if (mediaItem.url.isEmpty ||
        mediaItem.url.trim().isEmpty ||
        mediaItem.url == 'null' ||
        mediaItem.url == 'file:///' ||
        Uri.tryParse(mediaItem.url)?.hasAbsolutePath != true) {
      debugPrint(
          'MediaDisplayWidget: Invalid URL detected: "${mediaItem.url}"');
      return Container(
        color: Colors.white, // Always white for showcase cards
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.broken_image,
                color: Colors.grey,
                size: 40,
              ),
              SizedBox(height: 8),
              Text(
                'Invalid media URL',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (mediaItem.type == 'video') {
      return Stack(
        fit: StackFit.expand,
        children: [
          // Video thumbnail
          if (mediaItem.thumbnailUrl != null &&
              mediaItem.thumbnailUrl!.isNotEmpty &&
              Uri.tryParse(mediaItem.thumbnailUrl!)?.hasAbsolutePath == true)
            CachedNetworkImage(
              imageUrl: mediaItem.thumbnailUrl!,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.white, // Always white for showcase cards
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.white, // Always white for showcase cards
                child: const Icon(
                  Icons.error,
                  color: Colors.red,
                ),
              ),
            )
          else
            Container(
              color: Colors.black,
              child: const Center(
                child: Icon(
                  Icons.videocam,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
          // Play button overlay
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          // Duration badge
          if (mediaItem.duration != null)
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _formatDuration(mediaItem.duration!),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      );
    } else {
      // Image
      // Check if URL is valid before trying to load
      if (mediaItem.url.isEmpty ||
          Uri.tryParse(mediaItem.url)?.hasAbsolutePath != true) {
        return Container(
          color: Colors.white, // Always white for showcase cards
          child: const Center(
            child: Icon(
              Icons.broken_image,
              color: Colors.grey,
              size: 40,
            ),
          ),
        );
      }

      return CachedNetworkImage(
        imageUrl: mediaItem.url,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: Colors.white, // Always white for showcase cards
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.white, // Always white for showcase cards
          child: const Icon(
            Icons.error,
            color: Colors.red,
          ),
        ),
      );
    }
  }

  double _calculateOptimalHeight(MediaModel mediaItem) {
    if (mediaItem.aspectRatio != null) {
      const maxHeight = 400.0;
      const minHeight = 200.0;
      const screenWidth = 350.0; // Approximate screen width minus padding

      final calculatedHeight = screenWidth / mediaItem.aspectRatio!;
      return calculatedHeight.clamp(minHeight, maxHeight);
    }
    return 250.0; // Default height
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
