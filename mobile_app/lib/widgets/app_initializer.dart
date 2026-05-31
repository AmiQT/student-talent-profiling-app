import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// import 'package:provider/provider.dart'; // Unused import removed
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import '../config/supabase_config.dart';
// import '../services/profile_service.dart'; // Unused import removed
import '../services/gemini_chat_service.dart';
import '../services/chat_history_service.dart';
import '../screens/splash_screen.dart';
// Removed debug config for production
import '../utils/profile_image_cleanup.dart';

/// Complete app initializer with all functionality
class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Initialize Supabase if not already done (debug mode)
      if (kDebugMode) {
        try {
          // Check if Supabase is already initialized
          Supabase.instance.client;
          debugPrint('Supabase already initialized');
        } catch (e) {
          debugPrint('Initializing Supabase in debug mode...');
          await SupabaseConfig.initialize();
          debugPrint('Supabase initialized successfully');
        }
      }

      // Initialize app configuration
      if (kDebugMode) {
        debugPrint('Starting background initialization...');
      }

      await AppConfig.initialize();

      if (kDebugMode) {
        debugPrint('App configuration initialized');
      }

      // Run cleanup operations in background (optional)
      if (kDebugMode) {
        debugPrint('Initializing Gemini chat service...');
      }

      // Initialize Gemini chat service - check if it has initialize method
      try {
        GeminiChatService(ChatHistoryService());
        // Only call initialize if the method exists
        if (kDebugMode) {
          debugPrint('Gemini chat service initialized successfully');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Gemini chat service initialization skipped: $e');
        }
      }

      // Run profile image cleanup in TRUE background (non-blocking)
      if (kDebugMode) {
        debugPrint('Running profile image cleanup...');
      }

      // Fire-and-forget cleanup - don't block UI with await
      ProfileImageCleanup.cleanupPlaceholderUrls().catchError((e) {
        if (kDebugMode) {
          debugPrint('Error during placeholder cleanup: $e');
        }
      });

      if (kDebugMode) {
        debugPrint('Background initialization completed');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error during background initialization: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Always show splash screen immediately for fast hot restart
    // Initialization happens in background
    return const SplashScreen();
  }
}
