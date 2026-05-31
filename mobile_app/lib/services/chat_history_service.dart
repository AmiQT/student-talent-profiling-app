import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_models.dart';

/// Stores chat history locally to minimize database usage
class ChatHistoryService extends ChangeNotifier {
  static const String _conversationsKey = 'chat_conversations_local';
  static const String _messagesKeyPrefix = 'chat_messages_';
  static const String _lastSyncKey = 'chat_last_sync';
  static const int _maxConversations = 50;
  static const int _maxMessagesPerConversation = 200;

  List<ChatConversation> _conversations = [];
  final Map<String, List<ChatMessage>> _messagesCache = {};
  DateTime? _lastSync;

  List<ChatConversation> get conversations => List.unmodifiable(_conversations);
  DateTime? get lastSync => _lastSync;

  /// Initialize the service and load data
  Future<void> initialize() async {
    await _loadConversations();
    await _loadLastSync();
    // debugPrint(
    //     'ChatHistoryService: Initialized with ${_conversations.length} conversations');
  }

  /// Get conversations for a specific user
  List<ChatConversation> getUserConversations(String userId) {
    return _conversations
        .where((conv) => conv.userId == userId && conv.isActive)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  /// Get messages for a conversation
  Future<List<ChatMessage>> getConversationMessages(
      String conversationId) async {
    // Check cache first
    if (_messagesCache.containsKey(conversationId)) {
      return List.unmodifiable(_messagesCache[conversationId]!);
    }

    // Load from local storage
    final messages = await _loadMessages(conversationId);
    _messagesCache[conversationId] = messages;
    return List.unmodifiable(messages);
  }

  /// Save a new conversation
  Future<ChatConversation> saveConversation(
      ChatConversation conversation) async {
    // Add or update conversation
    final existingIndex =
        _conversations.indexWhere((c) => c.id == conversation.id);
    if (existingIndex >= 0) {
      _conversations[existingIndex] = conversation;
    } else {
      _conversations.insert(0, conversation);
    }

    // Limit conversations count
    if (_conversations.length > _maxConversations) {
      final removed = _conversations.removeLast();
      await _deleteConversationMessages(removed.id);
    }

    await _saveConversations();
    notifyListeners();
    return conversation;
  }

  /// Save a message to a conversation
  Future<void> saveMessage(ChatMessage message) async {
    // Initialize messages cache if needed
    if (!_messagesCache.containsKey(message.conversationId)) {
      _messagesCache[message.conversationId] =
          await _loadMessages(message.conversationId);
    }

    // Add message
    final messages = _messagesCache[message.conversationId]!;
    messages.add(message);

    // Limit messages per conversation
    if (messages.length > _maxMessagesPerConversation) {
      messages.removeAt(0); // Remove oldest message
    }

    // Save to local storage
    await _saveMessages(message.conversationId, messages);

    // Update conversation metadata
    await _updateConversationMetadata(message);

    notifyListeners();
  }

  /// Update conversation metadata after new message
  Future<void> _updateConversationMetadata(ChatMessage message) async {
    final conversationIndex =
        _conversations.indexWhere((c) => c.id == message.conversationId);
    if (conversationIndex >= 0) {
      final conversation = _conversations[conversationIndex];
      final updatedConversation = ChatConversation(
        id: conversation.id,
        userId: conversation.userId,
        title: conversation.title,
        createdAt: conversation.createdAt,
        updatedAt: DateTime.now(),
        isActive: conversation.isActive,
        messageCount: conversation.messageCount + 1,
        lastMessage: message.content.length > 100
            ? '${message.content.substring(0, 100)}...'
            : message.content,
        lastMessageAt: message.timestamp,
      );

      _conversations[conversationIndex] = updatedConversation;
      await _saveConversations();
    }
  }

  /// Search conversations by title or content
  List<ChatConversation> searchConversations(String userId, String query) {
    if (query.trim().isEmpty) {
      return getUserConversations(userId);
    }

    final lowerQuery = query.toLowerCase();
    return getUserConversations(userId)
        .where((conv) =>
            conv.title.toLowerCase().contains(lowerQuery) ||
            (conv.lastMessage?.toLowerCase().contains(lowerQuery) ?? false))
        .toList();
  }

  /// Delete a conversation and its messages
  Future<void> deleteConversation(String conversationId) async {
    _conversations.removeWhere((c) => c.id == conversationId);
    await _deleteConversationMessages(conversationId);
    await _saveConversations();
    notifyListeners();
  }

  /// Clear all chat history
  Future<void> clearAllHistory() async {
    _conversations.clear();
    _messagesCache.clear();

    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) =>
        key.startsWith(_messagesKeyPrefix) || key == _conversationsKey);

