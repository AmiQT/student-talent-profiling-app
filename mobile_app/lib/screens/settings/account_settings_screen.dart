import 'package:flutter/material.dart';
import '../../services/settings_service.dart';
import '../../models/user_model.dart';
import '../../widgets/settings_widgets.dart';
import '../../widgets/custom_text_field.dart';
import '../../utils/app_theme.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _departmentController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _passwordController = TextEditingController();

  final SettingsService _settingsService = SettingsService();

  UserModel? _currentUser;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditingEmail = false;
  bool _showPasswordField = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _departmentController.dispose();
    _studentIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await _settingsService.getUserData();

      if (userData != null && mounted) {
        setState(() {
          _currentUser = userData;
          _nameController.text = userData.name;
          _emailController.text = userData.email;
          _departmentController.text = userData.department ?? '';
          _studentIdController.text = userData.studentId ?? '';
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar(
            'No user data found. Please try logging out and back in.');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('Error loading user data: ${e.toString()}');
      }
    }
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

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Update name if changed
      if (_nameController.text.trim() != _currentUser!.name) {
        await _settingsService.updateDisplayName(_nameController.text.trim());
      }

      // Update email if changed and password provided
      if (_isEditingEmail &&
          _emailController.text.trim() != _currentUser!.email &&
          _passwordController.text.isNotEmpty) {
        await _settingsService.updateEmail(
          newEmail: _emailController.text.trim(),
          currentPassword: _passwordController.text,
        );
      }

      // Update other profile information
      await _settingsService.updateUserProfile(
        name: _nameController.text.trim(),
        department: _departmentController.text.trim().isEmpty
            ? null
            : _departmentController.text.trim(),
        studentId: _studentIdController.text.trim().isEmpty
            ? null
            : _studentIdController.text.trim(),
      );

      // Reload user data
      await _loadUserData();

      _showSuccessSnackBar('Account information updated successfully');

      // Reset email editing state
      setState(() {
        _isEditingEmail = false;
        _showPasswordField = false;
        _passwordController.clear();
      });
    } catch (e) {
      _showErrorSnackBar(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _toggleEmailEditing() {
    setState(() {
      _isEditingEmail = !_isEditingEmail;
      _showPasswordField = _isEditingEmail;
      if (!_isEditingEmail) {
        _emailController.text = _currentUser!.email;
        _passwordController.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Account Settings'),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.textPrimaryColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 16),

                    // Info Banner
                    const SettingsInfoBanner(
                      message:
                          'Update your account information. Email changes require password verification.',
                      icon: Icons.info_outline,
                    ),

                    // Personal Information Section
                    const SettingsSectionHeader(
                      title: 'Personal Information',
                      subtitle: 'Your basic account details',
                    ),
                    SettingsCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          CustomTextField(
                            controller: _nameController,
                            labelText: 'Full Name',
                            hintText: 'Enter your full name',
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your full name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: CustomTextField(
                                  controller: _emailController,
                                  labelText: 'Email Address',
                                  hintText: 'Enter your email',
                                  enabled: _isEditingEmail,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter your email';
                                    }
                                    if (!RegExp(
                                            r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                        .hasMatch(value)) {
                                      return 'Please enter a valid email';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: _toggleEmailEditing,
                                icon: Icon(
                                  _isEditingEmail ? Icons.cancel : Icons.edit,
                                  color: _isEditingEmail
                                      ? Colors.red
                                      : Theme.of(context).primaryColor,
                                ),
                                tooltip:
                                    _isEditingEmail ? 'Cancel' : 'Edit Email',
                              ),
                            ],
                          ),
                          if (_showPasswordField) ...[
                            const SizedBox(height: 16),
                            CustomTextField(
                              controller: _passwordController,
                              labelText: 'Current Password',
                              hintText: 'Enter your current password',
                              obscureText: true,
                              validator: (value) {
                                if (_isEditingEmail &&
                                    (value == null || value.isEmpty)) {
                                  return 'Password required to change email';
                                }
                                return null;
                              },
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Role-specific Information
                    if (_currentUser?.role == UserRole.student) ...[
                      const SettingsSectionHeader(
                        title: 'Student Information',
                        subtitle: 'Academic details',
                      ),
                      SettingsCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            CustomTextField(
                              controller: _studentIdController,
                              labelText: 'Student ID',
                              hintText: 'Enter your student ID',
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              controller: _departmentController,
                              labelText: 'Department',
                              hintText: 'Enter your department',
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      const SettingsSectionHeader(
                        title: 'Professional Information',
                        subtitle: 'Work-related details',
                      ),
                      SettingsCard(
                        padding: const EdgeInsets.all(16),
                        child: CustomTextField(
                          controller: _departmentController,
                          labelText: 'Department',
                          hintText: 'Enter your department',
                        ),
                      ),
                    ],

                    // Save Button
                    const SizedBox(height: 24),
                    SettingsActionButton(
                      text: 'Save Changes',
                      icon: Icons.save,
                      onPressed: _saveChanges,
                      isLoading: _isSaving,
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }
}
