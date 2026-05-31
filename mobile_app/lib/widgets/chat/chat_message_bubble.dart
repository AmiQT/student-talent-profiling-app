import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../models/chat_models.dart';
import '../../utils/app_theme.dart';
import 'rich_text_message.dart';

class ChatMessageBubble extends StatefulWidget {
  final ChatMessage message;
  final bool isUser;
  final VoidCallback? onTtsStart;
  final VoidCallback? onTtsStop;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.isUser,
    this.onTtsStart,
    this.onTtsStop,
  });

  @override
  State<ChatMessageBubble> createState() => _ChatMessageBubbleState();
}

class _ChatMessageBubbleState extends State<ChatMessageBubble> {
  static FlutterTts? _flutterTts;
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    _flutterTts ??= FlutterTts();
    
    await _flutterTts!.setLanguage('ms-MY'); // Default to Malay
    await _flutterTts!.setSpeechRate(0.5);
    await _flutterTts!.setVolume(1.0);
    await _flutterTts!.setPitch(1.0);
    
    _flutterTts!.setCompletionHandler(() {
      if (mounted) {
        setState(() => _isSpeaking = false);
        widget.onTtsStop?.call();
      }
    });
    
    _flutterTts!.setCancelHandler(() {
      if (mounted) {
        setState(() => _isSpeaking = false);
        widget.onTtsStop?.call();
      }
    });
    
    _flutterTts!.setErrorHandler((msg) {
      if (mounted) {
        setState(() => _isSpeaking = false);
        widget.onTtsStop?.call();
      }
    });
  }

  Future<void> _speak() async {
    if (_isSpeaking) {
      await _flutterTts!.stop();
      setState(() => _isSpeaking = false);
      widget.onTtsStop?.call();
    } else {
      // Detect language and set accordingly
      final content = widget.message.content;
      final isMalay = _containsMalay(content);
      await _flutterTts!.setLanguage(isMalay ? 'ms-MY' : 'en-US');
      
      setState(() => _isSpeaking = true);
      widget.onTtsStart?.call();
      await _flutterTts!.speak(content);
    }
  }

  bool _containsMalay(String text) {
    final malayWords = ['saya', 'anda', 'adalah', 'untuk', 'dengan', 'yang', 
                        'ini', 'itu', 'boleh', 'tidak', 'akan', 'telah',
                        'fakulti', 'pensyarah', 'jabatan', 'program', 'universiti'];
    final lowerText = text.toLowerCase();
    return malayWords.any((word) => lowerText.contains(word));
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.message.content));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Copied to clipboard'),
          ],
        ),
        backgroundColor: AppTheme.successColor,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    if (_isSpeaking) {
      _flutterTts?.stop();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment:
            widget.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.isUser) _buildAvatar(),
          if (!widget.isUser) const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: widget.isUser 
                  ? CrossAxisAlignment.end 
                  : CrossAxisAlignment.start,
              children: [
                _buildMessageBubble(context),
                // Action buttons for AI messages
                if (!widget.isUser && widget.message.content.isNotEmpty)
                  _buildActionButtons(context),
              ],
            ),
          ),
          if (widget.isUser) const SizedBox(width: 8),
          if (widget.isUser) _buildAvatar(),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: widget.isUser ? AppTheme.primaryColor : AppTheme.secondaryColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        widget.isUser ? Icons.person : Icons.smart_toy_rounded,
        color: AppTheme.primaryColor,
        size: 18,
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Copy button
          _ActionButton(
            icon: Icons.copy_rounded,
            tooltip: 'Copy',
            onTap: _copyToClipboard,
          ),
          const SizedBox(width: 4),
          // TTS button
          _ActionButton(
            icon: _isSpeaking ? Icons.stop_rounded : Icons.volume_up_rounded,
            tooltip: _isSpeaking ? 'Stop' : 'Read aloud',
            onTap: _speak,
            isActive: _isSpeaking,
          ),
          const SizedBox(width: 4),
          // More options
          _ActionButton(
            icon: Icons.more_horiz,
            tooltip: 'More options',
            onTap: () => _showMessageOptions(context),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _showMessageOptions(context),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: widget.isUser
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(widget.isUser ? 18 : 4),
            bottomRight: Radius.circular(widget.isUser ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color:
                  Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichTextMessage(
              content: widget.message.content,
              isUser: widget.isUser,
              baseStyle: TextStyle(
                color: widget.isUser
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 16,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(widget.message.timestamp),
                  style: TextStyle(
                    color: widget.isUser
                        ? Theme.of(context)
                            .colorScheme
                            .onPrimary
                            .withValues(alpha: 0.7)
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                if (widget.message.tokens != null) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.token,
                    size: 12,
                    color: widget.isUser
                        ? Theme.of(context)
                            .colorScheme
                            .onPrimary
                            .withValues(alpha: 0.7)
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${widget.message.tokens}',
                    style: TextStyle(
                      color: widget.isUser
                          ? Theme.of(context)
                              .colorScheme
                              .onPrimary
                              .withValues(alpha: 0.7)
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                ],
                if (widget.isUser) ...[
                  const SizedBox(width: 8),
                  _buildStatusIcon(),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    IconData icon;
    Color color;

    switch (widget.message.status) {
      case MessageStatus.sending:
        icon = Icons.access_time;
        color = AppTheme.primaryColor.withValues(alpha: 0.7);
        break;
      case MessageStatus.sent:
        icon = Icons.check;
        color = AppTheme.primaryColor.withValues(alpha: 0.7);
        break;
      case MessageStatus.delivered:
        icon = Icons.done_all;
        color = AppTheme.primaryColor.withValues(alpha: 0.7);
        break;
      case MessageStatus.failed:
        icon = Icons.error_outline;
        color = AppTheme.errorColor;
        break;
    }

    return Icon(
      icon,
      size: 14,
      color: color,
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }

  void _showMessageOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy Message'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: widget.message.content));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Message copied to clipboard')),
                );
              },
            ),
            if (!widget.isUser) ...[
              ListTile(
                leading: Icon(_isSpeaking ? Icons.stop : Icons.volume_up),
                title: Text(_isSpeaking ? 'Stop Reading' : 'Read Aloud'),
                onTap: () {
                  Navigator.pop(context);
                  _speak();
                },
              ),
              ListTile(
                leading: const Icon(Icons.thumb_up_outlined),
                title: const Text('Good Response'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Thank you for your positive feedback!'),
                      backgroundColor: AppTheme.successColor,
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.thumb_down_outlined),
                title: const Text('Poor Response'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('Thank you for your feedback! We will improve.'),
                      backgroundColor: AppTheme.warningColor,
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Small action button for message actions
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isActive;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isActive 
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              icon,
              size: 18,
              color: isActive
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }
}
