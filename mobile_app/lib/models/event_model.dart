// Firebase import removed - migrating to Supabase
// import 'package:cloud_firestore/cloud_firestore.dart';

class EventModel {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String category;
  final List<String> favoriteUserIds;
  final String registerUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Registration fields
  final DateTime? eventDate;
  final String? location;
  final String? venue;
  final int? maxParticipants;
  final int? currentParticipants;
  final DateTime? registrationDeadline;
  final bool? registrationOpen;
  final List<String>? requirements;
  final List<String>? skillsGained;
  final List<String>? targetAudience;

  // Payment fields
  final double? price;
  final bool isPaid;

  EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.category,
    required this.favoriteUserIds,
    required this.registerUrl,
    required this.createdAt,
    required this.updatedAt,
    this.eventDate,
    this.location,
    this.venue,
    this.maxParticipants,
    this.currentParticipants,
    this.registrationDeadline,
    this.registrationOpen,
    this.requirements,
    this.skillsGained,
    this.targetAudience,
    this.price,
    this.isPaid = false,
  });

  // Helper methods for registration
  bool get canRegister {
    if (registrationOpen == false) return false;
    if (registrationDeadline != null &&
        DateTime.now().isAfter(registrationDeadline!)) {
      return false;
    }
    if (maxParticipants != null &&
        currentParticipants != null &&
        currentParticipants! >= maxParticipants!) {
      return false;
    }
    return true;
  }

  int get spotsLeft {
    if (maxParticipants == null || currentParticipants == null) return -1;
    return maxParticipants! - currentParticipants!;
  }

  String get registrationStatus {
    if (registrationOpen == false) return 'Registration Closed';
    if (registrationDeadline != null &&
        DateTime.now().isAfter(registrationDeadline!)) {
      return 'Registration Deadline Passed';
    }
    if (maxParticipants != null &&
        currentParticipants != null &&
        currentParticipants! >= maxParticipants!) {
      return 'Event Full';
    }
    return 'Registration Open';
  }

  factory EventModel.fromJson(Map<String, dynamic> json, {String? documentId}) {
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          return null;
        }
      }
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      return null;
    }

    return EventModel(
      id: documentId ?? json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['imageUrl'] ?? json['image_url'] ?? '',
      category: json['category'] ?? '',
      favoriteUserIds: List<String>.from(json['favoriteUserIds'] ?? []),
      registerUrl: json['registerUrl'] ?? json['register_url'] ?? '',
      createdAt: json['createdAt'] is String
          ? DateTime.parse(json['createdAt'])
          : (json['created_at'] is String
              ? DateTime.parse(json['created_at'])
              : DateTime.fromMillisecondsSinceEpoch(
                  json['createdAt'] ?? json['created_at'] ?? 0)),
      updatedAt: json['updatedAt'] is String
          ? DateTime.parse(json['updatedAt'])
          : (json['updated_at'] is String
              ? DateTime.parse(json['updated_at'])
              : DateTime.fromMillisecondsSinceEpoch(
                  json['updatedAt'] ?? json['updated_at'] ?? 0)),
      // Registration fields
      eventDate: parseDateTime(json['eventDate'] ?? json['event_date']),
      location: json['location'],
      venue: json['venue'],
      maxParticipants: json['maxParticipants'] ?? json['max_participants'],
      currentParticipants:
          json['currentParticipants'] ?? json['current_participants'],
      registrationDeadline: parseDateTime(
          json['registrationDeadline'] ?? json['registration_deadline']),
      registrationOpen: json['registrationOpen'] ?? json['registration_open'],
      requirements: json['requirements'] != null
          ? List<String>.from(json['requirements'])
          : null,
      skillsGained: json['skillsGained'] != null
          ? List<String>.from(json['skillsGained'])
          : (json['skills_gained'] != null
              ? List<String>.from(json['skills_gained'])
              : null),
      targetAudience: json['targetAudience'] != null
          ? List<String>.from(json['targetAudience'])
          : (json['target_audience'] != null
              ? List<String>.from(json['target_audience'])
              : null),
      price: json['price'] != null
          ? (json['price'] is int
              ? (json['price'] as int).toDouble()
              : json['price'])
          : null,
      isPaid: json['isPaid'] ?? json['is_paid'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'category': category,
      'favoriteUserIds': favoriteUserIds,
      'registerUrl': registerUrl,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      // Registration fields
      'eventDate': eventDate?.toIso8601String(),
      'location': location,
      'venue': venue,
      'maxParticipants': maxParticipants,
      'currentParticipants': currentParticipants,
      'registrationDeadline': registrationDeadline?.toIso8601String(),
      'registrationOpen': registrationOpen,
      'requirements': requirements,
      'skillsGained': skillsGained,
      'targetAudience': targetAudience,
      'price': price,
      'isPaid': isPaid,
    };
  }

  EventModel copyWith({
    String? id,
    String? title,
    String? description,
    String? imageUrl,
    String? category,
    List<String>? favoriteUserIds,
    String? registerUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? eventDate,
    String? location,
    String? venue,
    int? maxParticipants,
    int? currentParticipants,
    DateTime? registrationDeadline,
    bool? registrationOpen,
    List<String>? requirements,
    List<String>? skillsGained,
    List<String>? targetAudience,
    double? price,
    bool? isPaid,
  }) {
    return EventModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      favoriteUserIds: favoriteUserIds ?? this.favoriteUserIds,
      registerUrl: registerUrl ?? this.registerUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      eventDate: eventDate ?? this.eventDate,
      location: location ?? this.location,
      venue: venue ?? this.venue,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      currentParticipants: currentParticipants ?? this.currentParticipants,
      registrationDeadline: registrationDeadline ?? this.registrationDeadline,
      registrationOpen: registrationOpen ?? this.registrationOpen,
      requirements: requirements ?? this.requirements,
      skillsGained: skillsGained ?? this.skillsGained,
      targetAudience: targetAudience ?? this.targetAudience,
      price: price ?? this.price,
      isPaid: isPaid ?? this.isPaid,
    );
  }
}
