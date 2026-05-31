import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  // Supabase configuration — read from assets/.env (see assets/.env.example).
  // Falls back to --dart-define values for release/CI builds.
  static String get supabaseUrl =>
      (dotenv.env['SUPABASE_URL']?.trim().isNotEmpty ?? false)
          ? dotenv.env['SUPABASE_URL']!.trim()
          : const String.fromEnvironment('SUPABASE_URL');

  static String get supabaseAnonKey =>
      (dotenv.env['SUPABASE_ANON_KEY']?.trim().isNotEmpty ?? false)
          ? dotenv.env['SUPABASE_ANON_KEY']!.trim()
          : const String.fromEnvironment('SUPABASE_ANON_KEY');

  static Future<void> initialize() async {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
        debug: kDebugMode,
      );

      if (kDebugMode) {
        // debugPrint('Supabase initialized successfully');
        // debugPrint('Supabase URL: $supabaseUrl');
        // debugPrint('Supabase Anon Key: ${supabaseAnonKey.substring(0, 20)}...');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to initialize Supabase: $e');
      }
      rethrow;
    }
  }

  static SupabaseClient get client {
    return Supabase.instance.client;
  }

  // Helper getters for common operations
  static GoTrueClient get auth => client.auth;
  static SupabaseQueryBuilder from(String table) => client.from(table);
  static SupabaseStorageClient get storage => client.storage;
}
