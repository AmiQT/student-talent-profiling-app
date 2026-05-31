// Supabase chat models

/// Optimized chat message model for Supabase
class ChatMessage {
  final String id;
  final String conversationId;
  final String userId;
  final String content;
  final MessageRole role;
  final DateTime timestamp;
  final MessageStatus status;
  final int? tokens; // Track token usage for cost monitoring
  final Map<String, dynamic>? metadata;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.userId,
    required this.content,
    required this.role,
    required this.timestamp,
    this.status = MessageStatus.sent,
    this.tokens,
    this.metadata,
  });

  // Factory for Supabase - minimal data transfer
  factory ChatMessage.fromSupabase(Map<String, dynamic> data) {
    return ChatMessage(
      id: data['id'] ?? '',
      conversationId: data['conversationId'] ?? '',
      userId: data['userId'] ?? '',
      content: data['content'] ?? '',
      role: MessageRole.values.firstWhere(
        (role) => role.toString().split('.').last == data['role'],
        orElse: () => MessageRole.user,
      ),
      timestamp: data['timestamp'] != null
          ? DateTime.parse(data['timestamp'])
          : DateTime.now(),
      status: MessageStatus.values.firstWhere(
        (status) =>
            status.toString().split('.').last == (data['status'] ?? 'sent'),
        orElse: () => MessageStatus.sent,
      ),
      tokens: data['tokens'],
      metadata: data['metadata'],
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? '',
      conversationId: json['conversationId'] ?? '',
      userId: json['userId'] ?? '',
      content: json['content'] ?? '',
      role: MessageRole.values.firstWhere(
        (e) => e.toString().split('.').last == json['role'],
        orElse: () => MessageRole.user,
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] ?? 0),
      status: MessageStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => MessageStatus.sent,
      ),
      tokens: json['tokens'],
      metadata: json['metadata'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'userId': userId,
      'content': content,
      'role': role.toString().split('.').last,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'status': status.toString().split('.').last,
      if (tokens != null) 'tokens': tokens,
      if (metadata != null) 'metadata': metadata,
    };
  }

  // Optimized toMap - only essential fields to minimize writes
  Map<String, dynamic> toSupabase() {
    return {
      'conversationId': conversationId,
      'userId': userId,
      'content': content.length > 1000
          ? content.substring(0, 1000)
          : content, // Limit content size
      'role': role.toString().split('.').last,
      'timestamp': DateTime.now().toIso8601String(),
      'status': status.toString().split('.').last,
      if (tokens != null) 'tokens': tokens,
      if (metadata != null && metadata!.isNotEmpty) 'metadata': metadata,
    };
  }

  ChatMessage copyWith({
    String? id,
    String? conversationId,
    String? userId,
    String? content,
    MessageRole? role,
    DateTime? timestamp,
    MessageStatus? status,
    int? tokens,
    Map<String, dynamic>? metadata,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      role: role ?? this.role,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      tokens: tokens ?? this.tokens,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Chat conversation model optimized for minimal storage
class ChatConversation {
  final String id;
  final String userId;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final int messageCount;
  final String? lastMessage;
  final DateTime? lastMessageAt;

  ChatConversation({
    required this.id,
    required this.userId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.messageCount = 0,
    this.lastMessage,
    this.lastMessageAt,
  });

  factory ChatConversation.fromSupabase(Map<String, dynamic> data) {
    return ChatConversation(
      id: data['id'] ?? '',
      userId: data['userId'] ?? '',
      title: data['title'] ?? 'New Conversation',
      createdAt: data['createdAt'] != null
          ? DateTime.parse(data['createdAt'])
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? DateTime.parse(data['updatedAt'])
          : DateTime.now(),
      isActive: data['isActive'] ?? true,
      messageCount: data['messageCount'] ?? 0,
      lastMessage: data['lastMessage'],
      lastMessageAt: data['lastMessageAt'] != null
          ? DateTime.parse(data['lastMessageAt'])
          : null,
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'userId': userId,
      'title': title,
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
      'isActive': isActive,
      'messageCount': messageCount,
      if (lastMessage != null)
        'lastMessage': lastMessage!.length > 100
            ? lastMessage!.substring(0, 100)
            : lastMessage,
      if (lastMessageAt != null)
        'lastMessageAt': lastMessageAt!.toIso8601String(),
    };
  }

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      title: json['title'] ?? 'New Conversation',
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] ?? 0),
      isActive: json['isActive'] ?? true,
      messageCount: json['messageCount'] ?? 0,
      lastMessage: json['lastMessage'],
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['lastMessageAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'isActive': isActive,
      'messageCount': messageCount,
      if (lastMessage != null) 'lastMessage': lastMessage,
      if (lastMessageAt != null)
        'lastMessageAt': lastMessageAt!.millisecondsSinceEpoch,
    };
  }

  ChatConversation copyWith({
    String? id,
    String? userId,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    int? messageCount,
    String? lastMessage,
    DateTime? lastMessageAt,
  }) {
    return ChatConversation(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      messageCount: messageCount ?? this.messageCount,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
    );
  }
}

