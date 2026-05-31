class ProjectModel {
  final String id;
  final String title;
  final String description;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isOngoing;
  final String? projectUrl;
  final String? githubUrl;
  final List<String> technologies;
  final List<String> images;
  final String? category;

  ProjectModel({
    required this.id,
    required this.title,
    required this.description,
    required this.startDate,
    this.endDate,
    this.isOngoing = false,
    this.projectUrl,
    this.githubUrl,
    this.technologies = const [],
    this.images = const [],
    this.category,
  });

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
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

    return ProjectModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      startDate: parseDateTime(json['startDate']),
      endDate: json['endDate'] != null ? parseDateTime(json['endDate']) : null,
      isOngoing: json['isOngoing'] ?? false,
      projectUrl: json['projectUrl'],
      githubUrl: json['githubUrl'],
      technologies: List<String>.from(json['technologies'] ?? []),
      images: List<String>.from(json['images'] ?? []),
      category: json['category'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'isOngoing': isOngoing,
      'projectUrl': projectUrl,
      'githubUrl': githubUrl,
      'technologies': technologies,
      'images': images,
      'category': category,
    };
  }

  ProjectModel copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    bool? isOngoing,
    String? projectUrl,
    String? githubUrl,
    List<String>? technologies,
    List<String>? images,
    String? category,
  }) {
    return ProjectModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isOngoing: isOngoing ?? this.isOngoing,
      projectUrl: projectUrl ?? this.projectUrl,
      githubUrl: githubUrl ?? this.githubUrl,
      technologies: technologies ?? this.technologies,
      images: images ?? this.images,
      category: category ?? this.category,
    );
  }
}
