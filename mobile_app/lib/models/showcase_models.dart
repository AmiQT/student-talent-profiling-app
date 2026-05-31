// Supabase showcase models
// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
// Removed debug config for production

/// Enum for different types of showcase posts
enum PostType {
  text,
  image,
  video,
  mixed, // Text + media combination
}

/// Enum for post privacy settings
enum PostPrivacy {
  public, // Visible to everyone
  department, // Visible to same department only
  friends, // Visible to connections only
}

/// Enum for post categories
enum PostCategory {
  academic,
  creative,
  technical,
  sports,
  volunteer,
  achievement,
  project,
  general,
}

/// Model for media content (images/videos)
class MediaModel {
  final String id;
  final String url;
  final String type; // 'image' or 'video'
  final String? thumbnailUrl; // For videos
  final int? duration; // For videos in seconds
  final double? aspectRatio;
  final int? fileSize; // In bytes
  final DateTime uploadedAt;

  MediaModel({
    required this.id,
    required this.url,
    required this.type,
    this.thumbnailUrl,
    this.duration,
    this.aspectRatio,
    this.fileSize,
    required this.uploadedAt,
  });

  factory MediaModel.fromJson(Map<String, dynamic> json) {
    return MediaModel(
      id: json['id'] ?? '',
      url: json['url'] ?? '',
      type: json['type'] ?? 'image',
      thumbnailUrl: json['thumbnailUrl'],
      duration: json['duration'],
      aspectRatio: json['aspectRatio']?.toDouble(),
      fileSize: json['fileSize'],
      uploadedAt: json['uploadedAt'] is String
          ? DateTime.parse(json['uploadedAt'])
          : DateTime.fromMillisecondsSinceEpoch(json['uploadedAt'] ?? 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'type': type,
      'thumbnailUrl': thumbnailUrl,
      'duration': duration,
      'aspectRatio': aspectRatio,
      'fileSize': fileSize,
      'uploadedAt': uploadedAt.toIso8601String(),
    };
  }
}

/// Model for user mentions in posts/comments
class MentionModel {
  final String userId;
  final String userName;
  final int startIndex;
  final int endIndex;

  MentionModel({
    required this.userId,
    required this.userName,
    required this.startIndex,
    required this.endIndex,
  });

  factory MentionModel.fromJson(Map<String, dynamic> json) {
    return MentionModel(
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? '',
      startIndex: json['startIndex'] ?? 0,
      endIndex: json['endIndex'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'startIndex': startIndex,
      'endIndex': endIndex,
    };
  }
}

/// Model for comments on posts
class CommentModel {
  final String id;
  final String postId;
  final String userId;
  final String userName;
  final String? userProfileImage;
  final String content;
  final List<String> likes;
  final List<MentionModel> mentions;
  final String? parentCommentId; // For threaded replies
  final List<CommentModel> replies;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isEdited;

  CommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    required this.userName,
    this.userProfileImage,
    required this.content,
    this.likes = const [],
    this.mentions = const [],
    this.parentCommentId,
    this.replies = const [],
    required this.createdAt,
    required this.updatedAt,
    this.isEdited = false,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    // Support both camelCase and snake_case keys (for legacy/alt sources)
    String getString(dynamic a, dynamic b, [String fallback = '']) {
      final v = a ?? b;
      return v is String ? v : fallback;
    }

    dynamic pickValue(dynamic a, dynamic b) => a ?? b;

    // Parse dates from either camelCase or snake_case
    DateTime parseDate(dynamic a, dynamic b) {
      final v = a ?? b;
      if (v == null) return DateTime.now();
      if (v is String) {
        try {
          return DateTime.parse(v);
        } catch (_) {
          return DateTime.now();
        }
      }
      if (v is int) {
        return DateTime.fromMillisecondsSinceEpoch(v);
      }
      return DateTime.now();
    }

