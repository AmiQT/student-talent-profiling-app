import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/report_model.dart';
import '../config/supabase_config.dart';

class ContentModerationService {
  // Get reports collection
  SupabaseQueryBuilder get reportsCollection => SupabaseConfig.from('reports');
  // Get moderation actions collection
  SupabaseQueryBuilder get moderationActionsCollection =>
      SupabaseConfig.from('moderationActions');

  // Profanity filter - basic implementation
  static const List<String> _profanityWords = [
    // Add appropriate words for your context
    'spam', 'fake', 'scam', // Basic examples
  ];

  /// Submit a report for content
  Future<String> submitReport({
    required String reporterId,
    required String reporterName,
    required String reportedUserId,
    required String reportedUserName,
    required ReportedContentType contentType,
    required String contentId,
    String? contentPreview,
    required ReportType type,
    required String reason,
    String? additionalDetails,
  }) async {
    try {
      final reportId = DateTime.now().millisecondsSinceEpoch.toString();

      final report = ReportModel(
        id: reportId,
        reporterId: reporterId,
        reporterName: reporterName,
        reportedUserId: reportedUserId,
        reportedUserName: reportedUserName,
        contentType: contentType,
        contentId: contentId,
        contentPreview: contentPreview,
        type: type,
        reason: reason,
        additionalDetails: additionalDetails,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await reportsCollection.insert(report.toJson());

      debugPrint('Report submitted successfully: $reportId');
      return reportId;
    } catch (e) {
      debugPrint('Error submitting report: $e');
      rethrow;
    }
  }

  /// Get all reports (admin only)
  Future<List<ReportModel>> getAllReports({
    ReportStatus? status,
    int limit = 50,
  }) async {
    try {
      var query = reportsCollection.select();

      if (status != null) {
        query = query.eq('status', status.toString().split('.').last);
      }

      final response =
          await query.order('createdAt', ascending: false).limit(limit);

      return response.map((doc) => ReportModel.fromJson(doc)).toList();
    } catch (e) {
      debugPrint('Error fetching reports: $e');
      return [];
    }
  }

  /// Get reports stream for real-time updates
  Stream<List<ReportModel>> getReportsStream({
    ReportStatus? status,
    int limit = 50,
  }) {
    try {
      var query = reportsCollection.select();

      if (status != null) {
        query = query.eq('status', status.toString().split('.').last);
      }

      // Implement with Supabase real-time subscriptions
      // Using periodic polling as fallback for real-time updates
      return Stream.periodic(const Duration(seconds: 30), (_) async {
        try {
          final response = await query.order('createdAt', ascending: false).limit(limit);
          return response.map((doc) => ReportModel.fromJson(doc)).toList();
        } catch (e) {
          debugPrint('Error fetching reports: $e');
          return <ReportModel>[];
        }
      }).asyncMap((future) => future);
    } catch (e) {
      debugPrint('Error getting reports stream: $e');
      return Stream.value([]);
    }
  }


  /// Validate content for inappropriate material
  Future<bool> validateContent(String content) async {
    try {
      // Simple profanity check - can be enhanced with AI/ML
      final lowerContent = content.toLowerCase();
      final profanityWords = ['spam', 'inappropriate', 'offensive', 'harassment'];
      
      for (final word in profanityWords) {
        if (lowerContent.contains(word)) {
          return false;
        }
      }
      return true;
    } catch (e) {
      debugPrint('Error validating content: $e');
      return true; // Default to allowing content if validation fails
    }
  }

  /// Update report status (admin only)
  Future<void> updateReportStatus({
    required String reportId,
    required ReportStatus status,
    required String reviewedBy,
    String? reviewNotes,
  }) async {
    try {
      await reportsCollection.update({
        'status': status.toString().split('.').last,
        'reviewedBy': reviewedBy,
        'reviewedAt': DateTime.now().toIso8601String(),
        'reviewNotes': reviewNotes,
        'updatedAt': DateTime.now().toIso8601String(),
      }).eq('id', reportId);

      debugPrint('Report status updated: $reportId -> $status');
    } catch (e) {
      debugPrint('Error updating report status: $e');
      rethrow;
    }
  }

  /// Check if content contains inappropriate material
  bool containsInappropriateContent(String content) {
    final lowerContent = content.toLowerCase();

    // Check for profanity
    for (final word in _profanityWords) {
      if (lowerContent.contains(word.toLowerCase())) {
        return true;
      }
    }

    // Check for spam patterns
    if (_isSpamContent(content)) {
      return true;
    }

    return false;
  }

  /// Check if content appears to be spam
  bool _isSpamContent(String content) {
    // Basic spam detection patterns
    final spamPatterns = [
      RegExp(r'(.)\1{4,}'), // Repeated characters (aaaaa)
      RegExp(r'[A-Z]{10,}'), // Excessive caps
      RegExp(r'(https?://[^\s]+){3,}'), // Multiple links
      RegExp(r'(\b\w+\b.*?){1,3}\1{3,}'), // Repeated phrases
    ];

    for (final pattern in spamPatterns) {
      if (pattern.hasMatch(content)) {
        return true;
      }
    }

    return false;
  }

  /// Validate content before posting with detailed analysis
  Map<String, dynamic> validateContentDetailed({
    required String content,
    List<String>? mediaUrls,
  }) {
    final issues = <String>[];

    // Check content length
    if (content.trim().isEmpty && (mediaUrls == null || mediaUrls.isEmpty)) {
      issues.add('Content cannot be empty');
    }

    if (content.length > 5000) {
      issues.add('Content is too long (max 5000 characters)');
    }

    // Check for inappropriate content
    if (containsInappropriateContent(content)) {
      issues.add('Content contains inappropriate material');
    }

    // Check for excessive mentions
    final mentionCount = RegExp(r'@\w+').allMatches(content).length;
    if (mentionCount > 10) {
      issues.add('Too many mentions (max 10)');
    }

    // Check for excessive hashtags
    final hashtagCount = RegExp(r'#\w+').allMatches(content).length;
    if (hashtagCount > 20) {
      issues.add('Too many hashtags (max 20)');
    }

    return {
      'isValid': issues.isEmpty,
      'issues': issues,
      'warnings': _getContentWarnings(content),
    };
  }

  /// Get content warnings
  List<String> _getContentWarnings(String content) {
    final warnings = <String>[];

    // Check for potential issues
    if (content.length > 3000) {
      warnings.add('Very long post - consider breaking it up');
    }

    final linkCount = RegExp(r'https?://[^\s]+').allMatches(content).length;
    if (linkCount > 2) {
      warnings.add('Multiple links detected - ensure they are relevant');
    }

    return warnings;
  }

  /// Get content statistics for admin dashboard
  Future<Map<String, dynamic>> getContentStatistics() async {
    try {
      final response = await reportsCollection.select();

      final reportsByType = <String, int>{};
      for (final report in response) {
        final type = report['type']?.toString().split('.').last ?? 'unknown';
        reportsByType[type] = (reportsByType[type] ?? 0) + 1;
      }

      return {
        'totalReports': response.length,
        'pendingReports': response.where((r) => r['status'] == 'pending').length,
        'resolvedReports': response.where((r) => r['status'] == 'resolved').length,
        'dismissedReports': response.where((r) => r['status'] == 'dismissed').length,
        'reportsByType': reportsByType,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('Error getting content statistics: $e');
      return {
        'totalReports': 0,
        'pendingReports': 0,
        'resolvedReports': 0,
        'dismissedReports': 0,
        'reportsByType': <String, int>{},
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Delete reported content (admin action)
  Future<void> deleteReportedContent({
    required String contentId,
    required ReportedContentType contentType,
    required String moderatorId,
    String? reason,
  }) async {
    try {
      // Log moderation action
      await moderationActionsCollection.insert({
        'action': 'delete_content',
        'contentId': contentId,
        'contentType': contentType.toString().split('.').last,
        'moderatorId': moderatorId,
        'reason': reason,
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Note: Actual content deletion would be handled by the respective services
      // (ShowcaseService for posts, etc.)

      debugPrint('Content deletion logged: $contentId');
    } catch (e) {
      debugPrint('Error logging content deletion: $e');
      rethrow;
    }
  }
}
