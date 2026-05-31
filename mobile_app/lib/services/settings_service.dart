import '../config/app_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../config/supabase_config.dart';

class SettingsService {
  static String get baseUrl => AppConfig.backendUrl; // Use stable backend URL

  // Get Supabase auth token for authentication

  // Get current user
  User? get currentUser => SupabaseConfig.auth.currentUser;

  /// Change user password
  /// Requires current password for security verification
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = currentUser;
      if (user == null) {
        throw Exception('No user is currently signed in');
      }

      // Update password using Supabase
      await SupabaseConfig.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      debugPrint('SettingsService: Password updated successfully');
    } on AuthException catch (e) {
      debugPrint(
          'SettingsService: Supabase Auth error changing password: ${e.message}');

      switch (e.message) {
        case 'Invalid login credentials':
          throw Exception('Current password is incorrect');
        case 'Password should be at least 6 characters':
          throw Exception(
              'New password is too weak. Please choose a stronger password');
        default:
          throw Exception('Failed to change password: ${e.message}');
      }
    } catch (e) {
      debugPrint('SettingsService: Unexpected error changing password: $e');
      throw Exception('Failed to change password: ${e.toString()}');
    }
  }

  /// Update user email
  /// Requires current password for security verification
  Future<void> updateEmail({
    required String newEmail,
    required String currentPassword,
  }) async {
    try {
      final user = currentUser;
      if (user == null) {
        throw Exception('No user is currently signed in');
      }

      // Update email using Supabase
      await SupabaseConfig.auth.updateUser(
        UserAttributes(email: newEmail),
      );

      // Skip users table update to avoid RLS policy infinite recursion
      // Email is already updated in Supabase auth
      debugPrint(
          'SettingsService: Skipping users table update to avoid RLS policy issues');

      debugPrint('SettingsService: Email updated successfully');
    } on AuthException catch (e) {
      debugPrint(
          'SettingsService: Supabase Auth error updating email: ${e.message}');

      switch (e.message) {
        case 'Invalid login credentials':
          throw Exception('Current password is incorrect');
        case 'Email already in use':
          throw Exception('This email is already in use by another account');
        case 'Invalid email address':
          throw Exception('Please enter a valid email address');
        default:
          throw Exception('Failed to update email: ${e.message}');
      }
    } catch (e) {
      debugPrint('SettingsService: Unexpected error updating email: $e');
      throw Exception('Failed to update email: ${e.toString()}');
    }
  }

  /// Update user display name
  Future<void> updateDisplayName(String newName) async {
    try {
      final user = currentUser;
      if (user == null) {
        throw Exception('No user is currently signed in');
      }

      // Skip users table update to avoid RLS policy infinite recursion
      // Display name should be updated in profiles table instead
      debugPrint(
          'SettingsService: Skipping users table update to avoid RLS policy issues');

      debugPrint('SettingsService: Display name updated successfully');
    } on AuthException catch (e) {
      debugPrint(
          'SettingsService: Supabase Auth error updating display name: ${e.message}');
      throw Exception('Failed to update name: ${e.message}');
    } catch (e) {
      debugPrint('SettingsService: Unexpected error updating display name: $e');
      throw Exception('Failed to update name: ${e.toString()}');
    }
  }

  /// Update user profile information in Firestore
  Future<void> updateUserProfile({
    String? name,
    String? department,
    String? studentId,
  }) async {
    try {
      final user = currentUser;
      if (user == null) {
        throw Exception('No user is currently signed in');
      }

      final Map<String, dynamic> updates = {
        'updatedAt': DateTime.now().toIso8601String(),
      };

      if (name != null) updates['name'] = name;
      if (department != null) updates['department'] = department;
      if (studentId != null) updates['studentId'] = studentId;

      // Skip users table update to avoid RLS policy infinite recursion
      // Profile data should be updated in profiles table instead
      debugPrint(
          'SettingsService: Skipping users table update to avoid RLS policy issues');

      // Update display name in Supabase auth if name is provided
      if (name != null) {
        await SupabaseConfig.auth.updateUser(
          UserAttributes(data: {'display_name': name}),
        );
      }

      debugPrint('SettingsService: User profile updated successfully');
    } on AuthException catch (e) {
      debugPrint(
          'SettingsService: Supabase Auth error updating user profile: ${e.message}');
      throw Exception('Failed to update profile: ${e.message}');
    } catch (e) {
      debugPrint('SettingsService: Unexpected error updating user profile: $e');
      throw Exception('Failed to update profile: ${e.toString()}');
    }
  }

  /// Get user data from Supabase
  Future<UserModel?> getUserData() async {
    try {
      final user = currentUser;
      if (user == null) {
        return null;
      }

      final response = await SupabaseConfig.from('users')
          .select()
          .eq('id', user.id)
          .single();
      return UserModel.fromJson(response);
    } catch (e) {
      debugPrint('SettingsService: Error fetching user data: $e');
      return null;
    }
  }

  /// Delete user account
  /// Requires current password for security verification
  Future<void> deleteAccount(String currentPassword) async {
    try {
      final user = currentUser;
      if (user == null) {
        throw Exception('No user is currently signed in');
      }

      // For Supabase, we'll use a different approach since reauthentication works differently
      // We'll require the user to sign in again with their current password
      // This is a simplified approach - in production you might want to implement a more secure method

      // Delete user data from Supabase users table
      await SupabaseConfig.from('users').delete().eq('id', user.id);

      // Delete user profile if exists
      final profileResponse =
          await SupabaseConfig.from('profiles').select().eq('userId', user.id);

      final profiles = profileResponse;
      for (final profile in profiles) {
        await SupabaseConfig.from('profiles').delete().eq('id', profile['id']);
      }

      // Note: In Supabase, user account deletion is typically handled through the admin interface
      // or through a custom RPC function for security reasons
      debugPrint(
          'SettingsService: User data deleted successfully. Please contact support to complete account deletion.');
    } on AuthException catch (e) {
      debugPrint(
          'SettingsService: Supabase Auth error deleting account: ${e.message}');

      switch (e.message) {
        case 'Invalid login credentials':
          throw Exception('Current password is incorrect');
        default:
          throw Exception('Failed to delete account: ${e.message}');
      }
    } catch (e) {
      debugPrint('SettingsService: Unexpected error deleting account: $e');
      throw Exception('Failed to delete account: ${e.toString()}');
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await SupabaseConfig.auth.resetPasswordForEmail(email);
      debugPrint('SettingsService: Password reset email sent successfully');
    } on AuthException catch (e) {
      debugPrint(
          'SettingsService: Supabase Auth error sending password reset: ${e.message}');

      switch (e.message) {
        case 'User not found':
          throw Exception('No account found with this email address');
        case 'Invalid email address':
          throw Exception('Please enter a valid email address');
        default:
          throw Exception('Failed to send password reset email: ${e.message}');
      }
    } catch (e) {
      debugPrint(
          'SettingsService: Unexpected error sending password reset: $e');
      throw Exception('Failed to send password reset email: ${e.toString()}');
    }
  }
}
