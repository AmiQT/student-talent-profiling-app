// No Firestore import

enum AchievementType { academic, competition, leadership, skill, other }

class AchievementModel {
  final String id;
  final String userId;
  final String title;
  final String description;
  final AchievementType type;
  final String? organization;
  final DateTime? dateAchieved;
  final String? certificateUrl;
  final String? imageUrl;
  final int? points; // For scoring system
  final bool isVerified;
  final String? verifiedBy;
  final DateTime? verifiedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  AchievementModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.type,
    this.organization,
    this.dateAchieved,
    this.certificateUrl,
    this.imageUrl,
    this.points,
    this.isVerified = false,
    this.verifiedBy,
    this.verifiedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  // Factory constructor to create AchievementModel from JSON
  factory AchievementModel.fromJson(Map<String, dynamic> json) {
    return AchievementModel(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      type: AchievementType.values.firstWhere(
        (type) => type.toString().split('.').last == json['type'],
        orElse: () => AchievementType.other,
      ),
      organization: json['organization'],
      dateAchieved: json['dateAchieved'] != null
          ? DateTime.parse(json['dateAchieved'])
          : null,
      certificateUrl: json['certificateUrl'],
      imageUrl: json['imageUrl'],
      points: json['points'],
      isVerified: json['isVerified'] ?? false,
      verifiedBy: json['verifiedBy'],
      verifiedAt: json['verifiedAt'] != null
          ? DateTime.parse(json['verifiedAt'])
          : null,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  // Convert AchievementModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'description': description,
      'type': type.toString().split('.').last,
      'organization': organization,
      'dateAchieved': dateAchieved?.toIso8601String(),
      'certificateUrl': certificateUrl,
      'imageUrl': imageUrl,
      'points': points,
      'isVerified': isVerified,
      'verifiedBy': verifiedBy,
      'verifiedAt': verifiedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // Create a copy of AchievementModel with updated fields
  AchievementModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    AchievementType? type,
    String? organization,
    DateTime? dateAchieved,
    String? certificateUrl,
    String? imageUrl,
    int? points,
    bool? isVerified,
    String? verifiedBy,
    DateTime? verifiedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AchievementModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      organization: organization ?? this.organization,
      dateAchieved: dateAchieved ?? this.dateAchieved,
      certificateUrl: certificateUrl ?? this.certificateUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      points: points ?? this.points,
      isVerified: isVerified ?? this.isVerified,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Get achievement type display name
  String get typeDisplayName {
    switch (type) {
      case AchievementType.academic:
        return 'Academic';
      case AchievementType.competition:
        return 'Competition';
      case AchievementType.leadership:
        return 'Leadership';
      case AchievementType.skill:
        return 'Skill';
      case AchievementType.other:
        return 'Other';
    }
  }

  @override
  String toString() {
    return 'AchievementModel(id: $id, title: $title, type: $type)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AchievementModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
