import 'package:flutter_dotenv/flutter_dotenv.dart';

class ToyyibPayConfig {
  // Base URLs
  static const String sandboxUrl = 'https://dev.toyyibpay.com';
  static const String productionUrl = 'https://toyyibpay.com';

  // Current Environment (Switch to productionUrl for real payments)
  static const String baseUrl = sandboxUrl;

  // API Keys
  // Retrieved from .env file
  static String get userSecretKey =>
      dotenv.env['TOYYIBPAY_USER_SECRET_KEY'] ?? '';
  static String get categoryCode => dotenv.env['TOYYIBPAY_CATEGORY_CODE'] ?? '';

  // API Endpoints
  static const String createBill = '$baseUrl/index.php/api/createBill';
  static const String getBillTransactions =
      '$baseUrl/index.php/api/getBillTransactions';
}
