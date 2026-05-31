import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'services/supabase_auth_service.dart';
import 'config/supabase_config.dart';
import 'services/profile_service.dart';
import 'services/achievement_service.dart';
import 'services/showcase_service.dart';
import 'services/search_service.dart';
import 'services/notification_service.dart';
import 'services/notification_preferences_service.dart';
import 'services/language_service.dart';
import 'utils/app_theme.dart';
// Removed debug config for production
import 'providers/theme_provider.dart';
import 'widgets/app_initializer.dart';
import 'screens/auth/login_screen.dart';
import 'screens/student/student_dashboard.dart';
import 'screens/auth/profile_setup_screen.dart';
import 'screens/chat/chat_history_screen.dart';

// Disable debug logging for cleaner testing
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  try {
    await dotenv.load(fileName: "assets/.env");
  } catch (e) {
    debugPrint('⚠️ Change to "assets/.env" or standard .env failed: $e');
    // Attempt fallback or ignore if using --dart-define
  }

  // Initialize Supabase
  try {
    await SupabaseConfig.initialize();
    debugPrint('✅ Supabase initialized successfully');
  } catch (e) {
    debugPrint('❌ Failed to initialize Supabase: $e');
    // Debug logging removed for production
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Simplified provider chain for better hot restart
        Provider<SupabaseAuthService>(
          create: (_) => SupabaseAuthService(),
        ),
        Provider<ProfileService>(
          create: (_) => ProfileService(),
        ),
        Provider<AchievementService>(
          create: (_) => AchievementService(),
        ),
        Provider<ShowcaseService>(
          create: (_) => ShowcaseService(),
        ),
        Provider<SearchService>(
          create: (_) => SearchService(),
        ),
        Provider<NotificationService>(
          create: (_) => NotificationService(),
        ),
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
        ),
        ChangeNotifierProvider<LanguageService>(
          create: (_) => LanguageService(),
        ),
        ChangeNotifierProvider<NotificationPreferencesService>(
          create: (_) => NotificationPreferencesService(),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            key: const ValueKey(
                'main_app'), // Add key for better state management
            title: 'Student Talent Profiling App',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.materialThemeMode,
            debugShowCheckedModeBanner: false,
            locale: const Locale('en'), // Fixed locale
            supportedLocales: const [Locale('en')], // Fixed supported locales
            home: const AppInitializer(),
            routes: {
              '/login': (context) => const LoginScreen(),
              '/dashboard': (context) => const StudentDashboard(),
              '/profile-setup': (context) => const ProfileSetupScreen(),
              '/chat-history': (context) => const ChatHistoryScreen(),
            },
            onUnknownRoute: (settings) {
              // Fallback for unknown routes
              debugPrint('Unknown route: ${settings.name}');
              return MaterialPageRoute(
                builder: (context) => const LoginScreen(),
              );
            },
          );
        },
      ),
    );
  }
}
