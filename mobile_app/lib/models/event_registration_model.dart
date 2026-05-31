class EventRegistrationModel {
  final String? id;
  final String eventId;
  final String userId;
  final DateTime registrationDate;
  final String? attendanceStatus; // 'pending', 'confirmed', 'attended', 'cancelled'

  // Auto-filled from Profile
  final String fullName;
  final String studentId;
  final String phone;
  final String email;
  final String program;
  final String department;
  final String faculty;
  final List<String> relevantSkills;

  // Feedback after event
  final double? feedbackRating;
  final String? feedbackComment;

  EventRegistrationModel({
    this.id,
    required this.eventId,
    required this.userId,
    required this.registrationDate,
    this.attendanceStatus = 'pending',
    required this.fullName,
    required this.studentId,
    required this.phone,
    required this.email,
    required this.program,
    required this.department,
    required this.faculty,
    required this.relevantSkills,
    this.feedbackRating,
    this.feedbackComment,
  });

  factory EventRegistrationModel.fromJson(Map<String, dynamic> json) {
    // Handle participant_data JSONB field from database
    final participantData = json['participant_data'] ?? {};

    return EventRegistrationModel(
      id: json['id'],
      eventId: json['event_id'] ?? json['eventId'] ?? '',
      userId: json['user_id'] ?? json['userId'] ?? '',
      registrationDate: json['registration_date'] is String
          ? DateTime.parse(json['registration_date'])
          : (json['registrationDate'] is String
              ? DateTime.parse(json['registrationDate'])
              : DateTime.now()),
      attendanceStatus: json['attendance_status'] ?? json['attendanceStatus'] ?? 'pending',
      fullName: participantData['fullName'] ?? json['fullName'] ?? '',
      studentId: participantData['studentId'] ?? json['studentId'] ?? '',
      phone: participantData['phone'] ?? json['phone'] ?? '',
      email: participantData['email'] ?? json['email'] ?? '',
      program: participantData['program'] ?? json['program'] ?? '',
      department: participantData['department'] ?? json['department'] ?? '',
      faculty: participantData['faculty'] ?? json['faculty'] ?? '',
      relevantSkills: participantData['relevantSkills'] != null
          ? List<String>.from(participantData['relevantSkills'])
          : (json['relevantSkills'] != null
              ? List<String>.from(json['relevantSkills'])
              : []),
      feedbackRating: json['feedback_rating']?.toDouble() ?? json['feedbackRating']?.toDouble(),
      feedbackComment: json['feedback_comment'] ?? json['feedbackComment'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'user_id': userId,
      'registration_date': registrationDate.toIso8601String(),
      'attendance_status': attendanceStatus,
      'participant_data': {
        'fullName': fullName,
        'studentId': studentId,
        'phone': phone,
        'email': email,
        'program': program,
        'department': department,
        'faculty': faculty,
        'relevantSkills': relevantSkills,
      },
      'feedback_rating': feedbackRating,
      'feedback_comment': feedbackComment,
    };
  }

  // For database insert (without id)
  Map<String, dynamic> toJsonForInsert() {
    return {
      'event_id': eventId,
      'user_id': userId,
      'registration_date': registrationDate.toIso8601String(),
      'attendance_status': attendanceStatus,
      'participant_data': {
        'fullName': fullName,
        'studentId': studentId,
        'phone': phone,
        'email': email,
        'program': program,
        'department': department,
        'faculty': faculty,
        'relevantSkills': relevantSkills,
      },
      'feedback_rating': feedbackRating,
      'feedback_comment': feedbackComment,
    };
  }

  EventRegistrationModel copyWith({
    String? id,
    String? eventId,
    String? userId,
    DateTime? registrationDate,
    String? attendanceStatus,
    String? fullName,
    String? studentId,
    String? phone,
    String? email,
    String? program,
    String? department,
    String? faculty,
    List<String>? relevantSkills,
    double? feedbackRating,
    String? feedbackComment,
  }) {
    return EventRegistrationModel(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      userId: userId ?? this.userId,
      registrationDate: registrationDate ?? this.registrationDate,
      attendanceStatus: attendanceStatus ?? this.attendanceStatus,
      fullName: fullName ?? this.fullName,
      studentId: studentId ?? this.studentId,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      program: program ?? this.program,
      department: department ?? this.department,
      faculty: faculty ?? this.faculty,
      relevantSkills: relevantSkills ?? this.relevantSkills,
      feedbackRating: feedbackRating ?? this.feedbackRating,
      feedbackComment: feedbackComment ?? this.feedbackComment,
    );
  }

  @override
  String toString() {
    return 'EventRegistrationModel(id: $id, eventId: $eventId, userId: $userId, fullName: $fullName, status: $attendanceStatus)';
  }
}
