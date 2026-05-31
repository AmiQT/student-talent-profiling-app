import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../../../models/event_model.dart';
import '../../../models/profile_model.dart';
import '../../../services/event_service.dart';
import '../../../services/profile_service.dart';
import '../../../utils/app_theme.dart';
import '../../../config/supabase_config.dart';
import '../../payment/payment_summary_screen.dart';

class ModernEventDetailScreen extends StatefulWidget {
  final EventModel event;

  const ModernEventDetailScreen({
    super.key,
    required this.event,
  });

  @override
  State<ModernEventDetailScreen> createState() =>
      _ModernEventDetailScreenState();
}

class _ModernEventDetailScreenState extends State<ModernEventDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final EventService _eventService = EventService();
  final ProfileService _profileService = ProfileService();
  bool _isFavorite = false;
  bool _isRegistered = false;
  bool _isLoadingRegistration = false;
  String? _userId;
  ProfileModel? _userProfile;

  @override
  void initState() {
    super.initState();
    _userId = SupabaseConfig.auth.currentUser?.id;
    // Initialize from passed event data (may not be accurate)
    _isFavorite =
        _userId != null && widget.event.favoriteUserIds.contains(_userId);

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );

    _animationController.forward();
    _loadRegistrationStatus();
    _loadUserProfile();
    _loadFavoriteStatus(); // Load accurate favorite status from Supabase
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      children: [
                        _buildEventInfo(),
                        _buildEventDescription(),
                        _buildEventMeta(),
                        _buildActionSection(),
                        const SizedBox(height: AppTheme.space2xl),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      backgroundColor: AppTheme.primaryColor,
      leading: Container(
        margin: const EdgeInsets.all(AppTheme.spaceXs),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.all(AppTheme.spaceXs),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          ),
          child: IconButton(
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? AppTheme.secondaryColor : Colors.white,
            ),
            onPressed: _toggleFavorite,
          ),
        ),
        Container(
          margin: const EdgeInsets.all(AppTheme.spaceXs),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          ),
          child: IconButton(
            icon: const Icon(Icons.share_rounded, color: Colors.white),
            onPressed: _shareEvent,
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            _buildEventImage(),
            _buildImageOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildEventImage() {
    if (widget.event.imageUrl.isNotEmpty &&
        _isValidImageUrl(widget.event.imageUrl)) {
      return CachedNetworkImage(
        imageUrl: widget.event.imageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
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
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.8),
            AppTheme.primaryColor,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_rounded,
              size: 80,
              color: Colors.white.withValues(alpha: 0.8),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            Text(
              'Event Image',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.3),
          ],
        ),
      ),
    );
  }

  Widget _buildEventInfo() {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(AppTheme.spaceLg),
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildCategoryBadge(),
              if (widget.event.isPaid && widget.event.price != null) ...[
                const SizedBox(width: AppTheme.spaceSm),
                _buildPriceBadge(),
              ],
              const Spacer(),
              _buildInterestCount(),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMd),
          Text(
            widget.event.title.isNotEmpty
                ? widget.event.title
                : 'Untitled Event',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMd,
        vertical: AppTheme.spaceXs,
      ),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        widget.event.category.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildPriceBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMd,
        vertical: AppTheme.spaceXs,
      ),
      decoration: BoxDecoration(
        color: AppTheme.secondaryColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        boxShadow: [
          BoxShadow(
            color: AppTheme.secondaryColor.withValues(alpha: 0.3),
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
          fontSize: 12,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildInterestCount() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMd,
        vertical: AppTheme.spaceXs,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.people_outline_rounded,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppTheme.spaceXs),
          Text(
            '${widget.event.favoriteUserIds.length} interested',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventDescription() {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLg),
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.description_rounded,
                color: AppTheme.primaryColor,
                size: 20,
              ),
              const SizedBox(width: AppTheme.spaceXs),
              Text(
                'About This Event',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMd),
          Text(
            widget.event.description.isNotEmpty
                ? widget.event.description
                : 'No description available for this event.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventMeta() {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(AppTheme.spaceLg),
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Event Details',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppTheme.spaceMd),
          _buildMetaItem(
            icon: Icons.calendar_today_rounded,
            label: 'Created',
            value: _formatDate(widget.event.createdAt),
          ),
          const SizedBox(height: AppTheme.spaceSm),
          _buildMetaItem(
            icon: Icons.update_rounded,
            label: 'Last Updated',
            value: _formatDate(widget.event.updatedAt),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: AppTheme.primaryColor,
        ),
        const SizedBox(width: AppTheme.spaceXs),
        Text(
          '$label: ',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildActionSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLg),
      child: Column(
        children: [
          // Registration Status Badge
          if (widget.event.eventDate != null) _buildRegistrationStatusBanner(),
          if (widget.event.eventDate != null)
            const SizedBox(height: AppTheme.spaceMd),
          // Register/Cancel Button
          _buildRegisterButton(),
          const SizedBox(height: AppTheme.spaceMd),
          // Secondary Actions
          _buildSecondaryActions(),
        ],
      ),
    );
  }

  Widget _buildRegistrationStatusBanner() {
    // If event doesn't have registration fields, show basic status
    if (widget.event.registrationOpen == null) {
      if (_isRegistered) {
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceMd,
            vertical: AppTheme.spaceSm,
          ),
          decoration: BoxDecoration(
            color: AppTheme.successColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border:
                Border.all(color: AppTheme.successColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: AppTheme.successColor, size: 20),
              const SizedBox(width: AppTheme.spaceSm),
              Expanded(
                child: Text(
                  '✓ You are registered for this event',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.successColor,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        );
      }
      return const SizedBox
          .shrink(); // Don't show banner if no registration fields
    }

    // Event has registration fields - show detailed status
    final canRegister = widget.event.canRegister;
    final spotsLeft = widget.event.spotsLeft;
    final status = widget.event.registrationStatus;

    Color bannerColor;
    IconData bannerIcon;
    String bannerText;

    if (_isRegistered) {
      bannerColor = AppTheme.successColor;
      bannerIcon = Icons.check_circle_rounded;
      bannerText = '✓ You are registered for this event';
    } else if (!canRegister) {
      bannerColor = AppTheme.errorColor;
      bannerIcon = Icons.cancel_rounded;
      bannerText = status;
    } else if (spotsLeft > 0 && spotsLeft <= 10) {
      bannerColor = AppTheme.warningColor;
      bannerIcon = Icons.warning_rounded;
      bannerText = 'Only $spotsLeft spots remaining!';
    } else {
      bannerColor = AppTheme.successColor;
      bannerIcon = Icons.event_available_rounded;
      bannerText = 'Registration Open';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMd,
        vertical: AppTheme.spaceSm,
      ),
      decoration: BoxDecoration(
        color: bannerColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: bannerColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(bannerIcon, color: bannerColor, size: 20),
          const SizedBox(width: AppTheme.spaceSm),
          Expanded(
            child: Text(
              bannerText,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: bannerColor,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          if (spotsLeft > 0 && spotsLeft <= 50 && !_isRegistered)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceSm,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: bannerColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusXs),
              ),
              child: Text(
                '$spotsLeft left',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRegisterButton() {
    // Determine button state
    // If event doesn't have registration fields, allow registration anyway
    final hasRegistrationFields = widget.event.registrationOpen != null;
    final bool canRegister =
        !hasRegistrationFields || (widget.event.canRegister && !_isRegistered);
    final bool showCancelButton = _isRegistered;

    if (showCancelButton) {
      // Show Cancel Registration button
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppTheme.errorColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.errorColor),
        ),
        child: ElevatedButton.icon(
          onPressed: _isLoadingRegistration ? null : _cancelRegistration,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceMd),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
          ),
          icon: _isLoadingRegistration
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppTheme.errorColor),
                  ),
                )
              : const Icon(Icons.cancel_rounded, color: AppTheme.errorColor),
          label: Text(
            _isLoadingRegistration ? 'Cancelling...' : 'Cancel Registration',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.errorColor,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
      );
    }

    if (canRegister) {
      if (widget.event.isPaid &&
          widget.event.price != null &&
          widget.event.price! > 0) {
        // Paid Event Flow
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: _isLoadingRegistration ? null : _handlePaidRegistration,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceMd),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
            ),
            icon: _isLoadingRegistration
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.payment_rounded, color: Colors.white),
            label: Text(
              _isLoadingRegistration
                  ? 'Processing...'
                  : 'Pay RM ${widget.event.price!.toStringAsFixed(2)} & Join',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        );
      }
    }

    // Show Register button
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: canRegister ? AppTheme.primaryGradient : null,
        color: !canRegister
            ? AppTheme.textSecondaryColor.withValues(alpha: 0.3)
            : null,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: canRegister
            ? [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: ElevatedButton.icon(
        onPressed: (_isLoadingRegistration || !canRegister)
            ? null
            : _registerForEventInApp,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceMd),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
        ),
        icon: _isLoadingRegistration
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.event_available_rounded, color: Colors.white),
        label: Text(
          _isLoadingRegistration
              ? 'Registering...'
              : (canRegister ? 'Register for Event' : 'Registration Closed'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
        ),
      ),
    );
  }

  Widget _buildSecondaryActions() {
    // Only Share button - Favorites is already in AppBar icon
    return _buildSecondaryButton(
      icon: Icons.share_rounded,
      label: 'Share Event',
      onTap: _shareEvent,
    );
  }

  Widget _buildSecondaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceMd),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.secondaryColor.withValues(alpha: 0.1)
              : AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: isActive
                ? AppTheme.secondaryColor
                : AppTheme.textSecondaryColor.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive
                  ? AppTheme.secondaryColor
                  : AppTheme.textSecondaryColor,
            ),
            const SizedBox(width: AppTheme.spaceXs),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isActive
                        ? AppTheme.secondaryColor
                        : AppTheme.textPrimaryColor,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  // Action methods
  Future<void> _toggleFavorite() async {
    if (_userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to add favorites')),
      );
      return;
    }

    try {
      await _eventService.toggleFavorite(
        eventId: widget.event.id,
        userId: _userId!,
        isFavorite: !_isFavorite,
      );

      setState(() {
        _isFavorite = !_isFavorite;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isFavorite ? 'Added to favorites' : 'Removed from favorites',
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating favorites: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _shareEvent() {
    Share.share(
      'Check out this event: ${widget.event.title}\n\n${widget.event.description}',
      subject: widget.event.title,
    );
  }

  // ==================== FAVORITE METHODS ====================

  Future<void> _loadFavoriteStatus() async {
    if (_userId == null) return;

    try {
      final isFavorite = await _eventService.isEventFavorited(
        widget.event.id,
        _userId!,
      );
      if (mounted) {
        setState(() {
          _isFavorite = isFavorite;
        });
      }
    } catch (e) {
      debugPrint('Error loading favorite status: $e');
    }
  }

  // ==================== REGISTRATION METHODS ====================

  Future<void> _loadRegistrationStatus() async {
    if (_userId == null) return;

    try {
      final isRegistered =
          await _eventService.isRegisteredForEvent(widget.event.id, _userId!);
      if (mounted) {
        setState(() {
          _isRegistered = isRegistered;
        });
      }
    } catch (e) {
      debugPrint('Error loading registration status: $e');
    }
  }

  Future<void> _loadUserProfile() async {
    if (_userId == null) return;

    try {
      final profile = await _profileService.getProfileByUserId(_userId!);
      if (mounted) {
        setState(() {
          _userProfile = profile;
        });
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
  }

  Future<void> _handlePaidRegistration() async {
    // Navigate to Payment Summary
    final paymentSuccess = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentSummaryScreen(event: widget.event),
      ),
    );

    if (paymentSuccess == true) {
      // If payment successful, proceed to register
      _registerForEventInApp();
    }
  }

  Future<void> _registerForEventInApp() async {
    if (_userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to register for events'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    if (_userProfile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete your profile first'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    // Skip validation if event doesn't have registration fields
    if (widget.event.registrationOpen != null && !widget.event.canRegister) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.event.registrationStatus),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Registration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Register for "${widget.event.title}"?',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            const Text(
                'Your profile information will be automatically filled:'),
            const SizedBox(height: AppTheme.spaceSm),
            _buildInfoRow('Name', _userProfile!.fullName),
            _buildInfoRow(
                'Student ID', _userProfile!.academicInfo?.studentId ?? 'N/A'),
            _buildInfoRow(
                'Program', _userProfile!.academicInfo?.program ?? 'N/A'),
            _buildInfoRow(
                'Email', SupabaseConfig.auth.currentUser?.email ?? 'N/A'),
            if (widget.event.eventDate != null) ...[
              const SizedBox(height: AppTheme.spaceSm),
              const Divider(),
              const SizedBox(height: AppTheme.spaceSm),
              _buildInfoRow(
                  'Event Date',
                  DateFormat('dd MMM yyyy, hh:mm a')
                      .format(widget.event.eventDate!)),
            ],
            if (widget.event.location != null)
              _buildInfoRow('Location', widget.event.location!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm Registration'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoadingRegistration = true;
    });

    try {
      debugPrint('========================================');
      debugPrint('🔵 UI: STARTING REGISTRATION PROCESS');
      debugPrint('Event ID: ${widget.event.id}');
      debugPrint('Event Title: ${widget.event.title}');
      debugPrint('User Profile: ${_userProfile?.fullName}');
      debugPrint('========================================');
      debugPrint('🔵 UI: Starting registration process...');

      final registration = await _eventService.registerForEvent(
        eventId: widget.event.id,
        userProfile: _userProfile!,
      );

      debugPrint('========================================');
      debugPrint('🔵 UI: REGISTRATION COMPLETED');
      debugPrint('Result: ${registration != null ? "SUCCESS ✅" : "FAILED ❌"}');
      debugPrint('========================================');
      debugPrint(
          '🔵 UI: Registration completed, result: ${registration != null ? "Success" : "Failed"}');

      if (mounted) {
        setState(() {
          _isLoadingRegistration = false;
        });

        if (registration != null) {
          // SUCCESS!
          setState(() {
            _isRegistered = true;
          });

          debugPrint('✅ UI: Registration successful, updating UI...');

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Successfully registered for event!'),
              backgroundColor: AppTheme.successColor,
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          // FAILED - Show more specific error
          debugPrint('❌ UI: Registration failed');

          // Check if already registered
          final isAlreadyRegistered = await _eventService.isRegisteredForEvent(
            widget.event.id,
            _userId!,
          );

          if (!mounted) return;

          if (isAlreadyRegistered) {
            // User already registered, update UI
            setState(() {
              _isRegistered = true;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('You are already registered for this event!'),
                backgroundColor: AppTheme.infoColor,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Registration failed. Please check your internet connection and try again.'),
                backgroundColor: AppTheme.errorColor,
                duration: Duration(seconds: 4),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('❌ UI: Exception during registration: $e');

      if (mounted) {
        setState(() {
          _isLoadingRegistration = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _cancelRegistration() async {
    if (_userId == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Registration'),
        content: Text(
          'Are you sure you want to cancel your registration for "${widget.event.title}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No, Keep Registration'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoadingRegistration = true;
    });

    try {
      final success = await _eventService.cancelRegistration(
        widget.event.id,
        _userId!,
      );

      if (mounted) {
        setState(() {
          _isLoadingRegistration = false;
        });

        if (success) {
          setState(() {
            _isRegistered = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Registration cancelled successfully'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to cancel registration'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingRegistration = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Widget _buildInfoRow(String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  bool _isValidImageUrl(String url) {
    if (url.isEmpty) return false;
    if (url.startsWith('data:')) return false;
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  String _formatDate(DateTime dateTime) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];

    return '${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year}';
  }
}