    for (final key in keys) {
      await prefs.remove(key);
    }

    notifyListeners();
    // debugPrint('ChatHistoryService: All history cleared');
  }

  /// Get storage usage statistics
  Future<Map<String, dynamic>> getStorageStats() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) =>
        key.startsWith(_messagesKeyPrefix) || key == _conversationsKey);

    int totalSize = 0;
    int messageCount = 0;

    for (final key in keys) {
      final data = prefs.getString(key);
      if (data != null) {
        totalSize += data.length;
        if (key.startsWith(_messagesKeyPrefix)) {
          try {
            final messages = jsonDecode(data) as List;
            messageCount += messages.length;
          } catch (e) {
            debugPrint('Error parsing messages for stats: $e');
          }
        }
      }
    }

    return {
      'conversations': _conversations.length,
      'totalMessages': messageCount,
      'storageSize': totalSize,
      'storageSizeKB': (totalSize / 1024).round(),
    };
  }

  /// Load conversations from local storage
  Future<void> _loadConversations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_conversationsKey);

      if (data != null) {
        final List<dynamic> jsonList = jsonDecode(data);
        _conversations =
            jsonList.map((json) => ChatConversation.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('ChatHistoryService: Error loading conversations: $e');
      _conversations = [];
    }
  }

  /// Save conversations to local storage
  Future<void> _saveConversations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _conversations.map((conv) => conv.toJson()).toList();
      await prefs.setString(_conversationsKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('ChatHistoryService: Error saving conversations: $e');
    }
  }

  /// Load messages for a conversation
  Future<List<ChatMessage>> _loadMessages(String conversationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('$_messagesKeyPrefix$conversationId');

      if (data != null) {
        final List<dynamic> jsonList = jsonDecode(data);
        return jsonList.map((json) => ChatMessage.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint(
          'ChatHistoryService: Error loading messages for $conversationId: $e');
    }
    return [];
  }

  /// Save messages for a conversation
  Future<void> _saveMessages(
      String conversationId, List<ChatMessage> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = messages.map((msg) => msg.toJson()).toList();
      await prefs.setString(
          '$_messagesKeyPrefix$conversationId', jsonEncode(jsonList));
    } catch (e) {
      debugPrint(
          'ChatHistoryService: Error saving messages for $conversationId: $e');
    }
  }

  /// Delete messages for a conversation
  Future<void> _deleteConversationMessages(String conversationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_messagesKeyPrefix$conversationId');
      _messagesCache.remove(conversationId);
    } catch (e) {
      debugPrint(
          'ChatHistoryService: Error deleting messages for $conversationId: $e');
    }
  }

  /// Load last sync timestamp
  Future<void> _loadLastSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_lastSyncKey);
      if (timestamp != null) {
        _lastSync = DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
    } catch (e) {
      debugPrint('ChatHistoryService: Error loading last sync: $e');
    }
  }

  /// Update last sync timestamp
  Future<void> updateLastSync() async {
    try {
      _lastSync = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastSyncKey, _lastSync!.millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('ChatHistoryService: Error updating last sync: $e');
    }
  }
}
