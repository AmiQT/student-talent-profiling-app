class ExperienceModel {
  final String id;
  final String title;
  final String company;
  final String description;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isCurrentPosition;
  final String? location;
  final List<String> skills;

  ExperienceModel({
    required this.id,
    required this.title,
    required this.company,
    required this.description,
    required this.startDate,
    this.endDate,
    this.isCurrentPosition = false,
    this.location,
    this.skills = const [],
  });

  factory ExperienceModel.fromJson(Map<String, dynamic> json) {
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

    return ExperienceModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      company: json['company'] ?? '',
      description: json['description'] ?? '',
      startDate: parseDateTime(json['startDate']),
      endDate: json['endDate'] != null ? parseDateTime(json['endDate']) : null,
      isCurrentPosition: json['isCurrentPosition'] ?? false,
      location: json['location'],
      skills: List<String>.from(json['skills'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'company': company,
      'description': description,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'isCurrentPosition': isCurrentPosition,
      'location': location,
      'skills': skills,
    };
  }

  ExperienceModel copyWith({
    String? id,
    String? title,
    String? company,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    bool? isCurrentPosition,
    String? location,
    List<String>? skills,
  }) {
    return ExperienceModel(
      id: id ?? this.id,
      title: title ?? this.title,
      company: company ?? this.company,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isCurrentPosition: isCurrentPosition ?? this.isCurrentPosition,
      location: location ?? this.location,
      skills: skills ?? this.skills,
    );
  }
}
