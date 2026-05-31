/// Talent-related models for soft skills, hobbies, and quiz results
/// Used for talent detection and recommendation system
import 'package:flutter/foundation.dart';

// ==================== ENUMS ====================

/// Soft skill categories
enum SoftSkillCategory {
  communication,
  leadership,
  teamwork,
  criticalThinking,
  problemSolving,
  creativity,
  timeManagement,
  adaptability,
  emotionalIntelligence,
}

/// Proficiency levels for skills
enum ProficiencyLevel {
  beginner, // 1
  elementary, // 2
  intermediate, // 3
  advanced, // 4
  expert, // 5
}

/// Hobby/Interest categories
enum HobbyCategory {
  performingArts,
  visualArts,
  sports,
  languageLiterature,
  technicalHobbies,
  communitySocial,
}

/// Subcategories for hobbies
enum HobbySubcategory {
  // Performing Arts
  musicInstrument,
  singing,
  traditionalDance,
  modernDance,
  drama,
  choir,

  // Visual Arts
  painting,
  digitalArt,
  photography,
  videography,
  sculpture,
  crafts,

  // Sports
  teamSports,
  individualSports,
  martialArts,
  esports,
  extremeSports,
  fitness,

  // Language & Literature
  publicSpeaking,
  debate,
  poetry,
  creativeWriting,
  journalism,
  foreignLanguage,

  // Technical Hobbies
  robotics,
  programming,
  gameDevelopment,
  electronics,
  threeDPrinting,
  diy,

  // Community & Social
  volunteering,
  environmentalism,
  entrepreneurship,
  eventOrganizing,
  mentoring,
  socialActivism,
}

// ==================== MODELS ====================

