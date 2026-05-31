import 'dart:io';
import 'showcase_models.dart';

/// Model for tracking post creation progress
class PostCreationState {
  final String? content;
  final List<File> selectedMedia;
  final List<String> tags;
  final PostCategory category;
  final PostPrivacy privacy;
  final String? location;
  final bool isUploading;
  final double uploadProgress;
  final String? error;
  final List<String> mentionedUsers;

  PostCreationState({
    this.content,
    this.selectedMedia = const [],
    this.tags = const [],
    this.category = PostCategory.general,
    this.privacy = PostPrivacy.public,
    this.location,
    this.isUploading = false,
    this.uploadProgress = 0.0,
    this.error,
    this.mentionedUsers = const [],
  });

  PostCreationState copyWith({
    String? content,
    List<File>? selectedMedia,
    List<String>? tags,
    PostCategory? category,
    PostPrivacy? privacy,
    String? location,
    bool? isUploading,
    double? uploadProgress,
    String? error,
    List<String>? mentionedUsers,
  }) {
    return PostCreationState(
      content: content ?? this.content,
      selectedMedia: selectedMedia ?? this.selectedMedia,
      tags: tags ?? this.tags,
      category: category ?? this.category,
      privacy: privacy ?? this.privacy,
      location: location ?? this.location,
      isUploading: isUploading ?? this.isUploading,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      error: error ?? this.error,
      mentionedUsers: mentionedUsers ?? this.mentionedUsers,
    );
  }

  bool get hasContent => content != null && content!.trim().isNotEmpty;
  bool get hasMedia => selectedMedia.isNotEmpty;
  bool get hasTags => tags.isNotEmpty;
  bool get canPost => hasContent || hasMedia;
  bool get hasError => error != null;

  PostType get postType {
    if (hasMedia && hasContent) return PostType.mixed;
    if (hasMedia) {
      final hasImages = selectedMedia.any((file) => 
          file.path.toLowerCase().endsWith('.jpg') ||
          file.path.toLowerCase().endsWith('.jpeg') ||
          file.path.toLowerCase().endsWith('.png') ||
          file.path.toLowerCase().endsWith('.gif'));
      final hasVideos = selectedMedia.any((file) => 
          file.path.toLowerCase().endsWith('.mp4') ||
          file.path.toLowerCase().endsWith('.mov') ||
          file.path.toLowerCase().endsWith('.avi'));
      
      if (hasVideos) return PostType.video;
      if (hasImages) return PostType.image;
    }
    return PostType.text;
  }
}

/// Model for media upload progress
class MediaUploadProgress {
  final String mediaId;
  final String fileName;
  final double progress;
  final bool isCompleted;
  final bool hasError;
  final String? error;
  final String? downloadUrl;

  MediaUploadProgress({
    required this.mediaId,
    required this.fileName,
    this.progress = 0.0,
    this.isCompleted = false,
    this.hasError = false,
    this.error,
    this.downloadUrl,
  });

  MediaUploadProgress copyWith({
    String? mediaId,
    String? fileName,
    double? progress,
    bool? isCompleted,
    bool? hasError,
    String? error,
    String? downloadUrl,
  }) {
    return MediaUploadProgress(
      mediaId: mediaId ?? this.mediaId,
      fileName: fileName ?? this.fileName,
      progress: progress ?? this.progress,
      isCompleted: isCompleted ?? this.isCompleted,
      hasError: hasError ?? this.hasError,
      error: error ?? this.error,
      downloadUrl: downloadUrl ?? this.downloadUrl,
    );
  }
}

/// Model for draft posts
class PostDraft {
  final String id;
  final String content;
  final List<String> mediaPaths;
  final List<String> tags;
  final PostCategory category;
  final PostPrivacy privacy;
  final String? location;
  final DateTime createdAt;
  final DateTime updatedAt;

