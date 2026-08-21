import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  static const productionBaseUrl =
      'https://anikoto-api-teramoto-danish.vercel.app';

  static String get baseUrl {
    const buildTimeUrl = String.fromEnvironment('API_BASE_URL');
    final configured = buildTimeUrl.trim().isNotEmpty
        ? buildTimeUrl.trim()
        : (dotenv.env['API_BASE_URL']?.trim().isNotEmpty == true
              ? dotenv.env['API_BASE_URL']!.trim()
              : productionBaseUrl);
    return configured.endsWith('/')
        ? configured.substring(0, configured.length - 1)
        : configured;
  }
}
