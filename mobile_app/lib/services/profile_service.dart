import '../config/app_config.dart';
// Removed unused imports: dart:convert, http (using Supabase directly)
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/profile_model.dart';
import '../models/academic_info_model.dart';
import '../models/experience_model.dart';
import '../models/project_model.dart';
import '../models/talent_model.dart';
import '../config/supabase_config.dart';
import '../utils/profile_image_cleanup.dart';
import '../config/cloudinary_config.dart';

class ProfileService {
  static const String baseUrl =
      AppConfig.backendUrl; // Use stable cloud backend

  // Get Supabase auth token for authentication
  static Future<String?> _getAuthToken() async {
    try {
      final session = SupabaseConfig.auth.currentSession;
      if (session?.accessToken != null) {
        return session!.accessToken;
      }
      return null;
    } catch (e) {
      debugPrint('ProfileService: Error getting auth token: $e');
      return null;
    }
  }

  Future<void> saveProfile(ProfileModel profile) async {
    try {
      // debugPrint(
      //     'ProfileService: Saving profile for userId: ${profile.userId}');

      // Clean up placeholder URLs before saving
      if (ProfileImageCleanup.isPlaceholderUrl(profile.profileImageUrl)) {
        // debugPrint(
        //     'ProfileService: Detected placeholder URL, setting to null for fallback');
        profile = profile.copyWith(profileImageUrl: null);
      }

      // Validate profile data before saving
      if (profile.userId.isEmpty || profile.fullName.isEmpty) {
        throw Exception(
            'Profile data is incomplete. User ID and full name are required.');
      }

      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('User not authenticated');
      }

      // MOBILE APP OPTIMIZATION: Skip custom backend, use Supabase directly
      // debugPrint(
      //     'ProfileService: Using Supabase directly for mobile app (no custom backend delays)');

      /* REMOVED FOR MOBILE: Custom backend calls (causes 30s delays)
      // Try to save to backend first
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/api/profiles'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(profile.toJson()),
        );

        if (response.statusCode == 201 || response.statusCode == 200) {
          debugPrint('ProfileService: Profile saved successfully to backend');
        } else {
          debugPrint(
              'ProfileService: Failed to save profile to backend: ${response.body}');
          throw Exception('Backend offline, trying Supabase fallback');
        }
      } catch (e) {
        debugPrint(
            'ProfileService: Backend save failed, using Supabase fallback: $e');
      */

      // Save to Supabase directly (no backend delays)
      await _saveProfileToSupabase(profile);
    } catch (e) {
      debugPrint('ProfileService: Error saving profile: $e');
      rethrow;
    }
  }

  // Save profile to Supabase as fallback
  Future<void> _saveProfileToSupabase(ProfileModel profile) async {
    try {
      // debugPrint(
      //     'ProfileService: Saving profile to Supabase for userId: ${profile.userId}');

      // Get authenticated client with user context
      final client = SupabaseConfig.client;
      final user = SupabaseConfig.auth.currentUser;

      if (user == null) {
        throw Exception('User not authenticated in Supabase');
      }

      // debugPrint('ProfileService: Using authenticated user: ${user.id}');
      // debugPrint(
      //     'ProfileService: Client auth state: ${client.auth.currentSession != null ? 'authenticated' : 'not authenticated'}');
      // debugPrint(
      //     'ProfileService: Current session user: ${client.auth.currentSession?.user.id}');

      // Prepare profile data
      final profileData = {
        'user_id': profile.userId,
        'full_name': profile.fullName,
        'headline': profile.headline ?? '',
        'bio': profile.bio ?? '',
        'profile_image_url': profile.profileImageUrl ?? '',
        'academic_info': profile.academicInfo?.toJson(),
        'skills': profile.skills,
        'interests': profile.interests,
        'is_profile_complete': profile.isProfileComplete,
        'created_at': profile.createdAt.toIso8601String(),
        'updated_at': profile.updatedAt.toIso8601String(),
      };

      // debugPrint(
      //     'ProfileService: Attempting to upsert profile data: ${profileData.keys}');

      // Save to profiles table using authenticated context
      await client.from('profiles').upsert(profileData);
      // debugPrint('ProfileService: Profile upsert successful');

      // Skip users table update to avoid RLS policy infinite recursion
      // Profile completion status is already stored in profiles table
      // debugPrint(
      //     'ProfileService: Skipping users table update to avoid RLS policy issues');

      // debugPrint('ProfileService: Profile saved to Supabase successfully');
    } catch (e) {
      debugPrint('ProfileService: Error saving profile to Supabase: $e');
      debugPrint('ProfileService: Error type: ${e.runtimeType}');
      if (e.toString().contains('permission denied')) {
        debugPrint('ProfileService: Permission denied error detected');
        debugPrint(
            'ProfileService: Current auth context: ${SupabaseConfig.auth.currentUser?.id ?? 'null'}');
      }
      rethrow;
    }
  }

  /// Clean up placeholder URLs in all profiles
  static Future<void> cleanupPlaceholderUrls() async {
    await ProfileImageCleanup.cleanupPlaceholderUrls();
  }

  Future<ProfileModel?> getProfileByUserId(String userId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('User not authenticated');
      }

      // MOBILE APP OPTIMIZATION: Skip custom backend, use Supabase directly
      // debugPrint(
      //     'ProfileService: Getting profile from Supabase directly for mobile app');
      return await _getProfileFromSupabase(userId);

      /* REMOVED FOR MOBILE: Custom backend calls (causes 30s delays)
      // Try to get from backend first
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/api/profiles/$userId'),
          headers: {
            'Authorization': 'Bearer $token',
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return ProfileModel.fromJson(data);
        } else if (response.statusCode == 404) {
          // Fallback to Supabase
          return await _getProfileFromSupabase(userId);
        } else {
          // Fallback to Supabase
          return await _getProfileFromSupabase(userId);
        }
      } catch (e) {
        // Fallback: Get from Supabase
        return await _getProfileFromSupabase(userId);
      }
      */
    } catch (e) {
      debugPrint('ProfileService: Error getting profile: $e');
      return null;
    }
  }

  // Get profile from Supabase as fallback
  Future<ProfileModel?> _getProfileFromSupabase(String userId) async {
    try {
      // Get authenticated client with user context
      final client = SupabaseConfig.client;
      final user = SupabaseConfig.auth.currentUser;

      if (user == null) {
        throw Exception('User not authenticated in Supabase');
      }

      final response = await client
          .from('profiles')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1)
          .single();

      // Convert Supabase response to ProfileModel
      debugPrint(
          'ProfileService: talent_quiz_results from DB = ${response['talent_quiz_results']}');
      return ProfileModel(
        id: response['id'] ?? '',
        userId: response['user_id'] ?? userId,
        fullName: response['full_name'] ?? '',
        headline: response['headline'],
        bio: response['bio'],
        profileImageUrl: response['profile_image_url'],
        backgroundImageUrl: response['background_image_url'],
        academicInfo: response['academic_info'] != null
            ? AcademicInfoModel.fromJson(response['academic_info'])
            : null,
        skills: List<String>.from(response['skills'] ?? []),
        interests: List<String>.from(response['interests'] ?? []),
        experiences: (response['experiences'] as List<dynamic>?)
                ?.map((e) => ExperienceModel.fromJson(e))
                .toList() ??
            [],
        projects: (response['projects'] as List<dynamic>?)
                ?.map((p) => ProjectModel.fromJson(p))
                .toList() ??
            [],
        isProfileComplete: response['is_profile_complete'] ?? false,
        completedSections: ['basic'], // Default sections
        createdAt: response['created_at'] != null
            ? DateTime.parse(response['created_at'])
            : DateTime.now(),
        updatedAt: response['updated_at'] != null
            ? DateTime.parse(response['updated_at'])
            : DateTime.now(),
        talentProfile: TalentProfileModel(
          userId: response['user_id'] ?? userId,
          softSkills: (response['soft_skills'] as List<dynamic>?)
                  ?.map((s) => SoftSkillModel.fromJson(s))
                  .toList() ??
              [],
          hobbies: (response['hobbies'] as List<dynamic>?)
                  ?.map((h) => HobbyModel.fromJson(h))
                  .toList() ??
              [],
          quizResults: (response['talent_quiz_results'] != null &&
                  response['talent_quiz_results'] is Map &&
                  (response['talent_quiz_results'] as Map).isNotEmpty)
              ? TalentQuizResultModel.fromJson(response['talent_quiz_results'])
              : null,
          updatedAt: response['updated_at'] != null
              ? DateTime.parse(response['updated_at'])
              : DateTime.now(),
        ),
      );
    } catch (e) {
      debugPrint('ProfileService: Error getting profile from Supabase: $e');
      return null;
    }
  }

  /// Get all profiles
  Future<List<ProfileModel>> getAllProfiles() async {
    try {
      final response = await SupabaseConfig.client
          .from('profiles')
          .select('*')
          .order('created_at', ascending: false);

      return response
          .map((data) => ProfileModel(
                id: data['id'] ?? '',
                userId: data['user_id'] ?? '',
                fullName: data['full_name'] ?? '',
                headline: data['headline'],
                bio: data['bio'],
                profileImageUrl:
                    _getSafeProfileImageUrl(data['profile_image_url']),
                backgroundImageUrl: data['background_image_url'],
                academicInfo: data['academic_info'] != null
                    ? AcademicInfoModel.fromJson(data['academic_info'])
                    : null,
                skills: List<String>.from(data['skills'] ?? []),
                interests: List<String>.from(data['interests'] ?? []),
                experiences: (data['experiences'] as List<dynamic>?)
                        ?.map((e) => ExperienceModel.fromJson(e))
                        .toList() ??
                    [],
                projects: (data['projects'] as List<dynamic>?)
                        ?.map((p) => ProjectModel.fromJson(p))
                        .toList() ??
                    [],
                linkedinUrl: data['linkedin_url'],
                githubUrl: data['github_url'],
                portfolioUrl: data['portfolio_url'],
                phone: data['phone'],
                studentId: data['student_id'],
                department: data['department'],
                faculty: data['faculty'],
                yearOfStudy: data['year_of_study'],
                cgpa: data['cgpa']?.toString(),
                languages: List<String>.from(data['languages'] ?? []),
                isProfileComplete: data['is_profile_complete'] ?? false,
                completedSections: ['basic'], // Default sections
                createdAt: data['created_at'] != null
                    ? DateTime.parse(data['created_at'].toString())
                    : DateTime.now(),
                updatedAt: data['updated_at'] != null
                    ? DateTime.parse(data['updated_at'].toString())
                    : DateTime.now(),
              ))
          .toList();
    } catch (e) {
      debugPrint('ProfileService: Error getting all profiles: $e');
      return [];
    }
  }

  /// Helper method to get safe profile image URL
  String? _getSafeProfileImageUrl(dynamic imageUrl) {
    if (imageUrl == null || imageUrl.toString().isEmpty) {
      return null;
    }

    final url = imageUrl.toString();

    // Check if it's a placeholder URL that might fail
    if (url.contains('via.placeholder.com') ||
        url.contains('placeholder.com') ||
        url.contains('dummyimage.com')) {
      // Return a more reliable placeholder or null
      return null;
    }

    return url;
  }

  // Get profile by ID
  Future<ProfileModel?> getProfileById(String profileId) async {
    try {
      final response = await SupabaseConfig.client
          .from('profiles')
          .select('*')
          .eq('id', profileId)
          .single();

      return ProfileModel(
        id: response['id'] ?? '',
        userId: response['user_id'] ?? '',
        fullName: response['full_name'] ?? '',
        headline: response['headline'],
        bio: response['bio'],
        profileImageUrl: response['profile_image_url'],
        backgroundImageUrl: response['background_image_url'],
        academicInfo: response['academic_info'] != null
            ? AcademicInfoModel.fromJson(response['academic_info'])
            : null,
        skills: List<String>.from(response['skills'] ?? []),
        interests: List<String>.from(response['interests'] ?? []),
        experiences: (response['experiences'] as List<dynamic>?)
                ?.map((e) => ExperienceModel.fromJson(e))
                .toList() ??
            [],
        projects: (response['projects'] as List<dynamic>?)
                ?.map((p) => ProjectModel.fromJson(p))
                .toList() ??
            [],
        isProfileComplete: response['is_profile_complete'] ?? false,
        completedSections: ['basic'], // Default sections
        createdAt: response['created_at'] != null
            ? DateTime.parse(response['created_at'])
            : DateTime.now(),
        updatedAt: response['updated_at'] != null
            ? DateTime.parse(response['updated_at'])
            : DateTime.now(),
      );
    } catch (e) {
      debugPrint('ProfileService: Error getting profile from Supabase: $e');
      return null;
    }
  }

  // Upload profile header image using Cloudinary
  Future<String?> uploadHeaderImage(String filePath, String userId) async {
    try {
      // debugPrint('ProfileService: Uploading header image to Cloudinary...');
      // debugPrint('ProfileService: File path: $filePath');

      final imageUrl = await CloudinaryConfig.uploadImage(
        filePath: filePath,
        userId: userId,
        folder: 'profile_headers',
      );

      // debugPrint('ProfileService: Header uploaded successfully: $imageUrl');
      return imageUrl;
    } catch (e) {
      debugPrint('ProfileService: Error uploading header to Cloudinary: $e');
      throw Exception('Upload failed: $e');
    }
  }

  // Upload profile header image using raw bytes (bypasses dart:io File issues)
  Future<String?> uploadHeaderImageBytes(
      Uint8List bytes, String fileName, String userId) async {
    try {
      // debugPrint(
      //     'ProfileService: Uploading header image bytes to Cloudinary...');

      // Use CloudinaryConfig directly with bytes
      final uri =
          Uri.parse(CloudinaryConfig.imageUploadUrl);
      final request = http.MultipartRequest('POST', uri);

      // Add upload preset for unsigned uploads
      request.fields['upload_preset'] = 'STAP-media';
      request.fields['folder'] = 'profile_headers/$userId';

      // Add file as bytes
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
        ),
      );

      // Send request
      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final jsonResponse = json.decode(responseData);

      if (response.statusCode == 200) {
        final secureUrl = jsonResponse['secure_url'] as String;
        // debugPrint('ProfileService: Header uploaded successfully: $secureUrl');
        return secureUrl;
      } else {
        throw Exception(
            'Upload failed: ${jsonResponse['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      debugPrint('ProfileService: Error uploading header bytes: $e');
      throw Exception('Upload failed: $e');
    }
  }
}