    return CommentModel(
      id: getString(json['id'], json['comment_id']),
      postId: getString(json['postId'], json['post_id']),
      userId: getString(json['userId'], json['user_id']),
      userName: getString(json['userName'], json['user_name'], 'User'),
      userProfileImage:
          pickValue(json['userProfileImage'], json['user_profile_image'])
              as String?,
      content: getString(json['content'], json['text']),
      likes: List<String>.from(
          pickValue(json['likes'], json['likes'] ?? []) ?? []),
      mentions: (json['mentions'] as List?)
              ?.map((m) => MentionModel.fromJson(Map<String, dynamic>.from(m)))
              .toList() ??
          [],
      parentCommentId:
          getString(json['parentCommentId'], json['parent_comment_id'], '')
                  .isEmpty
              ? null
              : getString(json['parentCommentId'], json['parent_comment_id']),
      replies: (json['replies'] as List?)
              ?.map((r) => CommentModel.fromJson(Map<String, dynamic>.from(r)))
              .toList() ??
          [],
      createdAt: parseDate(json['createdAt'], json['created_at']),
      updatedAt: parseDate(json['updatedAt'], json['updated_at']),
      isEdited: (json['isEdited'] ?? json['is_edited']) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'postId': postId,
      'userId': userId,
      'userName': userName,
      'userProfileImage': userProfileImage,
      'content': content,
      'likes': likes,
      'mentions': mentions.map((m) => m.toJson()).toList(),
      'parentCommentId': parentCommentId,
      'replies': replies.map((r) => r.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isEdited': isEdited,
    };
  }

  CommentModel copyWith({
    String? id,
    String? postId,
    String? userId,
    String? userName,
    String? userProfileImage,
    String? content,
    List<String>? likes,
    List<MentionModel>? mentions,
    String? parentCommentId,
    List<CommentModel>? replies,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isEdited,
  }) {
    return CommentModel(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userProfileImage: userProfileImage ?? this.userProfileImage,
      content: content ?? this.content,
      likes: likes ?? this.likes,
      mentions: mentions ?? this.mentions,
      parentCommentId: parentCommentId ?? this.parentCommentId,
      replies: replies ?? this.replies,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isEdited: isEdited ?? this.isEdited,
    );
  }

  // Helper methods
  bool get hasReplies => replies.isNotEmpty;
  int get likesCount => likes.length;
  bool isLikedBy(String userId) => likes.contains(userId);
  bool isOwnedBy(String userId) => this.userId == userId;

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 7) {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

/// Main model for showcase posts
class ShowcasePostModel {
  final String id;
  final String userId;
  final String userName;
  final String? userProfileImage;
  final String? userRole; // 'student' or 'lecturer'
  final String? userDepartment;
  final String? userHeadline;

  // Post content
  final String title;
  final String content;
  final PostType type;
  final PostCategory category;
  final PostPrivacy privacy;
  final List<MediaModel> media;
  final List<String> tags;
  final List<MentionModel> mentions;

  // Engagement
  final List<String> likes;
  final Map<String, int>
      reactions; // LinkedIn-style reactions: {like: 5, love: 2, celebrate: 1}
  final List<CommentModel> comments;
  final List<String> shares;
  final int viewCount;

  // Metadata
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isEdited;
  final bool isPinned;
  final bool isArchived;
  final String? location;

  ShowcasePostModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.userProfileImage,
    this.userRole,
    this.userDepartment,
    this.userHeadline,
    this.title = '',
    required this.content,
    required this.type,
    this.category = PostCategory.general,
    this.privacy = PostPrivacy.public,
    this.media = const [],
    this.tags = const [],
    this.mentions = const [],
    this.likes = const [],
    this.reactions = const {},
    this.comments = const [],
    this.shares = const [],
    this.viewCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.isEdited = false,
    this.isPinned = false,
    this.isArchived = false,
    this.location,
  });

  // Helper method to parse media from different database formats
  static List<MediaModel> _parseMediaFromJson(Map<String, dynamic> json) {
    // First try the new 'media' format (array of MediaModel objects)
    if (json['media'] is List && (json['media'] as List).isNotEmpty) {
      return (json['media'] as List)
          .map((m) => MediaModel.fromJson(m))
          .toList();
    }

    // Fallback to legacy format with separate arrays
    final mediaUrls = json['media_urls'] as List? ?? [];
    final mediaTypes = json['media_types'] as List? ?? [];

    if (mediaUrls.isEmpty) return [];

    // Create MediaModel objects from URL and type arrays
    final List<MediaModel> mediaList = [];
    for (int i = 0; i < mediaUrls.length; i++) {
      final url = mediaUrls[i]?.toString() ?? '';
      final type = i < mediaTypes.length
          ? (mediaTypes[i]?.toString() ?? 'image')
          : 'image';

      if (url.isNotEmpty) {
        mediaList.add(MediaModel(
          id: 'media_$i',
          url: url,
          type: type,
          uploadedAt: DateTime.now(),
        ));
      }
    }

    return mediaList;
  }

