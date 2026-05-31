// import 'package:supabase_flutter/supabase_flutter.dart'; // Unused

class DirectConversation {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<DirectChatParticipant> participants;
  final DirectMessage? lastMessage;
  final int unreadCount;

  DirectConversation({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.participants = const [],
    this.lastMessage,
    this.unreadCount = 0,
  });

  factory DirectConversation.fromJson(Map<String, dynamic> json) {
    var participantsList = <DirectChatParticipant>[];
    if (json['conversation_participants'] != null) {
      participantsList = (json['conversation_participants'] as List)
          .map((e) => DirectChatParticipant.fromJson(e))
          .toList();
    }

    // Try to extract last message if available (usually from a join or separate query)
    DirectMessage? lastMsg;
    if (json['messages'] != null && (json['messages'] as List).isNotEmpty) {
      lastMsg = DirectMessage.fromJson((json['messages'] as List).first);
    }

    return DirectConversation(
      id: json['id'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      participants: participantsList,
      lastMessage: lastMsg,
      // unreadCount would typically come from a calculated field or separate query
      unreadCount: json['unread_count'] ?? 0,
    );
  }

  // Helper to get the "other" participant (not me)
  DirectChatParticipant? getOtherParticipant(String myUserId) {
    try {
      return participants.firstWhere((p) => p.userId != myUserId);
    } catch (_) {
      return null;
    }
  }
}

class DirectChatParticipant {
  final String id;
  final String conversationId;
  final String userId;
  final DateTime joinedAt;
  final DateTime lastReadAt;
  final Map<String, dynamic>? userProfile; // Joined profile data

  DirectChatParticipant({
    required this.id,
    required this.conversationId,
    required this.userId,
    required this.joinedAt,
    required this.lastReadAt,
    this.userProfile,
  });

  factory DirectChatParticipant.fromJson(Map<String, dynamic> json) {
    return DirectChatParticipant(
      id: json['id'],
      conversationId: json['conversation_id'],
      userId: json['user_id'],
      joinedAt: DateTime.parse(json['joined_at']),
      lastReadAt: DateTime.parse(json['last_read_at']),
      userProfile:
          json['user_profile'] ?? json['users'], // Handle both versions
    );
  }
}

class DirectMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final String type; // text, image, file
  final DateTime createdAt;
  final bool isDeleted;
  final bool isMine; // Helper for UI

  DirectMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.type,
    required this.createdAt,
    required this.isDeleted,
    this.isMine = false,
  });

  factory DirectMessage.fromJson(Map<String, dynamic> json,
      {String? myUserId}) {
    return DirectMessage(
      id: json['id'],
      conversationId: json['conversation_id'],
      senderId: json['sender_id'],
      content: json['content'],
      type: json['type'] ?? 'text',
      createdAt: DateTime.parse(json['created_at']),
      isDeleted: json['is_deleted'] ?? false,
      isMine: myUserId != null && json['sender_id'] == myUserId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'conversation_id': conversationId,
      'sender_id': senderId,
      'content': content,
      'type': type,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
