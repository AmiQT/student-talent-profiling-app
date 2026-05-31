class AcademicInfoModel {
  final String studentId;
  final String program;
  final String department;
  final String faculty;
  final int currentSemester;
  final double? cgpa;
  final int? totalCredits;
  final int? completedCredits;
  final DateTime enrollmentDate;
  final DateTime? expectedGraduation;
  final String? specialization;
  final List<String> minors;
  
  // Personal Advisor (PAK - Penasihat Akademik)
  final String? personalAdvisor; // PAK name e.g. "Dr. Muhaini"
  final String? personalAdvisorEmail;
  
  // Kokurikulum metrics
  final double? kokurikulumScore; // Score from 0-100
  final int? kokurikulumCredits; // Credits earned from koku activities
  final List<String> kokurikulumActivities; // List of koku activities

  AcademicInfoModel({
    required this.studentId,
    required this.program,
    required this.department,
    required this.faculty,
    required this.currentSemester,
    this.cgpa,
    this.totalCredits,
    this.completedCredits,
    required this.enrollmentDate,
    this.expectedGraduation,
    this.specialization,
    this.minors = const [],
    this.personalAdvisor,
    this.personalAdvisorEmail,
    this.kokurikulumScore,
    this.kokurikulumCredits,
    this.kokurikulumActivities = const [],
  });

  factory AcademicInfoModel.fromJson(Map<String, dynamic> json) {
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

    // Safe cgpa parsing
    double? parseCgpa(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        try {
          return double.parse(value);
        } catch (e) {
          return null;
        }
      }
      return null;
    }

    return AcademicInfoModel(
      studentId: json['studentId'] ?? json['student_id'] ?? '',
      program: json['program'] ?? '',
      department: json['department'] ?? '',
      faculty: json['faculty'] ?? '',
      currentSemester: json['currentSemester'] ?? json['current_semester'] ?? 1,
      cgpa: parseCgpa(json['cgpa']),
      totalCredits: json['totalCredits'] ?? json['total_credits'],
      completedCredits: json['completedCredits'] ?? json['completed_credits'],
      enrollmentDate: parseDateTime(json['enrollmentDate'] ?? json['enrollment_date']),
      expectedGraduation: (json['expectedGraduation'] ?? json['expected_graduation']) != null
          ? parseDateTime(json['expectedGraduation'] ?? json['expected_graduation'])
          : null,
      specialization: json['specialization'],
      minors: List<String>.from(json['minors'] ?? []),
      personalAdvisor: json['personalAdvisor'] ?? json['personal_advisor'] ?? json['pak'],
      personalAdvisorEmail: json['personalAdvisorEmail'] ?? json['personal_advisor_email'] ?? json['pak_email'],
      kokurikulumScore: parseCgpa(json['kokurikulumScore'] ?? json['kokurikulum_score'] ?? json['koku_score']),
      kokurikulumCredits: json['kokurikulumCredits'] ?? json['kokurikulum_credits'] ?? json['koku_credits'],
      kokurikulumActivities: List<String>.from(json['kokurikulumActivities'] ?? json['kokurikulum_activities'] ?? json['koku_activities'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'studentId': studentId,
      'program': program,
      'department': department,
      'faculty': faculty,
      'currentSemester': currentSemester,
      'cgpa': cgpa,
      'totalCredits': totalCredits,
      'completedCredits': completedCredits,
      'enrollmentDate': enrollmentDate.toIso8601String(),
      'expectedGraduation': expectedGraduation?.toIso8601String(),
      'specialization': specialization,
      'minors': minors,
      'personalAdvisor': personalAdvisor,
      'personalAdvisorEmail': personalAdvisorEmail,
      'kokurikulumScore': kokurikulumScore,
      'kokurikulumCredits': kokurikulumCredits,
      'kokurikulumActivities': kokurikulumActivities,
    };
  }

  AcademicInfoModel copyWith({
    String? studentId,
    String? program,
    String? department,
    String? faculty,
    int? currentSemester,
    double? cgpa,
    int? totalCredits,
    int? completedCredits,
    DateTime? enrollmentDate,
    DateTime? expectedGraduation,
    String? specialization,
    List<String>? minors,
    String? personalAdvisor,
    String? personalAdvisorEmail,
    double? kokurikulumScore,
    int? kokurikulumCredits,
    List<String>? kokurikulumActivities,
  }) {
    return AcademicInfoModel(
      studentId: studentId ?? this.studentId,
      program: program ?? this.program,
      department: department ?? this.department,
      faculty: faculty ?? this.faculty,
      currentSemester: currentSemester ?? this.currentSemester,
      cgpa: cgpa ?? this.cgpa,
      totalCredits: totalCredits ?? this.totalCredits,
      completedCredits: completedCredits ?? this.completedCredits,
      enrollmentDate: enrollmentDate ?? this.enrollmentDate,
      expectedGraduation: expectedGraduation ?? this.expectedGraduation,
      specialization: specialization ?? this.specialization,
      minors: minors ?? this.minors,
      personalAdvisor: personalAdvisor ?? this.personalAdvisor,
      personalAdvisorEmail: personalAdvisorEmail ?? this.personalAdvisorEmail,
      kokurikulumScore: kokurikulumScore ?? this.kokurikulumScore,
      kokurikulumCredits: kokurikulumCredits ?? this.kokurikulumCredits,
      kokurikulumActivities: kokurikulumActivities ?? this.kokurikulumActivities,
    );
  }
  
  // Helper method to calculate academic-kokurikulum balance
  Map<String, dynamic> getBalanceMetrics() {
    final academicScore = (cgpa ?? 0) / 4.0 * 100; // Convert CGPA to percentage
    final kokuScore = kokurikulumScore ?? 0;
    
    // Calculate balance score (0-100, where 50 is perfectly balanced)
    final diff = (academicScore - kokuScore).abs();
    final balanceScore = 100 - diff;
    
    String balanceStatus;
    if (diff <= 10) {
      balanceStatus = 'Seimbang'; // Balanced
    } else if (academicScore > kokuScore) {
      balanceStatus = 'Fokus Akademik'; // Academic focused
    } else {
      balanceStatus = 'Fokus Kokurikulum'; // Koku focused
    }
    
    return {
      'academicScore': academicScore,
      'kokurikulumScore': kokuScore,
      'balanceScore': balanceScore,
      'balanceStatus': balanceStatus,
      'recommendation': _getBalanceRecommendation(academicScore, kokuScore),
    };
  }
  
  String _getBalanceRecommendation(double academic, double koku) {
    final diff = academic - koku;
    if (diff.abs() <= 10) {
      return 'Tahniah! Anda mempunyai keseimbangan yang baik antara akademik dan kokurikulum.';
    } else if (diff > 20) {
      return 'Sertai lebih banyak aktiviti kokurikulum untuk keseimbangan yang lebih baik.';
    } else if (diff < -20) {
      return 'Tingkatkan fokus pada akademik untuk keseimbangan yang lebih baik.';
    } else if (diff > 0) {
      return 'Anda sedikit fokus pada akademik. Pertimbangkan untuk menyertai aktiviti kokurikulum.';
    } else {
      return 'Anda sedikit fokus pada kokurikulum. Pastikan akademik tidak terabai.';
    }
  }
}