  // Helper methods for parsing enum values
  static PostType _parsePostType(dynamic value) {
    if (value is PostType) return value;
    if (value is String) {
      return PostType.values.firstWhere(
        (e) => e.toString().split('.').last == value,
        orElse: () => PostType.text,
      );
    }
    return PostType.text;
  }

  static PostCategory _parsePostCategory(dynamic value) {
    if (value is PostCategory) return value;
    if (value is String) {
      return PostCategory.values.firstWhere(
        (e) => e.toString().split('.').last == value,
        orElse: () => PostCategory.general,
      );
    }
    return PostCategory.general;
  }

  static PostPrivacy _parsePostPrivacy(dynamic value) {
    if (value is PostPrivacy) return value;
    if (value is String) {
      if (value == 'true' || value == 'false') {
        return value == 'true' ? PostPrivacy.public : PostPrivacy.department;
      }
      return PostPrivacy.values.firstWhere(
        (e) => e.toString().split('.').last == value,
        orElse: () => PostPrivacy.public,
      );
    }
    if (value is bool) {
      return value ? PostPrivacy.public : PostPrivacy.department;
    }
    return PostPrivacy.public;
  }

  static List<MentionModel> _parseMentions(dynamic value) {
    if (value is List) {
      return value.map((m) => MentionModel.fromJson(m)).toList();
    }
    return [];
  }

  static List<CommentModel> _parseComments(dynamic value) {
    if (value is List) {
      return value.map((c) => CommentModel.fromJson(c)).toList();
    }
    return [];
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return DateTime.now();
      }
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return DateTime.now();
  }

  factory ShowcasePostModel.fromJson(Map<String, dynamic> json) {
    // Handle Supabase nested user data (if available)
    final users = json['users'] as Map<String, dynamic>?;
    final profiles = json['profiles'] as Map<String, dynamic>?;
    final userName = users?['name'] ??
        profiles?['full_name'] ??
        json['user_name'] ??
        json['userName'] ??
        'User';
    final userProfileImage = profiles?['profile_image_url'] ??
        json['user_profile_image'] ??
        json['userProfileImage'];

    // Debug logging for profile image
    if (kDebugMode) {
      // Debug logging removed for production
    }

    // Parse reactions from JSONB
    Map<String, int> reactions = {};
    if (json['reactions'] != null) {
      if (json['reactions'] is Map) {
        reactions = Map<String, int>.from(json['reactions']);
      }
    }

    // Parse likes from relation (post_likes) or array (likes)
    List<String> parsedLikes = [];
    if (json['post_likes'] != null && json['post_likes'] is List) {
      // Relational format: [{'user_id': '...'}]
      parsedLikes = (json['post_likes'] as List)
          .map((l) => l['user_id'].toString())
          .toList();
    } else if (json['likes'] != null) {
      // Legacy/Array format
      parsedLikes = List<String>.from(json['likes']);
    }

    // Parse comments from relation (post_comments) or array (comments)
    List<CommentModel> parsedComments = [];
    if (json['post_comments'] != null && json['post_comments'] is List) {
      // Relational format
      parsedComments = (json['post_comments'] as List)
          .map((c) => CommentModel.fromJson(Map<String, dynamic>.from(c)))
          .toList();
    } else if (json['comments'] != null) {
      parsedComments = _parseComments(json['comments']);
    }

    return ShowcasePostModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? json['userId'] ?? '',
      userName: userName,
      userProfileImage: userProfileImage,
      userRole: json['user_role'] ?? json['userRole'],
      userDepartment: json['user_department'] ?? json['userDepartment'],
      userHeadline: json['user_headline'] ?? json['userHeadline'],
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      type: _parsePostType(json['type'] ?? 'text'),
      category: _parsePostCategory(json['category'] ?? 'general'),
      privacy:
          _parsePostPrivacy(json['is_public'] ?? json['privacy'] ?? 'public'),
      media: _parseMediaFromJson(json),
      tags: List<String>.from(json['tags'] ?? []),
      mentions: _parseMentions(json['mentions'] ?? []),
      likes: parsedLikes,
      reactions: reactions,
      comments: parsedComments,
      shares: List<String>.from(json['shares'] ?? []),
      viewCount: json['views_count'] ?? json['viewCount'] ?? 0,
      createdAt: _parseDateTime(json['created_at'] ?? json['createdAt']),
      updatedAt: _parseDateTime(json['updated_at'] ?? json['updatedAt']),
      isEdited: json['is_edited'] ?? json['isEdited'] ?? false,
      isPinned: json['is_pinned'] ?? json['isPinned'] ?? false,
      isArchived: json['is_archived'] ?? json['isArchived'] ?? false,
      location: json['location'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userProfileImage': userProfileImage,
      'userRole': userRole,
      'userDepartment': userDepartment,
      'userHeadline': userHeadline,
      'title': title,
      'content': content,
      'type': type.toString().split('.').last,
      'category': category.toString().split('.').last,
      'privacy': privacy.toString().split('.').last,
      'media': media.map((m) => m.toJson()).toList(),
      'tags': tags,
      'mentions': mentions.map((m) => m.toJson()).toList(),
      'likes': likes,
      'reactions': reactions,
      'comments': comments.map((c) => c.toJson()).toList(),
      'shares': shares,
      'viewCount': viewCount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isEdited': isEdited,
      'isPinned': isPinned,
      'isArchived': isArchived,
      'location': location,
    };
  }

  ShowcasePostModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userProfileImage,
    String? userRole,
    String? userDepartment,
    String? userHeadline,
    String? title,
    String? content,
    PostType? type,
    PostCategory? category,
    PostPrivacy? privacy,
    List<MediaModel>? media,
    List<String>? tags,
    List<MentionModel>? mentions,
    List<String>? likes,
    Map<String, int>? reactions,
    List<CommentModel>? comments,
    List<String>? shares,
    int? viewCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isEdited,
    bool? isPinned,
    bool? isArchived,
    String? location,
  }) {
    return ShowcasePostModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userProfileImage: userProfileImage ?? this.userProfileImage,
      userRole: userRole ?? this.userRole,
      userDepartment: userDepartment ?? this.userDepartment,
      userHeadline: userHeadline ?? this.userHeadline,
      title: title ?? this.title,
      content: content ?? this.content,
      type: type ?? this.type,
      category: category ?? this.category,
      privacy: privacy ?? this.privacy,
      media: media ?? this.media,
      tags: tags ?? this.tags,
      mentions: mentions ?? this.mentions,
      likes: likes ?? this.likes,
      reactions: reactions ?? this.reactions,
      comments: comments ?? this.comments,
      shares: shares ?? this.shares,
      viewCount: viewCount ?? this.viewCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isEdited: isEdited ?? this.isEdited,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      location: location ?? this.location,
    );
  }

  // Helper methods
  int get likesCount => likes.length;
  int get commentsCount => comments.length;
  int get sharesCount => shares.length;

  // Engagement methods
  int get totalReactions =>
      reactions.values.fold(0, (sum, count) => sum + count);

  bool isLikedBy(String userId) => likes.contains(userId);
  bool isSharedBy(String userId) => shares.contains(userId);
  bool isOwnedBy(String userId) => this.userId == userId;

  bool get hasMedia => media.isNotEmpty;
  bool get hasImages => media.any((m) => m.type == 'image');
  bool get hasVideos => media.any((m) => m.type == 'video');
  bool get hasTags => tags.isNotEmpty;
  bool get hasMentions => mentions.isNotEmpty;

  // Backward compatibility getter for mediaUrls
  List<String> get mediaUrls => media.map((m) => m.url).toList();

  // Backward compatibility getter for userProfileImageUrl
  String? get userProfileImageUrl => userProfileImage;

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 7) {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  String get categoryDisplayName {
    switch (category) {
      case PostCategory.academic:
        return 'Academic';
      case PostCategory.creative:
        return 'Creative';
      case PostCategory.technical:
        return 'Technical';
      case PostCategory.sports:
        return 'Sports';
      case PostCategory.volunteer:
        return 'Volunteer';
      case PostCategory.achievement:
        return 'Achievement';
      case PostCategory.project:
        return 'Project';
      case PostCategory.general:
        return 'General';
    }
  }
}
