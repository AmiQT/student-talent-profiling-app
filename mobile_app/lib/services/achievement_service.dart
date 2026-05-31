import '../config/app_config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/achievement_model.dart';
import '../utils/error_handler.dart';
import 'auto_notification_service.dart';
import 'supabase_auth_service.dart';
import 'dart:io';
import '../config/supabase_config.dart';

class AchievementService {
  static String get baseUrl => AppConfig.backendUrl; // Use stable backend URL

  final SupabaseAuthService _authService = SupabaseAuthService();

  // Get Supabase auth token for authentication
  static Future<String?> _getAuthToken() async {
    try {
      final session = SupabaseConfig.auth.currentSession;
      if (session?.accessToken != null) {
        return session!.accessToken;
      }
      return null;
    } catch (e) {
      debugPrint('AchievementService: Error getting auth token: $e');
      return null;
    }
  }

  Stream<List<AchievementModel>> streamAllAchievements() {
    // Use periodic polling instead of real-time streams for now
    return Stream.periodic(const Duration(seconds: 30), (_) async {
      return await getAllAchievements();
    }).asyncMap((future) => future).handleError((error) {
      debugPrint('❌ Error in achievement stream: $error');
      return <AchievementModel>[];
    });
  }

  Future<List<AchievementModel>> getAllAchievements() async {
    try {
      debugPrint('AchievementService: Fetching all achievements');

      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('No authentication token available');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/achievements'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> achievementsJson = data['achievements'] ?? data;

        final achievements = <AchievementModel>[];
        for (final achievementData in achievementsJson) {
          final achievement = AchievementModel(
            id: achievementData['id'] ?? '',
            userId: achievementData['user_id'] ?? '',
            title: achievementData['title'] ?? '',
            description: achievementData['description'] ?? '',
            type: AchievementType.values.firstWhere(
              (e) =>
                  e.toString().split('.').last ==
                  (achievementData['category'] ?? 'other'),
              orElse: () => AchievementType.other,
            ),
            organization: achievementData['issuing_organization'],
            dateAchieved: achievementData['date_achieved'] != null
                ? DateTime.parse(achievementData['date_achieved'])
                : null,
            certificateUrl: achievementData['certificate_url'],
            imageUrl: achievementData['image_url'],
            points: achievementData['points'],
            isVerified: achievementData['is_verified'] ?? false,
            verifiedBy: achievementData['verified_by'],
            verifiedAt: achievementData['verified_at'] != null
                ? DateTime.parse(achievementData['verified_at'])
                : null,
            createdAt: achievementData['created_at'] != null
                ? DateTime.parse(achievementData['created_at'])
                : DateTime.now(),
            updatedAt: achievementData['updated_at'] != null
                ? DateTime.parse(achievementData['updated_at'])
                : DateTime.now(),
          );
          achievements.add(achievement);
        }

        debugPrint(
            'AchievementService: Found ${achievements.length} achievements');
        return achievements;
      } else {
        throw Exception('Failed to fetch achievements: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('AchievementService: Error fetching achievements: $e');
      throw Exception('Failed to fetch achievements: ${e.toString()}');
    }
  }

  Future<List<AchievementModel>> getAchievementsByUserId(String userId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('No authentication token available');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/achievements?user_id=$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> achievementsJson = data['achievements'] ?? data;

        final achievements = <AchievementModel>[];
        for (final achievementData in achievementsJson) {
          final achievement = AchievementModel(
            id: achievementData['id'] ?? '',
            userId: achievementData['user_id'] ?? '',
            title: achievementData['title'] ?? '',
            description: achievementData['description'] ?? '',
            type: AchievementType.values.firstWhere(
              (e) =>
                  e.toString().split('.').last ==
                  (achievementData['category'] ?? 'other'),
              orElse: () => AchievementType.other,
            ),
            organization: achievementData['issuing_organization'],
            dateAchieved: achievementData['date_achieved'] != null
                ? DateTime.parse(achievementData['date_achieved'])
                : null,
            certificateUrl: achievementData['certificate_url'],
            imageUrl: achievementData['image_url'],
            points: achievementData['points'],
            isVerified: achievementData['is_verified'] ?? false,
            verifiedBy: achievementData['verified_by'],
            verifiedAt: achievementData['verified_at'] != null
                ? DateTime.parse(achievementData['verified_at'])
                : null,
            createdAt: achievementData['created_at'] != null
                ? DateTime.parse(achievementData['created_at'])
                : DateTime.now(),
            updatedAt: achievementData['updated_at'] != null
                ? DateTime.parse(achievementData['updated_at'])
                : DateTime.now(),
          );
          achievements.add(achievement);
        }

        return achievements;
      } else {
        debugPrint(
            'Error fetching achievements by user ID: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Error fetching achievements by user ID: $e');
      return [];
    }
  }

