import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/supabase_auth_service.dart';
import '../../services/settings_service.dart';
import '../../widgets/settings_widgets.dart';
import '../../widgets/custom_text_field.dart';
import '../../utils/app_theme.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  final _passwordFormKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _resetEmailController = TextEditingController();

  final SettingsService _settingsService = SettingsService();

  bool _isChangingPassword = false;
  bool _isSendingReset = false;
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _resetEmailController.dispose();
    super.dispose();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  String? _validateNewPassword(String? value) {
    final baseValidation = _validatePassword(value);
    if (baseValidation != null) return baseValidation;

    if (value == _currentPasswordController.text) {
      return 'New password must be different from current password';
    }

    // Check for password strength
    if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(value!)) {
      return 'Password should contain uppercase, lowercase, and numbers';
    }

    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _newPasswordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isChangingPassword = true;
    });

    try {
      await _settingsService.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      _showSuccessSnackBar('Password changed successfully');

      // Clear form
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    } catch (e) {
      _showErrorSnackBar(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isChangingPassword = false;
        });
      }
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _resetEmailController.text.trim();
    if (email.isEmpty) {
      _showErrorSnackBar('Please enter your email address');
      return;
    }

    setState(() {
      _isSendingReset = true;
    });

    try {
      await _settingsService.sendPasswordResetEmail(email);
      if (mounted) {
        _showSuccessSnackBar('Password reset email sent to $email');
        _resetEmailController.clear();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSendingReset = false;
        });
      }
    }
  }

  void _showPasswordResetDialog() {
    final authService =
        Provider.of<SupabaseAuthService>(context, listen: false);
    _resetEmailController.text = authService.supabaseUser?.email ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your email address to receive a password reset link.',
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _resetEmailController,
              labelText: 'Email Address',
              hintText: 'Enter your email',
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isSendingReset ? null : _sendPasswordReset,
            child: _isSendingReset
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Security Settings'),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.textPrimaryColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 16),

            // Security Info Banner
            const SettingsInfoBanner(
              message:
                  'Keep your account secure by using a strong password and updating it regularly.',
              icon: Icons.security,
              backgroundColor: Colors.orange,
              textColor: Colors.white,
              iconColor: Colors.white,
            ),

            // Change Password Section
            const SettingsSectionHeader(
              title: 'Change Password',
              subtitle: 'Update your account password',
            ),
            SettingsCard(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _passwordFormKey,
                child: Column(
                  children: [
                    CustomTextField(
                      controller: _currentPasswordController,
                      labelText: 'Current Password',
                      hintText: 'Enter your current password',
                      obscureText: !_showCurrentPassword,
                      validator: _validatePassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showCurrentPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _showCurrentPassword = !_showCurrentPassword;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    CustomTextField(
                      controller: _newPasswordController,
                      labelText: 'New Password',
                      hintText: 'Enter your new password',
                      obscureText: !_showNewPassword,
                      validator: _validateNewPassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showNewPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _showNewPassword = !_showNewPassword;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    CustomTextField(
                      controller: _confirmPasswordController,
                      labelText: 'Confirm New Password',
                      hintText: 'Confirm your new password',
                      obscureText: !_showConfirmPassword,
                      validator: _validateConfirmPassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showConfirmPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _showConfirmPassword = !_showConfirmPassword;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Password requirements
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Password Requirements:',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '• At least 6 characters\n• Contains uppercase and lowercase letters\n• Contains at least one number',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Change Password Button
            SettingsActionButton(
              text: 'Change Password',
              icon: Icons.lock_reset,
              onPressed: _changePassword,
              isLoading: _isChangingPassword,
            ),

            // Password Reset Section
            const SettingsSectionHeader(
              title: 'Password Reset',
              subtitle: 'Alternative password recovery options',
            ),
            SettingsCard(
              child: SettingsItem(
                icon: Icons.email_outlined,
                title: 'Send Password Reset Email',
                subtitle: 'Receive a password reset link via email',
                onTap: _showPasswordResetDialog,
                showDivider: false,
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
