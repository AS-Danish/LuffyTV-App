import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  // Pulls the URL securely from your .env file
  static String get baseUrl => dotenv.env['API_BASE_URL'] ?? 'https://anikoto-api-teramoto-danish.vercel.app';
}