  PostDraft({
    required this.id,
    required this.content,
    this.mediaPaths = const [],
    this.tags = const [],
    this.category = PostCategory.general,
    this.privacy = PostPrivacy.public,
    this.location,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PostDraft.fromJson(Map<String, dynamic> json) {
    return PostDraft(
      id: json['id'] ?? '',
      content: json['content'] ?? '',
      mediaPaths: List<String>.from(json['mediaPaths'] ?? []),
      tags: List<String>.from(json['tags'] ?? []),
      category: PostCategory.values.firstWhere(
        (e) => e.toString().split('.').last == json['category'],
        orElse: () => PostCategory.general,
      ),
      privacy: PostPrivacy.values.firstWhere(
        (e) => e.toString().split('.').last == json['privacy'],
        orElse: () => PostPrivacy.public,
      ),
      location: json['location'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'mediaPaths': mediaPaths,
      'tags': tags,
      'category': category.toString().split('.').last,
      'privacy': privacy.toString().split('.').last,
      'location': location,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  PostDraft copyWith({
    String? id,
    String? content,
    List<String>? mediaPaths,
    List<String>? tags,
    PostCategory? category,
    PostPrivacy? privacy,
    String? location,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PostDraft(
      id: id ?? this.id,
      content: content ?? this.content,
      mediaPaths: mediaPaths ?? this.mediaPaths,
      tags: tags ?? this.tags,
      category: category ?? this.category,
      privacy: privacy ?? this.privacy,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Model for post creation result
class PostCreationResult {
  final bool success;
  final String? postId;
  final String? error;
  final ShowcasePostModel? post;

  PostCreationResult({
    required this.success,
    this.postId,
    this.error,
    this.post,
  });

  PostCreationResult.success({
    required this.postId,
    required this.post,
  }) : success = true, error = null;

  PostCreationResult.failure({
    required this.error,
  }) : success = false, postId = null, post = null;
}

/// Model for user mentions in post creation
class UserMention {
  final String userId;
  final String userName;
  final String? userProfileImage;
  final String? userRole;

  UserMention({
    required this.userId,
    required this.userName,
    this.userProfileImage,
    this.userRole,
  });

  factory UserMention.fromJson(Map<String, dynamic> json) {
    return UserMention(
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? '',
      userProfileImage: json['userProfileImage'],
      userRole: json['userRole'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'userProfileImage': userProfileImage,
      'userRole': userRole,
    };
  }
}

/// Model for post templates/suggestions
class PostTemplate {
  final String id;
  final String title;
  final String content;
  final PostCategory category;
  final List<String> suggestedTags;
  final String? description;

  PostTemplate({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    this.suggestedTags = const [],
    this.description,
  });

  static List<PostTemplate> getDefaultTemplates() {
    return [
      PostTemplate(
        id: 'project_showcase',
        title: 'Project Showcase',
        content: '🚀 Excited to share my latest project!\n\n[Project Description]\n\n💡 Key Features:\n• \n• \n• \n\n🛠️ Technologies Used:\n#flutter #firebase #dart',
        category: PostCategory.project,
        suggestedTags: ['project', 'coding', 'development'],
        description: 'Perfect for showcasing your coding projects',
      ),
      PostTemplate(
        id: 'achievement',
        title: 'Achievement',
        content: '🎉 Thrilled to announce that I\'ve [achievement]!\n\nThis journey has been [experience/learning].\n\nGrateful for [acknowledgments].\n\n#achievement #milestone #grateful',
        category: PostCategory.achievement,
        suggestedTags: ['achievement', 'milestone', 'success'],
        description: 'Share your accomplishments and milestones',
      ),
      PostTemplate(
        id: 'learning',
        title: 'Learning Journey',
        content: '📚 Currently learning [topic/skill]!\n\n🔍 What I\'ve discovered so far:\n• \n• \n• \n\nExcited to apply this knowledge in [application].\n\n#learning #growth #education',
        category: PostCategory.academic,
        suggestedTags: ['learning', 'education', 'growth'],
        description: 'Document your learning experiences',
      ),
      PostTemplate(
        id: 'creative',
        title: 'Creative Work',
        content: '🎨 Sharing some creative work I\'ve been working on!\n\n[Description of creative process/inspiration]\n\nWould love to hear your thoughts! 💭\n\n#creative #art #design',
        category: PostCategory.creative,
        suggestedTags: ['creative', 'art', 'design'],
        description: 'Showcase your artistic and creative talents',
      ),
    ];
  }
}
