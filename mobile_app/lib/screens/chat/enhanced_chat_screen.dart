import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// Removed OpenRouter service; Gemini-only
import '../../services/gemini_chat_service.dart';
import '../../services/fsktm_data_service.dart';
import '../../services/chat_history_service.dart';
import '../../services/supabase_auth_service.dart';
import '../../models/chat_models.dart';
import '../../widgets/chat/chat_message_bubble.dart';
import '../../widgets/chat/typing_indicator.dart';
import '../../widgets/chat/chat_input_field.dart';

class EnhancedChatScreen extends StatefulWidget {
  final String? conversationId;

  const EnhancedChatScreen({
    super.key,
    this.conversationId,
  });

  @override
  State<EnhancedChatScreen> createState() => _EnhancedChatScreenState();
}

class _EnhancedChatScreenState extends State<EnhancedChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  late GeminiChatService _geminiService;
  late ChatHistoryService _historyService;

  bool _isLoading = false;
  bool _isTyping = false;
  String? _currentConversationId;
  String? _errorMessage;
  List<File> _selectedFiles = [];

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    _historyService = ChatHistoryService();
    await _historyService.initialize();
    _geminiService = GeminiChatService(_historyService);

    try {
      setState(() => _isLoading = true);

      // Load conversation if provided
      if (widget.conversationId != null) {
        _currentConversationId = widget.conversationId;
        await _loadConversationMessages();
      } else {
        _currentConversationId = _generateConversationId();
      }

      setState(() => _isLoading = false);
      // debugPrint('EnhancedChatScreen: All services initialized successfully');
    } catch (e) {
      debugPrint('EnhancedChatScreen: Initialization error: $e');
      debugPrint('EnhancedChatScreen: Error type: ${e.runtimeType}');

      setState(() {
        _isLoading = false;
        _errorMessage = 'Initialization failed: ${e.toString()}';
      });

      if (e.toString().contains('API key')) {
        _showGeminiKeyDialog();
      }
    }
  }

  Future<void> _loadConversationMessages() async {
    // Load messages from local history
    final messages =
        await _historyService.getConversationMessages(_currentConversationId!);
    if (messages.isNotEmpty) {
      setState(() {
        _messages.clear();
        _messages.addAll(messages);
      });
      _scrollToBottom();
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isTyping) return;

    final authService =
        Provider.of<SupabaseAuthService>(context, listen: false);
    final userId = authService.currentUserId;

    if (userId == null) {
      _showError('Please log in to send messages');
      return;
    }

    // Create conversation if this is the first message
    if (_messages.isEmpty) {
      final conversationTitle =
          content.length > 50 ? '${content.substring(0, 50)}...' : content;

      final conversation = ChatConversation(
        id: _currentConversationId!,
        userId: userId,
        title: conversationTitle,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isActive: true,
        messageCount: 0,
      );

      await _historyService.saveConversation(conversation);
      // debugPrint('Created new conversation: ${conversation.id}');
    }

    // Clear input and show typing
    _messageController.clear();
    setState(() => _isTyping = true);

    // Add user message to UI immediately
    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      conversationId: _currentConversationId!,
      userId: userId,
      content: content,
      role: MessageRole.user,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
    });

    _scrollToBottom();

    try {
      // Create placeholder for streaming AI message
      final aiMessageId = 'ai_${DateTime.now().millisecondsSinceEpoch}';
      final streamingMessage = ChatMessage(
        id: aiMessageId,
        conversationId: _currentConversationId!,
        userId: 'stap_advisor',
        content: '',
        role: MessageRole.assistant,
        timestamp: DateTime.now(),
      );

      setState(() {
        _messages.add(streamingMessage);
      });

      // Intelligent routing: Multi-faculty RAG with clarification
      String? facultyContext;
      String? clarificationPrompt;

      if (FSKTMDataService.isUTHMFacultyQuery(content)) {
        final detectedFaculty =
            FSKTMDataService.detectFacultyFromQuery(content);
        debugPrint('RAG: Detected faculty = $detectedFaculty');

        switch (detectedFaculty) {
          case 'fsktm':
            // Clear FSKTM query
            facultyContext =
                await FSKTMDataService.getFSKTMContextForAIWithQuery(content);
            break;
          case 'fkaab':
            // Clear FKAAB query
            facultyContext =
                await FSKTMDataService.getFKAABContextForAI(content);
            break;
          case 'fkee':
            // Clear FKEE query
            facultyContext =
                await FSKTMDataService.getFKEEContextForAI(content);
            break;
          case 'unclear':
            // Need clarification - add prompt for AI to ask user
            clarificationPrompt = '''
PENTING: User bertanya tentang staff/pensyarah tanpa menyatakan fakulti yang spesifik.
UTHM mempunyai beberapa fakulti. Sila tanya user fakulti mana yang mereka maksudkan:
- FSKTM (Fakulti Sains Komputer dan Teknologi Maklumat) - 104 staff
- FKAAB (Fakulti Kejuruteraan Awam dan Alam Bina) - 181 staff
- FKEE (Fakulti Kejuruteraan Elektrik dan Elektronik) - 185 staff

Contoh respons: "Maaf, boleh saya tahu fakulti mana yang awak maksudkan? FSKTM, FKAAB, atau FKEE?"
''';
            break;
          default:
            // General UTHM query - provide FSKTM as default
            facultyContext =
                await FSKTMDataService.getFSKTMContextForAIWithQuery(content);
        }
      } else {
        // SMART FALLBACK: If query contains potential name (Capitalized words),
        // load FSKTM context anyway - might be asking about staff
        final hasProperName = RegExp(r'\b[A-Z][a-z]+\b').hasMatch(content) ||
            content.toLowerCase().split(' ').any((word) =>
                word.length >= 4 &&
                ![
                  'what',
                  'this',
                  'that',
                  'with',
                  'from',
                  'your',
                  'have',
                  'will',
                  'been',
                  'were',
                  'they',
                  'their',
                  'about',
                  'which',
                  'would',
                  'there',
                  'could',
                  'other',
                  'after',
                  'first',
                  'also',
                  'make',
                  'like',
                  'just',
                  'over',
                  'such',
                  'into',
                  'year',
                  'some',
                  'them',
                  'than',
                  'look',
                  'only',
                  'come',
                  'most',
                  'very',
                  'when',
                  'being',
                  'these',
                  'more',
                  'many',
                  'those',
                  'then',
                  'must',
                  'said',
                  'each',
                  'tell',
                  'good',
                  'know',
                  'want'
                ].contains(word));

        if (hasProperName) {
          debugPrint(
              'RAG: Smart fallback - loading FSKTM context for potential name query');
          facultyContext =
              await FSKTMDataService.getFSKTMContextForAIWithQuery(content);
        }
      }

      // Use streaming for real-time response
      // Combine faculty context with clarification prompt if needed
      final ragContext = clarificationPrompt ?? facultyContext;

      await for (final partialContent in _geminiService.sendMessageStreaming(
        conversationId: _currentConversationId!,
        content: content,
        userId: userId,
        attachments: _selectedFiles.isNotEmpty ? _selectedFiles : null,
        ragContext: ragContext,
      )) {
        // Update the streaming message with new content
        final index = _messages.indexWhere((m) => m.id == aiMessageId);
        if (index != -1) {
          setState(() {
            _messages[index] =
                _messages[index].copyWith(content: partialContent);
          });
          _scrollToBottom();
        }
      }

      setState(() {
        _isTyping = false;
        _selectedFiles.clear();
      });

      _scrollToBottom();
    } catch (e) {
      setState(() => _isTyping = false);

      if (e.toString().contains('API authentication failed') ||
          e.toString().contains('API key')) {
        _showGeminiKeyDialog();
      } else {
        _showError(e.toString());
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onFilesSelected(List<File> files) {
    setState(() {
      _selectedFiles = files;
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _showGeminiKeyDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Gemini API Key Required'),
        content: const Text(
          'There\'s an issue with the Gemini API key. Please check your configuration:\n\n'
          '1. Ensure your assets/.env file contains GEMINI_API_KEY=your-key\n'
          '   (or run with --dart-define=GEMINI_API_KEY=your-key)\n'
          '2. Verify the key is valid in Google AI Studio\n'
          '3. Restart the app after adding the key',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Exit chat screen
            },
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // Retry initialization
              await _initializeServices();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  String _generateConversationId() {
    return 'conv_${DateTime.now().millisecondsSinceEpoch}';
  }

  // OpenRouter API helpers removed (Gemini-only)

  void _openChatHistory() {
    Navigator.pushNamed(context, '/chat-history').then((_) {
      // Refresh if user selected a conversation
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('STAP UTHM Advisor'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Chat History',
            onPressed: _openChatHistory,
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showUsageInfo,
          ),
        ],
      ),
      body: Column(
        children: [
          // Usage warning banner
          // Removed UsageWarningBanner

          // Messages area
          Expanded(
            child: _buildMessagesArea(),
          ),

          // Typing indicator
          if (_isTyping)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: TypingIndicator(),
            ),

          // Input area
          ChatInputField(
            controller: _messageController,
            onSend: _sendMessage,
            enabled: !_isTyping && _errorMessage == null,
            onFilesSelected: _onFilesSelected,
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesArea() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Chat Unavailable',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initializeServices,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Start a Conversation',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ask me anything about your studies, career, or skills!',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        return ChatMessageBubble(
          message: _messages[index],
          isUser: _messages[index].role == MessageRole.user,
        );
      },
    );
  }

  void _showUsageInfo() async {
    // Usage monitoring removed with Firebase removal
    final Map<String, dynamic> report =
        {}; // Placeholder for future usage reporting
    final suggestions = List<String>.from(report['suggestions'] ?? const []);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('System Usage'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Today\'s Usage:',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text('Reads: 0 / 50,000 (0%)'),
              const Text('Writes: 0 / 20,000 (0%)'),
              const Text('Deletes: 0 / 20,000 (0%)'),
              if (suggestions.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Optimization Tips:',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...suggestions.map<Widget>(
                  (suggestion) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('- $suggestion',
                        style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
