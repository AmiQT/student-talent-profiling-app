import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_auth_service.dart';
import '../../models/user_model.dart';
import '../../utils/error_handler.dart';
// Removed auth debug helper for production
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../student/student_dashboard.dart';
import '../lecturer/lecturer_dashboard.dart';

// import 'register_screen.dart';  // Registration removed
import 'comprehensive_profile_setup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Registration functionality removed

  void _onSignIn() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      // Debug authentication status before login
      debugPrint('🔐 Authentication attempt started');

      try {
        final authService =
            Provider.of<SupabaseAuthService>(context, listen: false);
        final email = _emailController.text.trim();
        final password = _passwordController.text.trim();

        debugPrint('🔐 Attempting login for email: $email');

        // Validate input
        if (email.isEmpty || password.isEmpty) {
          throw Exception('Please enter both email and password');
        }

        // Sign in with Supabase
        final user =
            await authService.signInWithEmailAndPassword(email, password);

        debugPrint('✅ Login successful for user: ${user.id}');

        if (!mounted) return;

        // Check if user has completed their profile
        final hasCompletedProfile =
            await authService.hasCompletedProfile(user.uid);

        if (!mounted) return;

        if (!hasCompletedProfile) {
          // Redirect to profile setup
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
                builder: (_) => const ComprehensiveProfileSetupScreen()),
            (route) => false,
          );
        } else {
          // Navigate to appropriate dashboard based on role
          _navigateToDashboard(user.role);
        }
      } on AuthException catch (e) {
        if (kDebugMode) debugPrint('Auth error during login: ${e.message}');
        if (mounted) {
          final userMessage = ErrorHandler.getUserFriendlyMessage(e);
          ErrorHandler.showErrorSnackBar(context, userMessage);
        }
      } catch (e) {
        if (kDebugMode) debugPrint('Login error: $e');
        if (mounted) {
          ErrorHandler.showErrorSnackBar(
              context, 'Login failed. Please try again.');
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _navigateToDashboard(UserRole role) {
    Widget dashboard;
    switch (role) {
      case UserRole.student:
        dashboard = const StudentDashboard();
        break;
      case UserRole.lecturer:
        dashboard = const LecturerDashboard();
        break;
      case UserRole.admin:
        // Admin uses same interface as students
        dashboard = const StudentDashboard();
        break;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => dashboard),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo and Title
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: theme.shadowColor.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Image.asset(
                          'assets/images/uthm.png',
                          height: 80,
                          width: 80,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Talent Hub',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Showcase your skills and connect with opportunities.\nSign in to get started.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Login Form
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: theme.shadowColor.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          CustomTextField(
                            controller: _emailController,
                            labelText: 'Email',
                            hintText: 'Enter your email address',
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                  .hasMatch(value)) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            controller: _passwordController,
                            labelText: 'Password',
                            hintText: 'Enter your password',
                            obscureText: _obscurePassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: theme.iconTheme.color,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your password';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          CustomButton(
                            text: _isLoading ? 'Signing In...' : 'Sign In',
                            onPressed: _isLoading ? null : _onSignIn,
                            isLoading: _isLoading,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Registration option removed - users must have existing accounts
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
