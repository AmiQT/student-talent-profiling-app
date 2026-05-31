import 'package:flutter/material.dart';
import 'enhanced_chat_screen.dart';

/// Legacy ChatScreen - redirects to EnhancedChatScreen
/// This maintains backward compatibility while using the new optimized implementation
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EnhancedChatScreen();
  }
}
