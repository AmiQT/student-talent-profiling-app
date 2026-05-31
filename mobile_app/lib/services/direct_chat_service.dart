import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/direct_chat_models.dart';

class DirectChatService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Fetch all conversations for current user
  Future<List<DirectConversation>> getConversations() async {
    final myUserId = _supabase.auth.currentUser?.id;
    if (myUserId == null) return [];

    try {
      // 1. Get conversation IDs where I am a participant
      final myParticipations = await _supabase
          .from('conversation_participants')
          .select('conversation_id')
          .eq('user_id', myUserId);

      if ((myParticipations as List).isEmpty) {
        return [];
      }

      final conversationIds = (myParticipations as List)
          .map((e) => e['conversation_id'] as String)
          .toList();

      if (conversationIds.isEmpty) return [];

      // 2. Fetch each conversation individually (simpler, more reliable)
      List<DirectConversation> conversations = [];

      for (String convoId in conversationIds) {
        try {
          // Get conversation
          final convoData = await _supabase
              .from('conversations')
              .select()
              .eq('id', convoId)
              .single();

          // Get participants
          final participantsData = await _supabase
              .from('conversation_participants')
              .select()
              .eq('conversation_id', convoId);

          // Get messages (latest only)
          final messagesData = await _supabase
              .from('messages')
              .select()
              .eq('conversation_id', convoId)
              .order('created_at', ascending: false)
              .limit(1);

          // Fetch profile info for each participant
          List<Map<String, dynamic>> participants = [];
          for (var p in (participantsData as List)) {
            final participantUserId = p['user_id'];
            Map<String, dynamic> participantData = Map<String, dynamic>.from(p);

            try {
              final profileResponse = await _supabase
                  .from('profiles')
                  .select('full_name, profile_image_url')
                  .eq('user_id', participantUserId)
                  .limit(1);

              if ((profileResponse as List).isNotEmpty) {
                final profileData = profileResponse.first;
                participantData['user_profile'] = {
                  'name': profileData['full_name'] ?? 'Unknown',
                };
              } else {
                participantData['user_profile'] = {'name': 'Unknown'};
              }
            } catch (_) {
              participantData['user_profile'] = {'name': 'Unknown'};
            }

            participants.add(participantData);
          }

          // Build full conversation data
          Map<String, dynamic> fullConvo = Map<String, dynamic>.from(convoData);
          fullConvo['conversation_participants'] = participants;
          fullConvo['messages'] = messagesData;

          conversations.add(DirectConversation.fromJson(fullConvo));
        } catch (e) {
          // Skip this conversation if there's an error
          continue;
        }
      }

      // Sort by updated_at descending
      conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      return conversations;
    } catch (e) {
      return [];
    }
  }

  // Get messages for a conversation
  Future<List<DirectMessage>> getMessages(String conversationId) async {
    final myUserId = _supabase.auth.currentUser?.id;
    try {
      final response = await _supabase
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);

      return (response as List)
          .map((e) => DirectMessage.fromJson(e, myUserId: myUserId))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Send a message
  Future<void> sendMessage(String conversationId, String content,
      {String type = 'text'}) async {
    final myUserId = _supabase.auth.currentUser?.id;
    if (myUserId == null) return;

    try {
      await _supabase.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': myUserId,
        'content': content,
        'type': type,
      });

      // Update conversation updated_at for sorting
      await _supabase.from('conversations').update({
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', conversationId);
    } catch (e) {
      rethrow;
    }
  }

  // Delete a message
  Future<void> deleteMessage(String messageId) async {
    try {
      await _supabase.from('messages').delete().eq('id', messageId);
    } catch (e) {
      rethrow;
    }
  }

  // Delete a conversation (and all its participants and messages)
  Future<void> deleteConversation(String conversationId) async {
    try {
      // 1. Delete messages first (FK constraint)
      await _supabase
          .from('messages')
          .delete()
          .eq('conversation_id', conversationId);

      // 2. Delete participants
      await _supabase
          .from('conversation_participants')
          .delete()
          .eq('conversation_id', conversationId);

      // 3. Delete conversation
      await _supabase.from('conversations').delete().eq('id', conversationId);
    } catch (e) {
      rethrow;
    }
  }

  // Start or get existing conversation with a user
  Future<String> startDirectChat(String targetUserId) async {
    final myUserId = _supabase.auth.currentUser?.id;
    if (myUserId == null) throw Exception('Not authenticated');

    // Check if conversation already exists between these 2 users
    final myConvos = await getConversations();

    for (var convo in myConvos) {
      if (convo.participants.length == 2) {
        final hasTarget =
            convo.participants.any((p) => p.userId == targetUserId);
        if (hasTarget) {
          return convo.id;
        }
      }
    }

    // If not found, create new
    final convoRes =
        await _supabase.from('conversations').insert({}).select().single();
    final newConvoId = convoRes['id'];

    // Add participants
    await _supabase.from('conversation_participants').insert([
      {'conversation_id': newConvoId, 'user_id': myUserId},
      {'conversation_id': newConvoId, 'user_id': targetUserId},
    ]);

    return newConvoId;
  }

  // Mark conversation as read
  Future<void> markAsRead(String conversationId) async {
    final myUserId = _supabase.auth.currentUser?.id;
    if (myUserId == null) return;

    try {
      await _supabase
          .from('conversation_participants')
          .update({'last_read_at': DateTime.now().toIso8601String()})
          .eq('conversation_id', conversationId)
          .eq('user_id', myUserId);
    } catch (_) {
      // Fail silently, not critical
    }
  }

  // Realtime subscription
  Stream<List<DirectMessage>> subscribeToMessages(String conversationId) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at')
        .map((maps) => maps
            .map((e) => DirectMessage.fromJson(e,
                myUserId: _supabase.auth.currentUser?.id))
            .toList());
  }

  RealtimeChannel? _conversationsChannel;

  void listenToConversationUpdates(Function onUpdate) {
    if (_conversationsChannel != null) return;

    _conversationsChannel = _supabase.channel('public:conversation_list');

    _conversationsChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (payload) => onUpdate(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversation_participants',
          callback: (payload) => onUpdate(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          callback: (payload) => onUpdate(),
        )
        .subscribe();
  }

  void stopListeningToConversationUpdates() {
    if (_conversationsChannel != null) {
      _supabase.removeChannel(_conversationsChannel!);
      _conversationsChannel = null;
    }
  }
}