/// User context for personalized AI responses - cached locally
class ChatUserContext {
  final String userId;
  final String fullName;
  final String? program;
  final String? department;
  final List<String> skills;
  final List<String> interests;
  final String? academicLevel;
  final int achievementCount;
  final DateTime lastUpdated;

  ChatUserContext({
    required this.userId,
    required this.fullName,
    this.program,
    this.department,
    this.skills = const [],
    this.interests = const [],
    this.academicLevel,
    this.achievementCount = 0,
    required this.lastUpdated,
  });

  // Generate context string for AI prompt
  String toContextString() {
    final buffer = StringBuffer();
    buffer.writeln('User: $fullName');
    if (program != null) buffer.writeln('Program: $program');
    if (department != null) buffer.writeln('Department: $department');
    if (academicLevel != null) buffer.writeln('Level: $academicLevel');
    if (skills.isNotEmpty) {
      buffer.writeln('Skills: ${skills.take(5).join(', ')}');
    }
    if (interests.isNotEmpty) {
      buffer.writeln('Interests: ${interests.take(5).join(', ')}');
    }
    if (achievementCount > 0) {
      buffer.writeln('Achievements: $achievementCount');
    }
    return buffer.toString();
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'fullName': fullName,
      'program': program,
      'department': department,
      'skills': skills,
      'interests': interests,
      'academicLevel': academicLevel,
      'achievementCount': achievementCount,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory ChatUserContext.fromJson(Map<String, dynamic> json) {
    return ChatUserContext(
      userId: json['userId'] ?? '',
      fullName: json['fullName'] ?? '',
      program: json['program'],
      department: json['department'],
      skills: List<String>.from(json['skills'] ?? []),
      interests: List<String>.from(json['interests'] ?? []),
      academicLevel: json['academicLevel'],
      achievementCount: json['achievementCount'] ?? 0,
      lastUpdated: DateTime.parse(
          json['lastUpdated'] ?? DateTime.now().toIso8601String()),
    );
  }
}

// Firebase usage tracking removed - not needed with Supabase

/// Enums
enum MessageRole { user, assistant, system }

enum MessageStatus { sending, sent, delivered, failed }

/// Chat configuration for optimization
class ChatConfig {
  static const int maxMessagesPerConversation = 50;
  static const int maxMessageLength = 1000;
  static const int maxConversationsPerUser = 10;
  static const Duration cacheExpiration = Duration(hours: 2);
  static const Duration contextCacheExpiration = Duration(hours: 6);
  static const int batchSize = 10;

  // API Configuration
  static const String defaultModel = 'qwen/qwen-2.5-coder-32b-instruct:free';
  static const int maxTokens = 1000;
  static const double temperature = 0.7;
  static const Duration apiTimeout = Duration(seconds: 30);
}
