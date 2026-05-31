import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../config/supabase_config.dart';
import '../config/app_config.dart';

class SupabaseAuthService {
  static String get baseUrl =>
      AppConfig.backendUrl; // Dynamic URL from AppConfig

  UserModel? _currentUser;

  // Getters
  UserModel? get currentUser => _currentUser;
  User? get supabaseUser => SupabaseConfig.auth.currentUser;
  String? get currentUserId => supabaseUser?.id;

  // Get Supabase auth token for backend API calls
  Future<String?> getAuthToken() async {
    try {
      final session = SupabaseConfig.auth.currentSession;
      if (session?.accessToken != null) {
        return session!.accessToken;
      }
      return null;
    } catch (e) {
      debugPrint('SupabaseAuthService: Error getting auth token: $e');
      return null;
    }
  }

  // Initialize service and restore session
  Future<void> initialize() async {
    try {
      // Check if user is already signed in
      final session = SupabaseConfig.auth.currentSession;
      if (session != null) {
        // Only load profile if session is valid
        if (!session.isExpired) {
          await _loadUserProfile(session.user.id);
        } else {
          _currentUser = null;
        }
      }

      // Listen to auth state changes
      SupabaseConfig.auth.onAuthStateChange.listen((data) {
        final AuthChangeEvent event = data.event;
        final Session? session = data.session;

        switch (event) {
          case AuthChangeEvent.signedIn:
            if (session?.user != null) {
              _loadUserProfile(session!.user.id);
            }
            break;
          case AuthChangeEvent.signedOut:
            _currentUser = null;
            break;
          case AuthChangeEvent.tokenRefreshed:
            break;
          case AuthChangeEvent.initialSession:
            if (session?.user != null) {
              _loadUserProfile(session!.user.id);
            }
            break;
          default:
            break;
        }
      });
    } catch (e) {
      debugPrint('SupabaseAuthService: Error during initialization: $e');
    }
  }

  // Sign in with email and password
  Future<UserModel> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      // debugPrint(
      //     'SupabaseAuthService: Attempting to sign in with email: $email');

      // Test network connectivity first
      // debugPrint('SupabaseAuthService: Testing network connectivity...');
      try {
        await SupabaseConfig.client
            .from('profiles')
            .select('count')
            .limit(1)
            .timeout(const Duration(seconds: 5));
        // debugPrint('SupabaseAuthService: Network test successful');
      } catch (e) {
        debugPrint('SupabaseAuthService: Network test failed: $e');
        throw Exception(
            'Network connection failed. Please check your internet connection.');
      }

      final response = await SupabaseConfig.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        // debugPrint(
        //     'SupabaseAuthService: Sign in successful for user: ${response.user!.id}');

        // Load user profile from your backend or Supabase
        await _loadUserProfile(response.user!.id);

        if (_currentUser != null) {
          return _currentUser!;
        } else {
          // Create basic user model if profile doesn't exist
          _currentUser = UserModel(
            id: response.user!.id,
            uid: response.user!.id,
            email: response.user!.email ?? email,
            name: response.user!.userMetadata?['name'] ?? 'User',
            role: UserRole.student,
            createdAt: DateTime.now(),
            isActive: true,
            profileCompleted: false, // New users don't have completed profiles
          );

          // Ensure user exists in Supabase
          await _ensureUserInSupabase(
            response.user!.id,
            response.user!.email ?? email,
            response.user!.userMetadata?['name'] ?? 'User',
            UserRole.student,
          );
        }

