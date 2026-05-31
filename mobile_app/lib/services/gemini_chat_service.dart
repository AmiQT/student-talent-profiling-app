import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/chat_models.dart';
import '../config/app_config.dart';
import '../config/supabase_config.dart';
import 'chat_history_service.dart';

/// Gemini Chat Service - Now uses Backend Proxy
/// All AI calls go through backend which handles Gemini API securely
/// Enhanced with FSKTM knowledge base integration (RAG via backend)
/// Supports v2 (LangChain) and v3 (Hybrid) endpoints
class GeminiChatService extends ChangeNotifier {
  // API Version: 'v2' for LangChain, 'v3' for Hybrid (smart routing)
  static const String _apiVersion = 'v3'; // Use hybrid by default

  // Backend AI endpoint - no more direct Gemini calls!
  static String get _backendAiUrl =>
      '${AppConfig.backendUrl}/api/ai/$_apiVersion/command';

  final ChatHistoryService _historyService;
  bool _isTyping = false;

  // RAG Response Cache - untuk soalan lazim
  static final Map<String, _CachedResponse> _responseCache = {};
  static const int _maxCacheSize = 50;
  static const Duration _cacheExpiry = Duration(hours: 24);

  GeminiChatService(this._historyService);

  bool get isTyping => _isTyping;

  /// Backend handles API key - always available if backend is up
  bool get hasApiKey => true;

  /// Get Supabase auth token for backend authentication
  String? get _authToken {
    return SupabaseConfig.auth.currentSession?.accessToken;
  }

