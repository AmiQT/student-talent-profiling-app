enum UserRole { student, lecturer, admin }

class UserModel {
  final String id;
  final String uid; // User ID
  final String email;
  // Password removed for security - Auth handles authentication
  final String name;
  final UserRole role;
  final String? studentId; // For students
  final String? staffId; // For lecturers/staff
  final String? department;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final DateTime? updatedAt;
  final bool isActive;
  final bool profileCompleted; // New field for profile completion status

  UserModel({
    required this.id,
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    this.studentId,
    this.staffId,
    this.department,
    required this.createdAt,
    this.lastLoginAt,
    this.isActive = true,
    this.profileCompleted = false, // Default to false
    this.updatedAt,
  });

  // Factory constructor to create UserModel from JSON
  factory UserModel.fromJson(Map<String, dynamic> json) {
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

    return UserModel(
      id: json['id'] ?? '',
      uid: json['uid'] ?? json['id'] ?? '', // Use id as fallback for uid
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      role: UserRole.values.firstWhere(
        (role) => role.toString().split('.').last == json['role'],
        orElse: () => UserRole.student,
      ),
      studentId: json['studentId'],
      staffId: json['staffId'],
      department: json['department'],
      createdAt: parseDateTime(json['createdAt']),
      lastLoginAt: json['lastLoginAt'] != null
          ? parseDateTime(json['lastLoginAt'])
          : null,
      isActive: json['isActive'] ?? true,
      profileCompleted:
          json['profileCompleted'] ?? json['profile_completed'] ?? false,
    );
  }

  // Convert UserModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uid': uid,
      'email': email,
      'name': name,
      'role': role.toString().split('.').last,
      'studentId': studentId,
      'department': department,
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'isActive': isActive,
      'profileCompleted': profileCompleted,
    };
  }

  // Create a copy of UserModel with updated fields
  UserModel copyWith({
    String? id,
    String? uid,
    String? email,
    String? name,
    UserRole? role,
    String? studentId,
    String? department,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    bool? isActive,
    bool? profileCompleted,
  }) {
    return UserModel(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      studentId: studentId ?? this.studentId,
      department: department ?? this.department,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      isActive: isActive ?? this.isActive,
      profileCompleted: profileCompleted ?? this.profileCompleted,
    );
  }

  @override
  String toString() {
    return 'UserModel(id: $id, email: $email, name: $name, role: $role, profileCompleted: $profileCompleted)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