  Future<void> createAchievement(AchievementModel achievement) async {
    try {
      // Validate achievement data
      if (achievement.title.isEmpty || achievement.userId.isEmpty) {
        throw Exception('Achievement title and user ID are required');
      }

      debugPrint(
          'AchievementService: Creating achievement: ${achievement.title}');

      await SupabaseConfig.from('achievements').insert({
        'id': achievement.id,
        'user_id': achievement.userId,
        'title': achievement.title,
        'description': achievement.description,
        'category': achievement.type.toString().split('.').last,
        'issuing_organization': achievement.organization,
        'date_achieved': achievement.dateAchieved?.toIso8601String(),
        'certificate_url': achievement.certificateUrl,
        'image_url': achievement.imageUrl,
        'points': achievement.points,
        'is_verified': achievement.isVerified,
        'verified_by': achievement.verifiedBy,
        'verified_at': achievement.verifiedAt?.toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Create notification for achievement submission
      await AutoNotificationService.onMilestoneAchieved(
        userId: achievement.userId,
        milestoneTitle: 'Achievement Submitted! 📝',
        description:
            'Your achievement "${achievement.title}" has been submitted for review.',
      );

      debugPrint('AchievementService: Achievement created successfully');
    } on PostgrestException catch (e) {
      debugPrint(
          'AchievementService: Supabase error creating achievement: ${e.message}');
      throw Exception(
          'Failed to create achievement: ${ErrorHandler.getUserFriendlyMessage(e)}');
    } catch (e) {
      debugPrint('AchievementService: Error creating achievement: $e');
      throw Exception('Failed to create achievement: $e');
    }
  }

  Future<void> updateAchievement(AchievementModel achievement) async {
    try {
      await SupabaseConfig.from('achievements').update({
        'id': achievement.id,
        'user_id': achievement.userId,
        'title': achievement.title,
        'description': achievement.description,
        'category': achievement.type.toString().split('.').last,
        'issuing_organization': achievement.organization,
        'date_achieved': achievement.dateAchieved?.toIso8601String(),
        'certificate_url': achievement.certificateUrl,
        'image_url': achievement.imageUrl,
        'points': achievement.points,
        'is_verified': achievement.isVerified,
        'verified_by': achievement.verifiedBy,
        'verified_at': achievement.verifiedAt?.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error updating achievement: $e');
      rethrow;
    }
  }

  Future<void> deleteAchievement(String achievementId) async {
    try {
      await SupabaseConfig.from('achievements')
          .delete()
          .eq('id', achievementId);
    } catch (e) {
      debugPrint('Error deleting achievement: $e');
      rethrow;
    }
  }

  Future<AchievementModel?> getAchievementById(String achievementId) async {
    try {
      final response = await SupabaseConfig.from('achievements')
          .select()
          .eq('id', achievementId)
          .single();

      return AchievementModel.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching achievement by ID: $e');
      return null;
    }
  }

  Future<List<AchievementModel>> getAchievementsByType(
      AchievementType type) async {
    try {
      final response = await SupabaseConfig.from('achievements')
          .select()
          .eq('category', type.toString().split('.').last);

      return response.map((item) => AchievementModel.fromJson(item)).toList();
    } catch (e) {
      debugPrint('Error fetching achievements by type: $e');
      return [];
    }
  }

  Future<List<AchievementModel>> searchAchievements(String query) async {
    try {
      final q = query.toLowerCase();
      final allAchievements = await getAllAchievements();
      return allAchievements
          .where((a) =>
              a.title.toLowerCase().contains(q) ||
              a.description.toLowerCase().contains(q) ||
              (a.organization?.toLowerCase().contains(q) ?? false))
          .toList();
    } catch (e) {
      debugPrint('Error searching achievements: $e');
      return [];
    }
  }

  Future<List<AchievementModel>> getPendingVerifications() async {
    try {
      final response = await SupabaseConfig.from('achievements')
          .select()
          .eq('is_verified', false);

      return (response as List<dynamic>)
          .map(
              (item) => AchievementModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching pending verifications: $e');
      return [];
    }
  }

  Future<void> verifyAchievement(
      String achievementId, String verifiedBy) async {
    try {
      // Get achievement details first
      final response = await SupabaseConfig.from('achievements')
          .select()
          .eq('id', achievementId)
          .single();

      final achievement = AchievementModel.fromJson(response);

      await SupabaseConfig.from('achievements').update({
        'id': achievementId,
        'is_verified': true,
        'verified_by': verifiedBy,
        'verified_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', achievementId);

      // Create notification for achievement verification
      await AutoNotificationService.onMilestoneAchieved(
        userId: achievement.userId,
        milestoneTitle: 'Achievement Verified! 🎉',
        description:
            'Your achievement "${achievement.title}" has been verified by $verifiedBy.',
      );

      // Check for milestone achievements
      await _checkForMilestones(achievement.userId);
    } on PostgrestException catch (e) {
      debugPrint('Error verifying achievement: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error verifying achievement: $e');
      rethrow;
    }
  }

  Future<void> rejectAchievement(
      String achievementId, String rejectedBy, String reason) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/achievements/$achievementId/reject'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await _authService.getAuthToken()}',
        },
        body: jsonEncode({
          'rejected_by': rejectedBy,
          'reason': reason,
          'rejected_at': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('Achievement rejected successfully: $achievementId');
      } else {
        throw Exception('Failed to reject achievement: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error rejecting achievement: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getAchievementStats() async {
    try {
      final allAchievements = await getAllAchievements();

      // Count by type
      final typeCounts = <String, int>{};
      for (var achievement in allAchievements) {
        final type = achievement.type.toString().split('.').last;
        typeCounts[type] = (typeCounts[type] ?? 0) + 1;
      }

      // Count verified vs unverified
      final verifiedCount = allAchievements.where((a) => a.isVerified).length;
      final unverifiedCount = allAchievements.length - verifiedCount;

      // Total points
      final totalPoints = allAchievements
          .where((a) => a.isVerified)
          .fold(0, (accumulator, a) => accumulator + (a.points ?? 0));

      return {
        'totalAchievements': allAchievements.length,
        'verifiedAchievements': verifiedCount,
        'unverifiedAchievements': unverifiedCount,
        'totalPoints': totalPoints,
        'typeCounts': typeCounts,
      };
    } catch (e) {
      debugPrint('Error getting achievement stats: $e');
      return {
        'totalAchievements': 0,
        'verifiedAchievements': 0,
        'unverifiedAchievements': 0,
        'totalPoints': 0,
        'typeCounts': {},
      };
    }
  }

  Stream<List<AchievementModel>> streamAchievementsByUserId(String userId) {
    return Stream.periodic(const Duration(seconds: 30), (_) async {
      return await getAchievementsByUserId(userId);
    }).asyncMap((future) => future).handleError((error) {
      debugPrint('❌ Error in achievement stream: $error');
      return <AchievementModel>[];
    });
  }

  Stream<List<AchievementModel>> streamPendingVerifications() {
    return Stream.periodic(const Duration(seconds: 30), (_) async {
      return await getPendingVerifications();
    }).asyncMap((future) => future).handleError((error) {
      debugPrint('❌ Error in pending verifications stream: $error');
      return <AchievementModel>[];
    });
  }

  /// Upload certificate file
  Future<String> uploadCertificate(String userId, File file) async {
    try {
      debugPrint(
          'AchievementService: Uploading certificate for user $userId from: ${file.path}');

      // Create a unique filename
      final fileName =
          'certificates/${userId}_${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';

      // Upload to Supabase Storage
      await SupabaseConfig.storage.from('certificates').upload(fileName, file);

      // Get download URL
      final publicUrl =
          SupabaseConfig.storage.from('certificates').getPublicUrl(fileName);

      debugPrint(
          'AchievementService: Certificate uploaded successfully: $publicUrl');

      return publicUrl;
    } catch (e) {
      debugPrint('AchievementService: Error uploading certificate: $e');
      rethrow;
    }
  }

  /// Upload achievement image
  Future<String> uploadAchievementImage(String userId, File file) async {
    try {
      debugPrint(
          'AchievementService: Uploading achievement image for user $userId from: ${file.path}');

      // Create a unique filename
      final fileName =
          'achievement_images/${userId}_${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';

      // Upload to Supabase Storage
      await SupabaseConfig.storage
          .from('achievement_images')
          .upload(fileName, file);

      // Get download URL
      final publicUrl = SupabaseConfig.storage
          .from('achievement_images')
          .getPublicUrl(fileName);

      debugPrint(
          'AchievementService: Achievement image uploaded successfully: $publicUrl');

      return publicUrl;
    } catch (e) {
      debugPrint('AchievementService: Error uploading achievement image: $e');
      rethrow;
    }
  }

  /// Get default points for achievement type
  int getDefaultPoints(AchievementType type) {
    switch (type) {
      case AchievementType.academic:
        return 10;
      case AchievementType.competition:
        return 15;
      case AchievementType.leadership:
        return 12;
      case AchievementType.skill:
        return 8;
      case AchievementType.other:
        return 5;
    }
  }

  /// Check for milestone achievements and create notifications
  Future<void> _checkForMilestones(String userId) async {
    try {
      final userAchievements = await getAchievementsByUserId(userId);
      final verifiedAchievements =
          userAchievements.where((a) => a.isVerified).toList();

      final totalPoints =
          verifiedAchievements.fold(0, (total, a) => total + (a.points ?? 0));
      final achievementCount = verifiedAchievements.length;

      // Check for point milestones
      final pointMilestones = [50, 100, 200, 500, 1000];
      for (final milestone in pointMilestones) {
        if (totalPoints >= milestone &&
            totalPoints - (verifiedAchievements.last.points ?? 0) < milestone) {
          await AutoNotificationService.onMilestoneAchieved(
            userId: userId,
            milestoneTitle: 'Points Milestone Reached! 🌟',
            description:
                'Congratulations! You\'ve earned $milestone points total!',
          );
        }
      }

      // Check for achievement count milestones
      final countMilestones = [5, 10, 25, 50];
      for (final milestone in countMilestones) {
        if (achievementCount >= milestone && achievementCount - 1 < milestone) {
          await AutoNotificationService.onMilestoneAchieved(
            userId: userId,
            milestoneTitle: 'Achievement Milestone! 🏆',
            description:
                'Amazing! You\'ve earned $milestone verified achievements!',
          );
        }
      }

      // Check for category diversity (achievements in multiple categories)
      final categories = verifiedAchievements.map((a) => a.type).toSet();
      if (categories.length >= 3 && verifiedAchievements.length >= 3) {
        // Check if this is the first time reaching 3+ categories
        final previousCount = verifiedAchievements.length - 1;
        if (previousCount < 3) {
          await AutoNotificationService.onMilestoneAchieved(
            userId: userId,
            milestoneTitle: 'Well-Rounded Achiever! 🎯',
            description:
                'Excellent! You\'ve earned achievements in multiple categories!',
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking for milestones: $e');
    }
  }
}
