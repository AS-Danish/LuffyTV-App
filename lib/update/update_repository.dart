import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:luffytv/core/utils/api_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'update_manifest.dart';

class UpdateFetchResult {
  final UpdateManifest manifest;
  final bool fromCache;
  final bool networkUnavailable;
  const UpdateFetchResult(
    this.manifest, {
    required this.fromCache,
    this.networkUnavailable = false,
  });
}

class UpdateRepositoryException implements Exception {
  final Object cause;
  final bool timeout;
  final bool network;
  final bool invalidManifest;
  const UpdateRepositoryException(
    this.cause, {
    this.timeout = false,
    this.network = false,
    this.invalidManifest = false,
  });
  @override
  String toString() => cause.toString();
}

class UpdateRepository {
  static const _cacheKey = 'luffytv_update_manifest_v2';
  final http.Client _client;
  final Uri manifestUri;

  UpdateRepository({http.Client? client, Uri? manifestUri})
    : _client = client ?? http.Client(),
      manifestUri = manifestUri ?? _configuredManifestUri();

  static Uri _configuredManifestUri() {
    const override = String.fromEnvironment('UPDATE_MANIFEST_URL');
    return Uri.parse(
      override.trim().isNotEmpty
          ? override.trim()
          : '${ApiConstants.baseUrl}/api/app-version',
    );
  }

  Future<UpdateFetchResult> fetch({bool allowCached = true}) async {
    try {
      if (!_isAllowedManifestUri(manifestUri)) {
        throw const FormatException('The update manifest URL must use HTTPS.');
      }
      final response = await _client
          .get(
            manifestUri.replace(
              queryParameters: {
                ...manifestUri.queryParameters,
                '_': DateTime.now().millisecondsSinceEpoch.toString(),
              },
            ),
            headers: const {
              'Accept': 'application/json',
              'Cache-Control': 'no-cache',
            },
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Update manifest returned HTTP ${response.statusCode}.',
          uri: manifestUri,
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) throw const FormatException('Expected JSON object.');
      final envelope = Map<String, dynamic>.from(decoded);
      final raw = envelope['data'] is Map
          ? Map<String, dynamic>.from(envelope['data'] as Map)
          : envelope;
      final manifest = UpdateManifest.fromJson(raw);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(manifest.toJson()));
      return UpdateFetchResult(manifest, fromCache: false);
    } on TimeoutException catch (error) {
      if (allowCached) return _cachedOrThrow(error, timeout: true);
      throw UpdateRepositoryException(error, timeout: true);
    } on SocketException catch (error) {
      if (allowCached) return _cachedOrThrow(error, network: true);
      throw UpdateRepositoryException(error, network: true);
    } on FormatException catch (error) {
      if (allowCached) return _cachedOrThrow(error, invalidManifest: true);
      throw UpdateRepositoryException(error, invalidManifest: true);
    } catch (error) {
      if (allowCached) return _cachedOrThrow(error);
      throw UpdateRepositoryException(error);
    }
  }

  Future<UpdateFetchResult> _cachedOrThrow(
    Object cause, {
    bool timeout = false,
    bool network = false,
    bool invalidManifest = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached != null) {
        final decoded = jsonDecode(cached);
        if (decoded is Map) {
          return UpdateFetchResult(
            UpdateManifest.fromJson(Map<String, dynamic>.from(decoded)),
            fromCache: true,
            networkUnavailable: network,
          );
        }
      }
    } catch (_) {
      // Invalid cached state is ignored and replaced after a successful check.
    }
    throw UpdateRepositoryException(
      cause,
      timeout: timeout,
      network: network,
      invalidManifest: invalidManifest,
    );
  }

  static bool _isAllowedManifestUri(Uri uri) {
    if (uri.scheme == 'https' && uri.host.isNotEmpty) return true;
    if (!kReleaseMode && uri.scheme == 'http') {
      return const {'localhost', '127.0.0.1', '10.0.2.2'}.contains(uri.host);
    }
    return false;
  }

  void close() => _client.close();
}
