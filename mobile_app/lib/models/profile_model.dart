import 'academic_info_model.dart';
import 'experience_model.dart';
import 'project_model.dart';
import 'achievement_model.dart';
import 'talent_model.dart';

class ProfileModel {
  final String id;
  final String userId;
  final String fullName;
  final String? phoneNumber;
  final String? address;
  final String? bio;
  final String? headline;
  final String? profileImageUrl;

  // Academic Information
  final AcademicInfoModel? academicInfo;

  // Skills and Interests
  final List<String> skills;
  final List<String> interests;

  // Experience
  final List<ExperienceModel> experiences;

  // Projects
  final List<ProjectModel> projects;

  // Achievements
  final List<AchievementModel> achievements;

  // Social Media URLs
  final String? linkedinUrl;
  final String? githubUrl;
  final String? portfolioUrl;

  // Additional fields for backend compatibility
  final String? phone;
  final String? studentId;
  final String? department;
  final String? faculty;
  final String? yearOfStudy;
  final String? cgpa;
  final List<String> languages;

  // Profile completion tracking
  final bool isProfileComplete;
  final List<String> completedSections;

  final DateTime createdAt;
  final DateTime updatedAt;

  // Added field
  final String? email;
  final String? backgroundImageUrl;

  // Talent profile for soft skills, hobbies, and quiz results
  final TalentProfileModel? talentProfile;

  ProfileModel({
    required this.id,
    required this.userId,
    required this.fullName,
    this.phoneNumber,
    this.address,
    this.bio,
    this.headline,
    this.profileImageUrl,
    this.academicInfo,
    this.skills = const [],
    this.interests = const [],
    this.experiences = const [],
    this.projects = const [],
    this.achievements = const [],
    this.isProfileComplete = false,
    this.completedSections = const [],
    this.linkedinUrl,
    this.githubUrl,
    this.portfolioUrl,
    this.phone,
    this.studentId,
    this.department,
    this.faculty,
    this.yearOfStudy,
    this.cgpa,
    this.languages = const [],
    required this.createdAt,
    required this.updatedAt,
    this.email,
    this.backgroundImageUrl,
    this.talentProfile,
  });

  // Factory constructor to create ProfileModel from JSON
  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDateTime(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is DateTime) return value;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          return DateTime.now();
        }
      }
      return DateTime.now();
    }

    return ProfileModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? json['userId'] ?? json['id'] ?? '',
      fullName: json['full_name'] ?? json['fullName'] ?? '',
      phoneNumber: json['phone_number'] ?? json['phoneNumber'],
      address: json['address'],
      bio: json['bio'],
      headline: json['headline'],
      profileImageUrl: json['profile_image_url'] ?? json['profileImageUrl'],
      backgroundImageUrl:
          json['background_image_url'] ?? json['backgroundImageUrl'],
      email: json['email'],
      academicInfo: json['academicInfo'] != null
          ? AcademicInfoModel.fromJson(json['academicInfo'])
          : null,
      skills: List<String>.from(json['skills'] ?? []),
      interests: List<String>.from(json['interests'] ?? []),
      experiences: (json['experiences'] as List?)
              ?.map((e) => ExperienceModel.fromJson(e))
              .toList() ??
          [],
      projects: (json['projects'] as List?)
              ?.map((p) => ProjectModel.fromJson(p))
              .toList() ??
          [],
      achievements: (json['achievements'] as List?)
              ?.map((a) => AchievementModel.fromJson(a))
              .toList() ??
          [],
      isProfileComplete: json['isProfileComplete'] ?? false,
      completedSections: List<String>.from(json['completedSections'] ?? []),
      createdAt: parseDateTime(json['created_at'] ?? json['createdAt']),
      updatedAt: parseDateTime(json['updated_at'] ?? json['updatedAt']),
      talentProfile: json['talent_profile'] != null
          ? TalentProfileModel.fromJson(json['talent_profile'])
          : null,
    );
  }

  // Convert ProfileModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'address': address,
      'bio': bio,
      'headline': headline,
      'profileImageUrl': profileImageUrl,
      'backgroundImageUrl': backgroundImageUrl,
      'email': email,
      'academicInfo': academicInfo?.toJson(),
      'skills': skills,
      'interests': interests,
      'experiences': experiences.map((e) => e.toJson()).toList(),
      'projects': projects.map((p) => p.toJson()).toList(),
      'achievements': achievements.map((a) => a.toJson()).toList(),
      'isProfileComplete': isProfileComplete,
      'completedSections': completedSections,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'talentProfile': talentProfile?.toJson(),
    };
  }

  // Convert ProfileModel to Map for local storage (keeping for compatibility)
  Map<String, dynamic> toFirestore() {
    return toJson();
  }

  // Factory constructor to create ProfileModel from local storage (keeping for compatibility)
  factory ProfileModel.fromFirestore(Map<String, dynamic> data) {
    return ProfileModel.fromJson(data);
  }

  // Create a copy of ProfileModel with updated fields
  ProfileModel copyWith({
    String? id,
    String? userId,
    String? fullName,
    String? phoneNumber,
    String? address,
    String? bio,
    String? headline,
    String? profileImageUrl,
    String? backgroundImageUrl,
    String? email,
    AcademicInfoModel? academicInfo,
    List<String>? skills,
    List<String>? interests,
    List<ExperienceModel>? experiences,
    List<ProjectModel>? projects,
    List<AchievementModel>? achievements,
    bool? isProfileComplete,
    List<String>? completedSections,
    DateTime? createdAt,
    DateTime? updatedAt,
    TalentProfileModel? talentProfile,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      bio: bio ?? this.bio,
      headline: headline ?? this.headline,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      backgroundImageUrl: backgroundImageUrl ?? this.backgroundImageUrl,
      email: email ?? this.email,
      academicInfo: academicInfo ?? this.academicInfo,
      skills: skills ?? this.skills,
      interests: interests ?? this.interests,
      experiences: experiences ?? this.experiences,
      projects: projects ?? this.projects,
      achievements: achievements ?? this.achievements,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
      completedSections: completedSections ?? this.completedSections,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      talentProfile: talentProfile ?? this.talentProfile,
    );
  }

  // Calculation Logic
  double calculateCompleteness() {
    int totalScore = 0;
    int maxScore = 5; // Total sections

    // 1. Basic Info (Name, etc - always present usually, check phone/address)
    if (fullName.isNotEmpty &&
        (phoneNumber?.isNotEmpty == true || address?.isNotEmpty == true)) {
      totalScore++;
    }

    // 2. Bio / Headline
    if (bio?.isNotEmpty == true || headline?.isNotEmpty == true) {
      totalScore++;
    }

    // 3. Profile Image
    if (profileImageUrl?.isNotEmpty == true) {
      totalScore++;
    }

    // 4. Skills
    if (skills.isNotEmpty) {
      totalScore++;
    }

    // 5. Experience/Projects
    if (experiences.isNotEmpty || projects.isNotEmpty) {
      totalScore++;
    }

    return (totalScore / maxScore) * 100;
  }

  // Helper getters for backward compatibility
  String get studentIdFromAcademic => academicInfo?.studentId ?? '';
  String get program => academicInfo?.program ?? '';
  String get departmentFromAcademic => academicInfo?.department ?? '';
  int get semester => academicInfo?.currentSemester ?? 1;

  @override
  String toString() {
    return 'ProfileModel(id: $id, fullName: $fullName)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProfileModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
