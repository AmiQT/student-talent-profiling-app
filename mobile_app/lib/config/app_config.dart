import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static Future<void> initialize() async {
    try {
      await dotenv.load(fileName: "assets/.env");
      if (kDebugMode) debugPrint('Environment variables loaded');
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading environment variables: $e');
    }
  }

  static String get backendUrl {
    return dotenv.env['BACKEND_URL']?.trim().isNotEmpty == true
        ? dotenv.env['BACKEND_URL']!.trim()
        : 'http://localhost:8000';
  }
}