  /// Send message with optional file attachments and RAG context
  /// Now routes through backend for secure API key handling
  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String content,
    required String userId,
    List<File>? attachments,
    String? ragContext,
  }) async {
    _isTyping = true;
    notifyListeners();

    try {
      // Create user message
      final userMessage = ChatMessage(
        id: _generateMessageId(),
        conversationId: conversationId,
        userId: userId,
        content: content,
        role: MessageRole.user,
        timestamp: DateTime.now(),
      );

      // Save user message to local history
      await _historyService.saveMessage(userMessage);

      // Check cache for similar FSKTM queries
      if (ragContext != null) {
        final cachedResponse = _getCachedResponse(content);
        if (cachedResponse != null) {
          debugPrint(
              'RAG Cache HIT for query: ${content.substring(0, content.length.clamp(0, 50))}...');
          final aiMessage = ChatMessage(
            id: _generateMessageId(),
            conversationId: conversationId,
            userId: 'stap_advisor',
            content: cachedResponse,
            role: MessageRole.assistant,
            timestamp: DateTime.now(),
            tokens: _calculateTokens(cachedResponse),
          );
          await _historyService.saveMessage(aiMessage);
          return aiMessage;
        }
      }

      // Build backend request with RAG context INJECTED into command
      // This ensures Gemini receives faculty/staff data even though backend doesn't parse rag_context separately
      String commandWithContext = content;
      if (ragContext != null && ragContext.isNotEmpty) {
        commandWithContext = '''
[KONTEKS FAKULTI UTHM - Gunakan data ini untuk menjawab soalan]
$ragContext
[TAMAT KONTEKS]

Soalan user: $content''';
      }

      final requestBody = {
        'command': commandWithContext,
        'session_id': conversationId,
        'context': {
          'user_id': userId,
        },
      };

      // Get auth token
      final authToken = _authToken;
      if (authToken == null) {
        throw Exception('User not authenticated');
      }

      // Send to Backend AI endpoint (which calls Gemini securely)
      final response = await http.post(
        Uri.parse(_backendAiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        throw Exception(
            'Backend AI error: ${response.statusCode} - ${response.body}');
      }

      final responseData = jsonDecode(response.body);
      final aiContent = responseData['message'] ?? 'Maaf, tiada respons.';

      // Log routing info for v3 hybrid endpoint
      if (_apiVersion == 'v3') {
        final modeUsed = responseData['mode_used'] ?? 'unknown';
        final confidence = responseData['confidence'] ?? 0.0;
        debugPrint('🔀 Hybrid AI: mode=$modeUsed, confidence=$confidence');
      }

      // Cache response for FSKTM queries
      if (ragContext != null) {
        _cacheResponse(content, aiContent);
      }

      // Create AI message
      final aiMessage = ChatMessage(
        id: _generateMessageId(),
        conversationId: conversationId,
        userId: 'stap_advisor',
        content: aiContent,
        role: MessageRole.assistant,
        timestamp: DateTime.now(),
        tokens: _calculateTokens(aiContent),
      );

      // Save AI message to local history
      await _historyService.saveMessage(aiMessage);

      return aiMessage;
    } finally {
      _isTyping = false;
      notifyListeners();
    }
  }

  /// Send message with STREAMING response - word by word output
  /// Now routes through backend, simulates streaming from full response
  Stream<String> sendMessageStreaming({
    required String conversationId,
    required String content,
    required String userId,
    List<File>? attachments,
    String? ragContext,
  }) async* {
    _isTyping = true;
    notifyListeners();

    try {
      // Create and save user message
      final userMessage = ChatMessage(
        id: _generateMessageId(),
        conversationId: conversationId,
        userId: userId,
        content: content,
        role: MessageRole.user,
        timestamp: DateTime.now(),
      );
      await _historyService.saveMessage(userMessage);

      // Check cache for similar FSKTM queries
      if (ragContext != null) {
        final cachedResponse = _getCachedResponse(content);
        if (cachedResponse != null) {
          debugPrint(
              'RAG Cache HIT (streaming): ${content.substring(0, content.length.clamp(0, 50))}...');

          // Simulate streaming for cached response
          yield* _simulateStreaming(cachedResponse);

          // Save to history
          final aiMessage = ChatMessage(
            id: _generateMessageId(),
            conversationId: conversationId,
            userId: 'stap_advisor',
            content: cachedResponse,
            role: MessageRole.assistant,
            timestamp: DateTime.now(),
            tokens: _calculateTokens(cachedResponse),
          );
          await _historyService.saveMessage(aiMessage);
          return;
        }
      }

      // Build backend request
      // Build backend request with RAG context INJECTED into command
      String commandWithContext = content;
      if (ragContext != null && ragContext.isNotEmpty) {
        commandWithContext = '''
[KONTEKS FAKULTI UTHM - Gunakan data ini untuk menjawab soalan]
$ragContext
[TAMAT KONTEKS]

Soalan user: $content''';
      }

      final requestBody = {
        'command': commandWithContext,
        'session_id': conversationId,
        'context': {
          'user_id': userId,
        },
      };

      // Get auth token
      final authToken = _authToken;
      if (authToken == null) {
        throw Exception('User not authenticated');
      }

      // Send to Backend AI endpoint
      final response = await http.post(
        Uri.parse(_backendAiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        throw Exception(
            'Backend AI error: ${response.statusCode} - ${response.body}');
      }

      final responseData = jsonDecode(response.body);
      final fullContent = responseData['message'] ?? 'Maaf, tiada respons.';

      // Cache response for FSKTM queries
      if (ragContext != null && fullContent.isNotEmpty) {
        _cacheResponse(content, fullContent);
      }

      // Simulate streaming by yielding words progressively
      yield* _simulateStreaming(fullContent);

      // Save final AI message
      final aiMessage = ChatMessage(
        id: _generateMessageId(),
        conversationId: conversationId,
        userId: 'stap_advisor',
        content: fullContent,
        role: MessageRole.assistant,
        timestamp: DateTime.now(),
        tokens: _calculateTokens(fullContent),
      );
      await _historyService.saveMessage(aiMessage);
    } finally {
      _isTyping = false;
      notifyListeners();
    }
  }

  /// Simulate streaming by yielding words progressively
  Stream<String> _simulateStreaming(String content) async* {
    final words = content.split(' ');
    final buffer = StringBuffer();
    for (final word in words) {
      buffer.write('$word ');
      yield buffer.toString();
      await Future.delayed(const Duration(milliseconds: 25));
    }
  }

  // NOTE: _extractTextFromStreamChunk removed - no longer used with backend proxy
  // NOTE: _buildGeminiRequest removed - no longer used with backend proxy
  // NOTE: _extractContentFromResponse removed - no longer used with backend proxy
  // NOTE: _processFileAttachment removed - no longer used with backend proxy
  // NOTE: _buildSystemPrompt removed - no longer used with backend proxy

  /// Calculate approximate token count
  int _calculateTokens(String text) {
    // Rough estimation: 1 token ≈ 4 characters
    return (text.length / 4).round();
  }

  /// Generate unique message ID
  String _generateMessageId() {
    return 'msg_${DateTime.now().millisecondsSinceEpoch}';
  }

  // NOTE: _createConversationSummary removed - no longer used with backend proxy

  // ============== RAG CACHE METHODS ==============

  /// Get cached response for similar queries
  String? _getCachedResponse(String query) {
    final normalizedQuery = _normalizeQuery(query);
    final cached = _responseCache[normalizedQuery];

    if (cached != null && !cached.isExpired) {
      return cached.response;
    }

    // Remove expired entry
    if (cached != null) {
      _responseCache.remove(normalizedQuery);
    }

    return null;
  }

  /// Cache response for future similar queries
  void _cacheResponse(String query, String response) {
    // Limit cache size
    if (_responseCache.length >= _maxCacheSize) {
      // Remove oldest entries
      final sortedKeys = _responseCache.keys.toList()
        ..sort((a, b) => _responseCache[a]!
            .timestamp
            .compareTo(_responseCache[b]!.timestamp));

      for (int i = 0; i < 10; i++) {
        _responseCache.remove(sortedKeys[i]);
      }
    }

    final normalizedQuery = _normalizeQuery(query);
    _responseCache[normalizedQuery] = _CachedResponse(
      response: response,
      timestamp: DateTime.now(),
    );
  }

  /// Normalize query for cache key
  String _normalizeQuery(String query) {
    return query
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Clear RAG response cache
  static void clearCache() {
    _responseCache.clear();
  }
}

/// Cached response model for RAG
class _CachedResponse {
  final String response;
  final DateTime timestamp;

  _CachedResponse({
    required this.response,
    required this.timestamp,
  });

  bool get isExpired =>
      DateTime.now().difference(timestamp) > GeminiChatService._cacheExpiry;
}