        return _currentUser!;
      } else {
        throw Exception('Sign in failed: No user returned');
      }
    } catch (e) {
      debugPrint('SupabaseAuthService: Sign in error: $e');
      rethrow;
    }
  }

  // Register with email and password
  Future<UserModel> registerWithEmailAndPassword(
    String email,
    String password,
    String name,
    UserRole role, {
    String? studentId,
    String? department,
  }) async {
    try {
      // debugPrint('SupabaseAuthService: Attempting to register user: $email');

      final response = await SupabaseConfig.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'role': role.toString().split('.').last,
          'student_id': studentId,
          'department': department,
        },
      );

      if (response.user != null) {
        // debugPrint(
        //     'SupabaseAuthService: Registration successful for user: ${response.user!.id}');

        // Create user profile in your backend
        final userModel = UserModel(
          id: response.user!.id,
          uid: response.user!.id,
          email: email,
          name: name,
          role: role,
          studentId: studentId,
          department: department,
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
          isActive: true,
          profileCompleted:
              false, // Newly registered users don't have completed profiles
        );

        // Save to backend if needed
        await _createUserInBackend(userModel);

        // Also create user in Supabase
        await _ensureUserInSupabase(response.user!.id, email, name, role);

        _currentUser = userModel;
        return userModel;
      } else {
        throw Exception('Registration failed: No user returned');
      }
    } catch (e) {
      debugPrint('SupabaseAuthService: Registration error: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await SupabaseConfig.auth.signOut();
      _currentUser = null;
      // debugPrint('SupabaseAuthService: User signed out successfully');
    } catch (e) {
      debugPrint('SupabaseAuthService: Sign out error: $e');
      rethrow;
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await SupabaseConfig.auth.resetPasswordForEmail(email);
      // debugPrint('SupabaseAuthService: Password reset email sent to: $email');
    } catch (e) {
      debugPrint('SupabaseAuthService: Password reset error: $e');
      rethrow;
    }
  }

  // Update user profile
  Future<void> updateUserProfile(Map<String, dynamic> updates) async {
    try {
      await SupabaseConfig.auth.updateUser(
        UserAttributes(
          data: updates,
        ),
      );

      // Update profile completion status in Supabase if provided
      if (updates.containsKey('profileCompleted')) {
        final userId = currentUserId;
        if (userId != null) {
          try {
            // Skip users table update to avoid RLS policy infinite recursion
            // Only update profiles table
            await SupabaseConfig.client.from('profiles').upsert({
              'user_id': userId,
              'is_profile_complete': updates['profileCompleted'],
              'updated_at': DateTime.now().toIso8601String(),
            });
            // debugPrint(
            //     'SupabaseAuthService: Profile completion status updated in profiles table');
          } catch (e) {
            debugPrint('SupabaseAuthService: Supabase update failed: $e');
          }
        }
      }

      // Reload user profile
      if (currentUserId != null) {
        await _loadUserProfile(currentUserId!);
      }

      // debugPrint('SupabaseAuthService: User profile updated successfully');
    } catch (e) {
      debugPrint('SupabaseAuthService: Profile update error: $e');
      rethrow;
    }
  }

  // Load user profile from backend or Supabase
  Future<void> _loadUserProfile(String userId) async {
    try {
      // Option 1: Try to load from profiles table first (this is the main source)
      final userData = await getUserById(userId);
      if (userData != null) {
        _currentUser = userData;
        return;
      }

      // Option 2: Fallback to Supabase user metadata if no profile found
      final supabaseUser = SupabaseConfig.auth.currentUser;
      if (supabaseUser != null) {
        _currentUser = UserModel(
          id: supabaseUser.id,
          uid: supabaseUser.id,
          email: supabaseUser.email ?? '',
          name: supabaseUser.userMetadata?['name'] ?? 'User',
          role: _parseUserRole(supabaseUser.userMetadata?['role']),
          studentId: supabaseUser.userMetadata?['student_id'],
          department: supabaseUser.userMetadata?['department'],
          createdAt: DateTime.parse(supabaseUser.createdAt.toString()),
          lastLoginAt: DateTime.now(),
          isActive: true,
          profileCompleted: false, // No profile means not completed
        );
      }
    } catch (e) {
      debugPrint('SupabaseAuthService: Error loading user profile: $e');
    }
  }

  // Create user in your backend
  Future<void> _createUserInBackend(UserModel user) async {
    try {
      final token = await getAuthToken();
      if (token == null) return;

      // Create user in your backend database
      await SupabaseConfig.client.functions.invoke(
        'create-user',
        body: user.toJson(),
        headers: {'Authorization': 'Bearer $token'},
      );

      // debugPrint('SupabaseAuthService: User created in backend successfully');
    } catch (e) {
      debugPrint('SupabaseAuthService: Error creating user in backend: $e');
    }
  }

  // Create user in Supabase if they don't exist
  Future<void> _ensureUserInSupabase(
      String userId, String email, String name, UserRole role) async {
    try {
      // Skip users table operations to avoid RLS policy infinite recursion
      // User data will be managed through Supabase auth metadata and profiles table
      // debugPrint(
      //     'SupabaseAuthService: Skipping users table operations to avoid RLS policy issues');
      // debugPrint(
      //     'SupabaseAuthService: User authentication handled by Supabase auth: $userId');
    } catch (e) {
      debugPrint('SupabaseAuthService: Error in _ensureUserInSupabase: $e');
    }
  }

  // Validate SMAP credentials (keep your existing logic)
  Future<bool> validateSMAPCredentials(
      String studentId, String password) async {
    try {
      // debugPrint(
      //     'SupabaseAuthService: Validating SMAP credentials for: $studentId');

      // Your existing SMAP validation logic
      if (!_isValidStudentIdFormat(studentId)) {
        return false;
      }

      if (password.isEmpty || password.length < 6) {
        return false;
      }

      return _validateStudentIdPattern(studentId);
    } catch (e) {
      debugPrint('SupabaseAuthService: SMAP validation error: $e');
      return false;
    }
  }

  // Helper methods (keep your existing logic)
  bool _isValidStudentIdFormat(String studentId) {
    final regex = RegExp(r'^[A-Z]{2}\d{7}$');
    return regex.hasMatch(studentId.toUpperCase());
  }

  bool _validateStudentIdPattern(String studentId) {
    final validFacultyCodes = ['CI', 'EE', 'ME', 'CE', 'BA', 'ED', 'SC', 'AR'];
    final facultyCode = studentId.substring(0, 2).toUpperCase();
    return validFacultyCodes.contains(facultyCode);
  }

  UserRole _parseUserRole(String? roleString) {
    switch (roleString?.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'lecturer':
      case 'teacher':
      case 'staff':
        return UserRole.lecturer;
      case 'student':
      default:
        return UserRole.student;
    }
  }

  // Check if user has completed profile
  Future<bool> hasCompletedProfile(String userId) async {
    try {
      // debugPrint(
      //     'SupabaseAuthService: Checking profile completion for userId: $userId');

      // If userId is empty, return false
      if (userId.isEmpty) {
        // debugPrint(
        //     'SupabaseAuthService: Empty userId provided, returning false');
        return false;
      }

      // Check if current user has a completed profile
      if (_currentUser != null && _currentUser!.uid == userId) {
        // debugPrint(
        //     'SupabaseAuthService: Using cached user profile completion: ${_currentUser!.profileCompleted}');
        return _currentUser!.profileCompleted;
      }

      // If _currentUser is null or doesn't match, load user profile first
      if (_currentUser == null || _currentUser!.uid != userId) {
        // debugPrint(
        //     'SupabaseAuthService: Loading user profile for userId: $userId');
        await _loadUserProfile(userId);

        // Check again after loading
        if (_currentUser != null && _currentUser!.uid == userId) {
          // debugPrint(
          //     'SupabaseAuthService: Using loaded user profile completion: ${_currentUser!.profileCompleted}');
          return _currentUser!.profileCompleted;
        }
      }

      // Check current auth user
      // final currentAuthUser = SupabaseConfig.auth.currentUser;
      // debugPrint(
      //     'SupabaseAuthService: Current auth user: ${currentAuthUser?.id}');
      // debugPrint(
      //     'SupabaseAuthService: Auth user matches userId: ${currentAuthUser?.id == userId}');

      // Try to get profile from Supabase profiles table
      try {
        // debugPrint('SupabaseAuthService: Checking profiles table...');
        final response = await SupabaseConfig.client
            .from('profiles')
            .select('is_profile_complete')
            .eq('user_id', userId)
            .single();

        // debugPrint('SupabaseAuthService: Profiles table response: $response');
        if (response['is_profile_complete'] != null) {
          final result = response['is_profile_complete'] as bool;
          // debugPrint(
          //     'SupabaseAuthService: Profile completion from profiles table: $result');
          return result;
        }
      } catch (e) {
        debugPrint('SupabaseAuthService: No profile found in Supabase: $e');
      }

      // Try to get user from Supabase users table
      try {
        // debugPrint('SupabaseAuthService: Checking users table...');
        final response = await SupabaseConfig.client
            .from('users')
            .select('profile_completed')
            .eq('id', userId)
            .single();

        // debugPrint('SupabaseAuthService: Users table response: $response');
        if (response['profile_completed'] != null) {
          final result = response['profile_completed'] as bool;
          // debugPrint(
          //     'SupabaseAuthService: Profile completion from users table: $result');
          return result;
        }
      } catch (e) {
        debugPrint('SupabaseAuthService: No user found in Supabase: $e');
      }

      // If we can't get user data, assume profile is complete for existing auth users
      // debugPrint(
      //     'SupabaseAuthService: No profile data found, assuming complete for auth user');
      return true;
    } catch (e) {
      debugPrint('SupabaseAuthService: Error checking profile completion: $e');
      return false;
    }
  }

  // Get all users (admin function)
  Future<List<UserModel>> getAllUsers() async {
    try {
      // Get all users from profiles table (has public access policy)
      final response = await SupabaseConfig.client.from('profiles').select('*');

      final users = response.map<UserModel>((profileData) {
        // Convert profile data to UserModel format
        return UserModel(
          id: profileData['user_id'] ?? '',
          uid: profileData['user_id'] ?? '',
          email: profileData['email'] ?? '',
          name: profileData['full_name'] ?? '',
          role: _getRoleFromProfile(profileData),
          studentId: profileData['academic_info']?['studentId'],
          department: profileData['academic_info']?['department'] ??
              profileData['academic_info']?['faculty'],
          createdAt: profileData['created_at'] != null
              ? DateTime.parse(profileData['created_at'])
              : DateTime.now(),
          lastLoginAt: null,
          isActive: true,
          profileCompleted: profileData['is_profile_complete'] ?? false,
        );
      }).toList();

      return users;
    } catch (e) {
      debugPrint('SupabaseAuthService: Error getting all users: $e');
      return [];
    }
  }

  // Get all users with full profile data for search (optimized)
  Future<List<Map<String, dynamic>>> getAllUsersWithProfiles() async {
    try {
      // Get all users from profiles table (has public access policy)
      final response = await SupabaseConfig.client.from('profiles').select('*');

      return response;
    } catch (e) {
      debugPrint(
          'SupabaseAuthService: Error getting all users with profiles: $e');
      return [];
    }
  }

  // Helper method to determine role from profile data
  UserRole _getRoleFromProfile(Map<String, dynamic> profileData) {
    final academicInfo = profileData['academic_info'];
    if (academicInfo != null) {
      if (academicInfo['studentId'] != null) {
        return UserRole.student;
      } else if (academicInfo['position'] != null) {
        return UserRole.lecturer;
      }
    }
    // Default to student if can't determine
    return UserRole.student;
  }

  // Get user by ID
  Future<UserModel?> getUserById(String userId) async {
    try {
      // First, try to get role from users table (most reliable)
      UserRole userRole = UserRole.student;
      try {
        final userResponse = await SupabaseConfig.client
            .from('users')
            .select('role, email, name')
            .eq('id', userId)
            .maybeSingle();

        if (userResponse != null && userResponse['role'] != null) {
          userRole = _parseUserRole(userResponse['role']);
          // debugPrint(
          //     'SupabaseAuthService: Got role from users table: ${userResponse['role']} -> $userRole');
        }
      } catch (e) {
        // debugPrint(
        //     'SupabaseAuthService: Could not get role from users table: $e');
      }

      // Try to get user from profiles table - get the latest profile if multiple exist
      final response = await SupabaseConfig.client
          .from('profiles')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      // Convert profile data to UserModel - use role from users table
      final user = UserModel(
        id: response['user_id'] ?? userId,
        uid: response['user_id'] ?? userId,
        email: response['email'] ?? '',
        name: response['full_name'] ?? '',
        role:
            userRole, // Use role from users table instead of _getRoleFromProfile
        studentId: response['academic_info']?['studentId'],
        department: response['academic_info']?['department'] ??
            response['academic_info']?['faculty'],
        createdAt: response['created_at'] != null
            ? DateTime.parse(response['created_at'])
            : DateTime.now(),
        lastLoginAt: null,
        isActive: true,
        profileCompleted: response['is_profile_complete'] ?? false,
      );

      return user;
    } catch (e) {
      debugPrint('SupabaseAuthService: Error getting user by ID: $e');
      return null;
    }
  }

  // Get user data (alias for getUserById for compatibility)
  Future<UserModel?> getUserData(String uid) async {
    return await getUserById(uid);
  }

  // Check if user should stay logged in
  bool get shouldStayLoggedIn {
    final session = SupabaseConfig.auth.currentSession;
    if (session == null) return false;

    // Check if session is expired
    if (session.isExpired) return false;

    // Check if we have user data
    if (_currentUser == null) return false;

    return true;
  }

  // Get current session info for debugging
  Map<String, dynamic> get sessionInfo {
    final session = SupabaseConfig.auth.currentSession;
    if (session == null) {
      return {'status': 'no_session'};
    }

    return {
      'status': 'active',
      'user_id': session.user.id,
      'expires_at': session.expiresAt?.toString(),
      'is_expired': session.isExpired,
      'has_user_data': _currentUser != null,
      'current_user_id': _currentUser?.id,
    };
  }
}