/// Model for soft skills
class SoftSkillModel {
  final String id;
  final String name;
  final SoftSkillCategory category;
  final ProficiencyLevel proficiencyLevel;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  SoftSkillModel({
    required this.id,
    required this.name,
    required this.category,
    required this.proficiencyLevel,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SoftSkillModel.fromJson(Map<String, dynamic> json) {
    return SoftSkillModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      category: SoftSkillCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => SoftSkillCategory.communication,
      ),
      proficiencyLevel: ProficiencyLevel.values.firstWhere(
        (p) => p.name == json['proficiency_level'],
        orElse: () => ProficiencyLevel.beginner,
      ),
      description: json['description'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category.name,
      'proficiency_level': proficiencyLevel.name,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  SoftSkillModel copyWith({
    String? id,
    String? name,
    SoftSkillCategory? category,
    ProficiencyLevel? proficiencyLevel,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SoftSkillModel(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      proficiencyLevel: proficiencyLevel ?? this.proficiencyLevel,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get display name for category
  String get categoryDisplayName {
    switch (category) {
      case SoftSkillCategory.communication:
        return 'Komunikasi';
      case SoftSkillCategory.leadership:
        return 'Kepimpinan';
      case SoftSkillCategory.teamwork:
        return 'Kerja Berpasukan';
      case SoftSkillCategory.criticalThinking:
        return 'Pemikiran Kritis';
      case SoftSkillCategory.problemSolving:
        return 'Penyelesaian Masalah';
      case SoftSkillCategory.creativity:
        return 'Kreativiti';
      case SoftSkillCategory.timeManagement:
        return 'Pengurusan Masa';
      case SoftSkillCategory.adaptability:
        return 'Kebolehsuaian';
      case SoftSkillCategory.emotionalIntelligence:
        return 'Kecerdasan Emosi';
    }
  }

  /// Get proficiency level as integer (1-5)
  int get proficiencyValue {
    return proficiencyLevel.index + 1;
  }

  /// Get proficiency display name
  String get proficiencyDisplayName {
    switch (proficiencyLevel) {
      case ProficiencyLevel.beginner:
        return 'Pemula';
      case ProficiencyLevel.elementary:
        return 'Asas';
      case ProficiencyLevel.intermediate:
        return 'Pertengahan';
      case ProficiencyLevel.advanced:
        return 'Mahir';
      case ProficiencyLevel.expert:
        return 'Pakar';
    }
  }
}

/// Model for hobbies/interests
class HobbyModel {
  final String id;
  final String name;
  final HobbyCategory category;
  final HobbySubcategory? subcategory;
  final int? yearsExperience;
  final String? description;
  final List<String> achievements;
  final DateTime createdAt;
  final DateTime updatedAt;

  HobbyModel({
    required this.id,
    required this.name,
    required this.category,
    this.subcategory,
    this.yearsExperience,
    this.description,
    this.achievements = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory HobbyModel.fromJson(Map<String, dynamic> json) {
    return HobbyModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      category: HobbyCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => HobbyCategory.performingArts,
      ),
      subcategory: json['subcategory'] != null
          ? HobbySubcategory.values.firstWhere(
              (s) => s.name == json['subcategory'],
              orElse: () => HobbySubcategory.musicInstrument,
            )
          : null,
      yearsExperience: json['years_experience'],
      description: json['description'],
      achievements: List<String>.from(json['achievements'] ?? []),
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category.name,
      'subcategory': subcategory?.name,
      'years_experience': yearsExperience,
      'description': description,
      'achievements': achievements,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  HobbyModel copyWith({
    String? id,
    String? name,
    HobbyCategory? category,
    HobbySubcategory? subcategory,
    int? yearsExperience,
    String? description,
    List<String>? achievements,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HobbyModel(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      yearsExperience: yearsExperience ?? this.yearsExperience,
      description: description ?? this.description,
      achievements: achievements ?? this.achievements,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get display name for category
  String get categoryDisplayName {
    switch (category) {
      case HobbyCategory.performingArts:
        return 'Seni Persembahan';
      case HobbyCategory.visualArts:
        return 'Seni Visual';
      case HobbyCategory.sports:
        return 'Sukan';
      case HobbyCategory.languageLiterature:
        return 'Bahasa & Sastera';
      case HobbyCategory.technicalHobbies:
        return 'Hobi Teknikal';
      case HobbyCategory.communitySocial:
        return 'Komuniti & Sosial';
    }
  }

  /// Get icon for category
  String get categoryIcon {
    switch (category) {
      case HobbyCategory.performingArts:
        return '🎭';
      case HobbyCategory.visualArts:
        return '🎨';
      case HobbyCategory.sports:
        return '⚽';
      case HobbyCategory.languageLiterature:
        return '📚';
      case HobbyCategory.technicalHobbies:
        return '🔧';
      case HobbyCategory.communitySocial:
        return '🌱';
    }
  }
}

/// Model for talent quiz results
class TalentQuizResultModel {
  final String id;
  final String oderId;
  final Map<String, int> categoryScores; // category name -> score
  final List<String> topTalents; // Top 3 talent categories
  final Map<String, dynamic> answers; // Question ID -> Answer
  final DateTime completedAt;

  TalentQuizResultModel({
    required this.id,
    required this.oderId,
    required this.categoryScores,
    required this.topTalents,
    required this.answers,
    required this.completedAt,
  });

  factory TalentQuizResultModel.fromJson(Map<String, dynamic> json) {
    debugPrint('TalentQuizResultModel.fromJson: Raw JSON = $json');
    debugPrint(
        'TalentQuizResultModel.fromJson: category_scores = ${json['category_scores']}');
    debugPrint(
        'TalentQuizResultModel.fromJson: top_talents = ${json['top_talents']}');
    return TalentQuizResultModel(
      id: json['id'] ?? '',
      oderId: json['user_id'] ?? '',
      categoryScores: Map<String, int>.from(json['category_scores'] ?? {}),
      topTalents: List<String>.from(json['top_talents'] ?? []),
      answers: Map<String, dynamic>.from(json['answers'] ?? {}),
      completedAt:
          DateTime.tryParse(json['completed_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': oderId,
      'category_scores': categoryScores,
      'top_talents': topTalents,
      'answers': answers,
      'completed_at': completedAt.toIso8601String(),
    };
  }

  /// Check if quiz has been completed
  bool get isCompleted => answers.isNotEmpty;

  /// Get highest scoring category
  String? get primaryTalent {
    if (topTalents.isNotEmpty) {
      return topTalents.first;
    }

    // Fallback: Calculate from categoryScores if topTalents is empty
    if (categoryScores.isNotEmpty) {
      final sortedEntries = categoryScores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return sortedEntries.first.key;
    }

    return null;
  }
}

/// Combined talent profile model
class TalentProfileModel {
  final String userId;
  final List<SoftSkillModel> softSkills;
  final List<HobbyModel> hobbies;
  final TalentQuizResultModel? quizResults;
  final DateTime updatedAt;

  TalentProfileModel({
    required this.userId,
    this.softSkills = const [],
    this.hobbies = const [],
    this.quizResults,
    required this.updatedAt,
  });

  factory TalentProfileModel.fromJson(Map<String, dynamic> json) {
    return TalentProfileModel(
      userId: json['user_id'] ?? '',
      softSkills: (json['soft_skills'] as List?)
              ?.map((s) => SoftSkillModel.fromJson(s))
              .toList() ??
          [],
      hobbies: (json['hobbies'] as List?)
              ?.map((h) => HobbyModel.fromJson(h))
              .toList() ??
          [],
      quizResults: json['quiz_results'] != null
          ? TalentQuizResultModel.fromJson(json['quiz_results'])
          : null,
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'soft_skills': softSkills.map((s) => s.toJson()).toList(),
      'hobbies': hobbies.map((h) => h.toJson()).toList(),
      'quiz_results': quizResults?.toJson(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  TalentProfileModel copyWith({
    String? userId,
    List<SoftSkillModel>? softSkills,
    List<HobbyModel>? hobbies,
    TalentQuizResultModel? quizResults,
    DateTime? updatedAt,
  }) {
    return TalentProfileModel(
      userId: userId ?? this.userId,
      softSkills: softSkills ?? this.softSkills,
      hobbies: hobbies ?? this.hobbies,
      quizResults: quizResults ?? this.quizResults,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if user has completed talent quiz
  bool get hasCompletedQuiz => quizResults?.isCompleted ?? false;

  /// Get all hobby categories user is interested in
  Set<HobbyCategory> get hobbyCategories =>
      hobbies.map((h) => h.category).toSet();

  /// Get all soft skill categories user has
  Set<SoftSkillCategory> get softSkillCategories =>
      softSkills.map((s) => s.category).toSet();
}
