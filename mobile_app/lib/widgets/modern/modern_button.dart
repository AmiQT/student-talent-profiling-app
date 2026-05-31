import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/app_theme.dart';

enum ModernButtonType {
  primary,
  secondary,
  outline,
  text,
  danger,
}

enum ModernButtonSize {
  small,
  medium,
  large,
}

class ModernButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final ModernButtonType type;
  final ModernButtonSize size;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;
  final Color? customColor;
  final Color? customTextColor;
  final double? customBorderRadius;
  final EdgeInsetsGeometry? customPadding;

  const ModernButton({
    super.key,
    required this.text,
    this.onPressed,
    this.type = ModernButtonType.primary,
    this.size = ModernButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.customColor,
    this.customTextColor,
    this.customBorderRadius,
    this.customPadding,
  });

  @override
  State<ModernButton> createState() => _ModernButtonState();
}

class _ModernButtonState extends State<ModernButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      setState(() {
        _isPressed = true;
      });
      _animationController.forward();
      HapticFeedback.lightImpact();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    _handleTapEnd();
  }

  void _handleTapCancel() {
    _handleTapEnd();
  }

  void _handleTapEnd() {
    if (_isPressed) {
      setState(() {
        _isPressed = false;
      });
      _animationController.reverse();
    }
  }

  Color _getBackgroundColor() {
    if (widget.customColor != null) {
      return widget.customColor!;
    }

    switch (widget.type) {
      case ModernButtonType.primary:
        return AppTheme.primaryColor;
      case ModernButtonType.secondary:
        return AppTheme.secondaryColor;
      case ModernButtonType.outline:
        return Colors.transparent;
      case ModernButtonType.text:
        return Colors.transparent;
      case ModernButtonType.danger:
        return AppTheme.errorColor;
    }
  }

  Color _getTextColor() {
    if (widget.customTextColor != null) {
      return widget.customTextColor!;
    }

    switch (widget.type) {
      case ModernButtonType.primary:
      case ModernButtonType.secondary:
      case ModernButtonType.danger:
        return Colors.white;
      case ModernButtonType.outline:
        return AppTheme.primaryColor;
      case ModernButtonType.text:
        return AppTheme.primaryColor;
    }
  }

  BorderSide _getBorderSide() {
    switch (widget.type) {
      case ModernButtonType.outline:
        return BorderSide(
          color: widget.customColor ?? AppTheme.primaryColor,
          width: 2.0,
        );
      default:
        return BorderSide.none;
    }
  }

  EdgeInsetsGeometry _getPadding() {
    if (widget.customPadding != null) {
      return widget.customPadding!;
    }

    switch (widget.size) {
      case ModernButtonSize.small:
        return const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMd,
          vertical: AppTheme.spaceSm,
        );
      case ModernButtonSize.medium:
        return const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceLg,
          vertical: AppTheme.spaceMd,
        );
      case ModernButtonSize.large:
        return const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceXl,
          vertical: AppTheme.spaceLg,
        );
    }
  }

  double _getFontSize() {
    switch (widget.size) {
      case ModernButtonSize.small:
        return 14.0;
      case ModernButtonSize.medium:
        return 16.0;
      case ModernButtonSize.large:
        return 18.0;
    }
  }

  double _getIconSize() {
    switch (widget.size) {
      case ModernButtonSize.small:
        return 16.0;
      case ModernButtonSize.medium:
        return 20.0;
      case ModernButtonSize.large:
        return 24.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null || widget.isLoading;
    final backgroundColor = _getBackgroundColor();
    final textColor = _getTextColor();

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: _handleTapDown,
            onTapUp: _handleTapUp,
            onTapCancel: _handleTapCancel,
            child: Container(
              width: widget.isFullWidth ? double.infinity : null,
              decoration: BoxDecoration(
                color: isDisabled 
                    ? backgroundColor.withValues(alpha: 0.5)
                    : backgroundColor,
                borderRadius: BorderRadius.circular(
                  widget.customBorderRadius ?? AppTheme.radiusMd,
                ),
                border: Border.fromBorderSide(_getBorderSide()),
                boxShadow: [
                  if (!isDisabled && widget.type != ModernButtonType.text)
                    BoxShadow(
                      color: backgroundColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isDisabled ? null : widget.onPressed,
                  borderRadius: BorderRadius.circular(
                    widget.customBorderRadius ?? AppTheme.radiusMd,
                  ),
                  child: Container(
                    padding: _getPadding(),
                    child: Row(
                      mainAxisSize: widget.isFullWidth 
                          ? MainAxisSize.max 
                          : MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.isLoading) ...[
                          SizedBox(
                            width: _getIconSize(),
                            height: _getIconSize(),
                            child: CircularProgressIndicator(
                              strokeWidth: 2.0,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                textColor.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppTheme.spaceSm),
                        ] else if (widget.icon != null) ...[
                          Icon(
                            widget.icon,
                            size: _getIconSize(),
                            color: isDisabled 
                                ? textColor.withValues(alpha: 0.5)
                                : textColor,
                          ),
                          const SizedBox(width: AppTheme.spaceSm),
                        ],
                        
                        Text(
                          widget.text,
                          style: TextStyle(
                            fontSize: _getFontSize(),
                            fontWeight: FontWeight.w600,
                            color: isDisabled 
                                ? textColor.withValues(alpha: 0.5)
                                : textColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
