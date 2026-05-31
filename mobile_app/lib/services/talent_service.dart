import '../config/app_config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/talent_model.dart';

/// Service for managing talent-related operations
/// Handles soft skills, hobbies, quiz results, and recommendations
class TalentService {
  final String baseUrl;

  TalentService({String? baseUrl}) : baseUrl = baseUrl ?? AppConfig.backendUrl;

  /// Get talent categories (soft skills and hobbies)
  Future<Map<String, dynamic>> getTalentCategories() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/talents/categories'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('Failed to load categories: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error fetching categories: $e');
    }
  }

  /// Get talent profile for a user
  Future<TalentProfileModel> getTalentProfile(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/talents/profile/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return TalentProfileModel.fromJson(json.decode(response.body));
      }
      throw Exception('Failed to load talent profile: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error fetching talent profile: $e');
    }
  }

  /// Update soft skills for a user
  Future<List<SoftSkillModel>> updateSoftSkills(
    String userId,
    List<SoftSkillModel> softSkills,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/talents/soft-skills/$userId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'soft_skills': softSkills.map((s) => s.toJson()).toList(),
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['soft_skills'] as List)
            .map((s) => SoftSkillModel.fromJson(s))
            .toList();
      }
      throw Exception('Failed to update soft skills: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error updating soft skills: $e');
    }
  }

  /// Update hobbies for a user
  Future<List<HobbyModel>> updateHobbies(
    String userId,
    List<HobbyModel> hobbies,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/talents/hobbies/$userId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'hobbies': hobbies.map((h) => h.toJson()).toList(),
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['hobbies'] as List)
            .map((h) => HobbyModel.fromJson(h))
            .toList();
      }
      throw Exception('Failed to update hobbies: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error updating hobbies: $e');
    }
  }

  /// Submit talent quiz results
  Future<TalentQuizResultModel> submitQuizResults(
    String userId,
    List<Map<String, dynamic>> answers,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/talents/quiz-results/$userId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'answers': answers}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return TalentQuizResultModel.fromJson(data['quiz_results']);
      }
      throw Exception('Failed to submit quiz: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error submitting quiz: $e');
    }
  }

  /// Get quiz results for a user
  Future<TalentQuizResultModel?> getQuizResults(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/talents/quiz-results/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['quiz_results'] != null) {
          return TalentQuizResultModel.fromJson(data['quiz_results']);
        }
        return null;
      }
      throw Exception('Failed to get quiz results: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error fetching quiz results: $e');
    }
  }

  /// Get personalized recommendations
  Future<Map<String, dynamic>> getRecommendations(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/talents/recommendations/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('Failed to get recommendations: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error fetching recommendations: $e');
    }
  }
}
