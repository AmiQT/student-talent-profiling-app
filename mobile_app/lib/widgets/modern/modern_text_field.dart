import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/app_theme.dart';

class ModernTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hintText;
  final IconData? icon;
  final bool obscureText;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final int maxLines;
  final int? maxLength;
  final bool enabled;
  final VoidCallback? onTap;
  final Function(String)? onChanged;
  final Function(String)? onSubmitted;
  final TextCapitalization textCapitalization;
  final bool autofocus;
  final FocusNode? focusNode;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final Color? fillColor;
  final bool readOnly;

  const ModernTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hintText,
    this.icon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.validator,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
    this.onTap,
    this.onChanged,
    this.onSubmitted,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
    this.focusNode,
    this.suffixIcon,
    this.prefixIcon,
    this.fillColor,
    this.readOnly = false,
  });

  @override
  State<ModernTextField> createState() => _ModernTextFieldState();
}

class _ModernTextFieldState extends State<ModernTextField>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late FocusNode _focusNode;

  bool _isFocused = false;
  bool _hasError = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_handleFocusChange);

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    _animationController.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    final hasFocus = _focusNode.hasFocus;
    setState(() {
      _isFocused = hasFocus;
    });

    if (hasFocus) {
      _animationController.forward();
    } else {
      if (widget.controller.text.isEmpty) {
        _animationController.reverse();
      }
    }
  }

  void _validateField() {
    if (widget.validator != null) {
      final error = widget.validator!(widget.controller.text);
      setState(() {
        _hasError = error != null;
        _errorText = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            boxShadow: [
              if (_isFocused)
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return TextFormField(
                controller: widget.controller,
                obscureText: widget.obscureText,
                keyboardType: widget.keyboardType,
                inputFormatters: widget.inputFormatters,
                maxLines: widget.maxLines,
                maxLength: widget.maxLength,
                enabled: widget.enabled,
                onTap: widget.onTap,
                onChanged: (value) {
                  _validateField();
                  widget.onChanged?.call(value);
                },
                onFieldSubmitted: widget.onSubmitted,
                textCapitalization: widget.textCapitalization,
                autofocus: widget.autofocus,
                focusNode: _focusNode,
                readOnly: widget.readOnly,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: theme.brightness == Brightness.dark
                          ? Colors.black
                          : Colors.black87,
                    ),
                decoration: InputDecoration(
                  labelText: widget.label,
                  hintText: widget.hintText,
                  floatingLabelBehavior: FloatingLabelBehavior.never,
                  prefixIcon: widget.icon != null
                      ? Icon(
                          widget.icon,
                          color: _isFocused
                              ? AppTheme.primaryColor
                              : AppTheme.grayColor,
                        )
                      : widget.prefixIcon,
                  suffixIcon: widget.suffixIcon,
                  filled: true,
                  fillColor: widget.fillColor ??
                      (_isFocused
                          ? AppTheme.primaryColor.withValues(alpha: 0.05)
                          : Colors.white),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    borderSide: BorderSide(
                      color: _hasError
                          ? AppTheme.errorColor
                          : AppTheme.lightGrayColor,
                      width: 1.5,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    borderSide: BorderSide(
                      color: _hasError
                          ? AppTheme.errorColor
                          : AppTheme.lightGrayColor,
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    borderSide: BorderSide(
                      color: _hasError
                          ? AppTheme.errorColor
                          : AppTheme.primaryColor,
                      width: 2.0,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    borderSide: const BorderSide(
                      color: AppTheme.errorColor,
                      width: 2.0,
                    ),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    borderSide: const BorderSide(
                      color: AppTheme.errorColor,
                      width: 2.0,
                    ),
                  ),
                  labelStyle: TextStyle(
                    color: _hasError
                        ? AppTheme.errorColor
                        : (_isFocused
                            ? AppTheme.primaryColor
                            : theme.brightness == Brightness.dark
                                ? Colors.grey[600]
                                : AppTheme.grayColor),
                    fontWeight: FontWeight.w500,
                  ),
                  hintStyle: TextStyle(
                    color: theme.brightness == Brightness.dark
                        ? Colors.grey[500]
                        : AppTheme.grayColor.withValues(alpha: 0.7),
                    fontWeight: FontWeight.normal,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceMd,
                    vertical: widget.maxLines > 1
                        ? AppTheme.spaceLg
                        : AppTheme.spaceMd,
                  ),
                  counterStyle: const TextStyle(
                    color: AppTheme.grayColor,
                    fontSize: 12,
                  ),
                ),
                onTapOutside: (event) {
                  FocusScope.of(context).unfocus();
                },
                validator: widget.validator,
              );
            },
          ),
        ),

        // Error text
        if (_hasError && _errorText != null) ...[
          const SizedBox(height: AppTheme.spaceXs),
          Padding(
            padding: const EdgeInsets.only(left: AppTheme.spaceSm),
            child: Text(
              _errorText!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.errorColor,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ],
    );
  }
}
