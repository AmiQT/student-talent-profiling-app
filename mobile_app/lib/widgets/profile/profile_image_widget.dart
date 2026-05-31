import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class ProfileImageWidget extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final String? fallbackText;
  final Color? backgroundColor;
  final Color? textColor;
  final BoxShape shape;
  final Widget? placeholder;
  final String? cacheKey; // Optional cache key for forcing refresh

  const ProfileImageWidget({
    super.key,
    this.imageUrl,
    this.size = 50.0,
    this.fallbackText,
    this.backgroundColor,
    this.textColor,
    this.shape = BoxShape.circle,
    this.placeholder,
    this.cacheKey,
  });

  /// Clear all cached images
  static Future<void> clearCache() async {
    await DefaultCacheManager().emptyCache();
  }

  /// Clear cache for a specific URL
  static Future<void> clearCacheForUrl(String url) async {
    await DefaultCacheManager().removeFile(url);
  }

  /// Get URL with cache-busting parameter
  String _getImageUrlWithCacheBuster(String url) {
    // Use cacheKey if provided, otherwise use current timestamp
    final version =
        cacheKey ?? DateTime.now().millisecondsSinceEpoch.toString();
    final separator = url.contains('?') ? '&' : '?';
    return '$url${separator}v=$version';
  }

  @override
  Widget build(BuildContext context) {
    // If no image URL or it's a problematic placeholder URL, show fallback
    if (imageUrl == null || imageUrl!.isEmpty || _isProblematicUrl(imageUrl!)) {
      return _buildFallbackWidget(context);
    }

    // Add cache-busting to URL
    final urlWithCacheBuster = _getImageUrlWithCacheBuster(imageUrl!);

    // Try to load the image with error handling
    return CachedNetworkImage(
      imageUrl: urlWithCacheBuster,
      cacheKey: cacheKey ??
          imageUrl, // Use original URL as cache key if no explicit key
      width: size,
      height: size,
      fit: BoxFit.cover,
      placeholder: (context, url) =>
          placeholder ?? _buildFallbackWidget(context),
      errorWidget: (context, url, error) => _buildFallbackWidget(context),
      imageBuilder: (context, imageProvider) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: shape,
          image: DecorationImage(
            image: imageProvider,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackWidget(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor =
        backgroundColor ?? theme.primaryColor.withValues(alpha: 0.1);
    final txtColor = textColor ?? theme.primaryColor;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: shape,
        color: bgColor,
      ),
      child: Center(
        child: Text(
          _getInitials(),
          style: TextStyle(
            color: txtColor,
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String _getInitials() {
    if (fallbackText == null || fallbackText!.isEmpty) {
      return '?';
    }

    final words = fallbackText!.trim().split(' ');
    if (words.isEmpty) return '?';

    if (words.length == 1) {
      return words[0][0].toUpperCase();
    }

    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }

  bool _isProblematicUrl(String url) {
    final problematicDomains = [
      'via.placeholder.com',
      'placeholder.com',
      'dummyimage.com',
      'placehold.it',
    ];

    return problematicDomains.any((domain) => url.contains(domain));
  }
}
