import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:luffytv/core/utils/api_constants.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppVersionDecision {
  final String installedVersion;
  final String latestVersion;
  final String minimumVersion;
  final String updateUrl;
  final String message;

  const AppVersionDecision({
    required this.installedVersion,
    required this.latestVersion,
    required this.minimumVersion,
    required this.updateUrl,
    required this.message,
  });

  bool get updateRequired =>
      AppVersionService.compare(installedVersion, minimumVersion) < 0;
  bool get updateAvailable =>
      AppVersionService.compare(installedVersion, latestVersion) < 0;

  Map<String, dynamic> toJson() => {
    'latestVersion': latestVersion,
    'minimumVersion': minimumVersion,
    'updateUrl': updateUrl,
    'message': message,
  };
}

class AppVersionService {
  static const _cachedPolicyKey = 'luffytv_version_policy_v1';

  static Future<AppVersionDecision?> check() async {
    final info = await PackageInfo.fromPlatform();
    Map<String, dynamic>? policy;
    try {
      final response = await http
          .get(Uri.parse('${ApiConstants.baseUrl}/api/app-version'))
          .timeout(const Duration(seconds: 6));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = jsonDecode(response.body);
        final raw = body is Map && body['data'] is Map
            ? body['data'] as Map
            : body as Map;
        policy = Map<String, dynamic>.from(raw);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_cachedPolicyKey, jsonEncode(policy));
      }
    } catch (_) {
      // A previously received policy is used below so airplane mode cannot
      // bypass a mandatory update. First-run network failures remain usable.
    }

    if (policy == null) {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cachedPolicyKey);
      if (cached == null) return null;
      policy = Map<String, dynamic>.from(jsonDecode(cached) as Map);
    }

    final minimum = (policy['minimumVersion'] ?? '').toString().trim();
    final latest = (policy['latestVersion'] ?? minimum).toString().trim();
    if (minimum.isEmpty || latest.isEmpty) return null;
    return AppVersionDecision(
      installedVersion: info.version,
      latestVersion: latest,
      minimumVersion: minimum,
      updateUrl: (policy['updateUrl'] ?? '').toString().trim(),
      message:
          (policy['message'] ??
                  'A newer Luffy TV release is required to keep streaming.')
              .toString(),
    );
  }

  static int compare(String left, String right) {
    List<int> parts(String value) => value
        .split('+')
        .first
        .split('-')
        .first
        .split('.')
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
    final a = parts(left);
    final b = parts(right);
    for (var index = 0; index < 3; index++) {
      final av = index < a.length ? a[index] : 0;
      final bv = index < b.length ? b[index] : 0;
      if (av != bv) return av.compareTo(bv);
    }
    return 0;
  }
}
