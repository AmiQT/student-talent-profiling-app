// Firebase import removed - migrating to Supabase
// import 'package:cloud_firestore/cloud_firestore.dart';

enum ReportType {
  spam,
  harassment,
  inappropriateContent,
  falseInformation,
  copyright,
  other,
}

enum ReportStatus {
  pending,
  reviewed,
  resolved,
  dismissed,
}

enum ReportedContentType {
  post,
  comment,
  profile,
  user,
}

class ReportModel {
  final String id;
  final String reporterId;
  final String reporterName;
  final String reportedUserId;
  final String reportedUserName;
  final ReportedContentType contentType;
  final String contentId;
  final String? contentPreview;
  final ReportType type;
  final String reason;
  final String? additionalDetails;
  final ReportStatus status;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? reviewNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  ReportModel({
    required this.id,
    required this.reporterId,
    required this.reporterName,
    required this.reportedUserId,
    required this.reportedUserName,
    required this.contentType,
    required this.contentId,
    this.contentPreview,
    required this.type,
    required this.reason,
    this.additionalDetails,
    this.status = ReportStatus.pending,
    this.reviewedBy,
    this.reviewedAt,
    this.reviewNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      id: json['id'] ?? '',
      reporterId: json['reporterId'] ?? '',
      reporterName: json['reporterName'] ?? '',
      reportedUserId: json['reportedUserId'] ?? '',
      reportedUserName: json['reportedUserName'] ?? '',
      contentType: ReportedContentType.values.firstWhere(
        (e) => e.toString().split('.').last == json['contentType'],
        orElse: () => ReportedContentType.post,
      ),
      contentId: json['contentId'] ?? '',
      contentPreview: json['contentPreview'],
      type: ReportType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => ReportType.other,
      ),
      reason: json['reason'] ?? '',
      additionalDetails: json['additionalDetails'],
      status: ReportStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => ReportStatus.pending,
      ),
      reviewedBy: json['reviewedBy'],
      reviewedAt: json['reviewedAt'] != null
          ? (json['reviewedAt'] is String
              ? DateTime.parse(json['reviewedAt'])
              : DateTime.fromMillisecondsSinceEpoch(json['reviewedAt']))
          : null,
      reviewNotes: json['reviewNotes'],
      createdAt: json['createdAt'] is String
          ? DateTime.parse(json['createdAt'])
          : DateTime.fromMillisecondsSinceEpoch(json['createdAt'] ?? 0),
      updatedAt: json['updatedAt'] is String
          ? DateTime.parse(json['updatedAt'])
          : DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] ?? 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reporterId': reporterId,
      'reporterName': reporterName,
      'reportedUserId': reportedUserId,
      'reportedUserName': reportedUserName,
      'contentType': contentType.toString().split('.').last,
      'contentId': contentId,
      'contentPreview': contentPreview,
      'type': type.toString().split('.').last,
      'reason': reason,
      'additionalDetails': additionalDetails,
      'status': status.toString().split('.').last,
      'reviewedBy': reviewedBy,
      'reviewedAt': reviewedAt?.toIso8601String(),
      'reviewNotes': reviewNotes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  ReportModel copyWith({
    String? id,
    String? reporterId,
    String? reporterName,
    String? reportedUserId,
    String? reportedUserName,
    ReportedContentType? contentType,
    String? contentId,
    String? contentPreview,
    ReportType? type,
    String? reason,
    String? additionalDetails,
    ReportStatus? status,
    String? reviewedBy,
    DateTime? reviewedAt,
    String? reviewNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReportModel(
      id: id ?? this.id,
      reporterId: reporterId ?? this.reporterId,
      reporterName: reporterName ?? this.reporterName,
      reportedUserId: reportedUserId ?? this.reportedUserId,
      reportedUserName: reportedUserName ?? this.reportedUserName,
      contentType: contentType ?? this.contentType,
      contentId: contentId ?? this.contentId,
      contentPreview: contentPreview ?? this.contentPreview,
      type: type ?? this.type,
      reason: reason ?? this.reason,
      additionalDetails: additionalDetails ?? this.additionalDetails,
      status: status ?? this.status,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewNotes: reviewNotes ?? this.reviewNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get typeDisplayName {
    switch (type) {
      case ReportType.spam:
        return 'Spam';
      case ReportType.harassment:
        return 'Harassment';
      case ReportType.inappropriateContent:
        return 'Inappropriate Content';
      case ReportType.falseInformation:
        return 'False Information';
      case ReportType.copyright:
        return 'Copyright Violation';
      case ReportType.other:
        return 'Other';
    }
  }

  String get statusDisplayName {
    switch (status) {
      case ReportStatus.pending:
        return 'Pending Review';
      case ReportStatus.reviewed:
        return 'Under Review';
      case ReportStatus.resolved:
        return 'Resolved';
      case ReportStatus.dismissed:
        return 'Dismissed';
    }
  }

  String get contentTypeDisplayName {
    switch (contentType) {
      case ReportedContentType.post:
        return 'Post';
      case ReportedContentType.comment:
        return 'Comment';
      case ReportedContentType.profile:
        return 'Profile';
      case ReportedContentType.user:
        return 'User';
    }
  }
}
