import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/event_model.dart';
import '../../utils/app_theme.dart';

class ModernEventCard extends StatefulWidget {
  final EventModel event;
  final String? currentUserId;
  final Function(EventModel) onTap;
  final Function(EventModel) onFavoriteToggle;
  final Function(EventModel) onShare;

  const ModernEventCard({
    super.key,
    required this.event,
    this.currentUserId,
    required this.onTap,
    required this.onFavoriteToggle,
    required this.onShare,
  });

  @override
  State<ModernEventCard> createState() => _ModernEventCardState();
}

class _ModernEventCardState extends State<ModernEventCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _isFavorite = widget.currentUserId != null &&
        widget.event.favoriteUserIds.contains(widget.currentUserId);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleFavorite() {
    setState(() {
      _isFavorite = !_isFavorite;
    });
    widget.onFavoriteToggle(widget.event);

    // Add animation feedback
    _animationController.forward().then((_) {
      _animationController.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => widget.onTap(widget.event),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              margin: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceMd,
                vertical: AppTheme.spaceXs,
              ),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? Colors.white
                    : theme.cardColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.shadowColor.withValues(alpha: 0.15),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildEventImage(),
                  _buildEventContent(),
                  _buildActionButtons(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEventImage() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppTheme.radiusLg),
            topRight: Radius.circular(AppTheme.radiusLg),
          ),
          child: _buildImageContent(),
        ),
        _buildImageOverlay(),
      ],
    );
  }

  Widget _buildImageContent() {
    if (widget.event.imageUrl.isNotEmpty &&
        _isValidImageUrl(widget.event.imageUrl)) {
      return CachedNetworkImage(
        imageUrl: widget.event.imageUrl,
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          height: 180,
          color: AppTheme.surfaceVariant,
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          ),
        ),
        errorWidget: (context, url, error) => _buildPlaceholderImage(),
      );
    } else {
      return _buildPlaceholderImage();
    }
  }

  Widget _buildPlaceholderImage() {
    final theme = Theme.of(context);
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: theme.brightness == Brightness.dark
              ? [
                  Colors.grey[700]?.withValues(alpha: 0.3) ?? Colors.grey,
                  Colors.grey[600]?.withValues(alpha: 0.4) ?? Colors.grey,
                ]
              : [
                  theme.primaryColor.withValues(alpha: 0.1),
                  theme.primaryColor.withValues(alpha: 0.2),
                ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_rounded,
            size: 48,
            color: theme.brightness == Brightness.dark
                ? Colors.white70
                : theme.primaryColor.withValues(alpha: 0.6),
          ),
          const SizedBox(height: AppTheme.spaceXs),
          Text(
            'Event Image',
            style: TextStyle(
              color: theme.brightness == Brightness.dark
                  ? Colors.white70
                  : theme.primaryColor.withValues(alpha: 0.8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageOverlay() {
    return Positioned(
      top: AppTheme.spaceMd,
      left: AppTheme.spaceMd,
      right: AppTheme.spaceMd,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              _buildCategoryBadge(),
              if (widget.event.isPaid && widget.event.price != null) ...[
                const SizedBox(width: AppTheme.spaceXs),
                _buildPriceBadge(),
              ],
            ],
          ),
          _buildFavoriteButton(),
        ],
      ),
    );
  }

  Widget _buildCategoryBadge() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceSm,
        vertical: AppTheme.spaceXs,
      ),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? Colors.grey[700]?.withValues(alpha: 0.8)
            : theme.primaryColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? (Colors.grey[500] ?? Colors.grey).withValues(alpha: 0.5)
              : theme.primaryColor.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        widget.event.category.toUpperCase(),
        style: TextStyle(
          color:
              theme.brightness == Brightness.dark ? Colors.white : Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 10,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildPriceBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceSm,
        vertical: AppTheme.spaceXs,
      ),
      decoration: BoxDecoration(
        color: AppTheme.secondaryColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        'RM ${(widget.event.price ?? 0).toStringAsFixed(2)}',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 10,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildFavoriteButton() {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: _handleFavorite,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spaceXs),
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.dark
              ? Colors.grey[800]?.withValues(alpha: 0.9)
              : Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          _isFavorite ? Icons.favorite : Icons.favorite_border,
          color: _isFavorite
              ? (theme.brightness == Brightness.dark
                  ? Colors.red[300]
                  : theme.colorScheme.secondary)
              : (theme.brightness == Brightness.dark
                  ? Colors.white70
                  : theme.textTheme.bodyMedium?.color),
          size: 20,
        ),
      ),
    );
  }

  Widget _buildEventContent() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.event.title.isNotEmpty
                ? widget.event.title
                : 'Untitled Event',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.brightness == Brightness.dark
                  ? Colors.black
                  : theme.textTheme.titleLarge?.color,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppTheme.spaceXs),
          Text(
            widget.event.description.isNotEmpty
                ? widget.event.description
                : 'No description available',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.brightness == Brightness.dark
                  ? Colors.grey[600]
                  : theme.textTheme.bodyMedium?.color,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppTheme.spaceSm),
          _buildEventMeta(),
        ],
      ),
    );
  }

  Widget _buildEventMeta() {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          Icons.people_outline_rounded,
          size: 16,
          color: theme.brightness == Brightness.dark
              ? Colors.grey[600]
              : theme.textTheme.bodySmall?.color,
        ),
        const SizedBox(width: AppTheme.spaceXs),
        Text(
          '${widget.event.favoriteUserIds.length} interested',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.brightness == Brightness.dark
                ? Colors.grey[600]
                : theme.textTheme.bodySmall?.color,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Icon(
          Icons.access_time_rounded,
          size: 16,
          color: theme.brightness == Brightness.dark
              ? Colors.grey[600]
              : theme.textTheme.bodySmall?.color,
        ),
        const SizedBox(width: AppTheme.spaceXs),
        Text(
          _formatDate(widget.event.createdAt),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.brightness == Brightness.dark
                ? Colors.grey[600]
                : theme.textTheme.bodySmall?.color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMd,
        vertical: AppTheme.spaceSm,
      ),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? Colors.grey[50]
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AppTheme.radiusLg),
          bottomRight: Radius.circular(AppTheme.radiusLg),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              icon: Icons.info_outline_rounded,
              label: 'View Details',
              onTap: () => widget.onTap(widget.event),
            ),
          ),
          const SizedBox(width: AppTheme.spaceSm),
          _buildIconButton(
            icon: Icons.share_rounded,
            onTap: () => widget.onShare(widget.event),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMd,
          vertical: AppTheme.spaceXs,
        ),
        decoration: BoxDecoration(
          gradient: theme.brightness == Brightness.dark
              ? LinearGradient(
                  colors: [
                    Colors.grey[200] ?? Colors.grey,
                    Colors.grey[100] ?? Colors.grey,
                  ],
                )
              : AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(
            color: theme.brightness == Brightness.dark
                ? Colors.grey[300] ?? Colors.grey
                : theme.primaryColor.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: theme.brightness == Brightness.dark
                  ? Colors.black
                  : Colors.white,
            ),
            const SizedBox(width: AppTheme.spaceXs),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.brightness == Brightness.dark
                    ? Colors.black
                    : Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spaceXs),
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.dark
              ? Colors.grey[100]
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: theme.brightness == Brightness.dark
              ? Colors.grey[600]
              : theme.textTheme.bodyMedium?.color,
        ),
      ),
    );
  }

  bool _isValidImageUrl(String url) {
    if (url.isEmpty) return false;
    if (url.startsWith('data:')) return false;
    if (url.contains('via.placeholder.com')) {
      return false; // Block problematic placeholder
    }
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
