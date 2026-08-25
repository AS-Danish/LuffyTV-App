import 'dart:io';

import 'package:crypto/crypto.dart';

import 'update_manifest.dart';

enum VerificationFailure { missing, sizeMismatch, checksumMismatch }

class UpdateVerificationException implements Exception {
  final VerificationFailure failure;
  final String message;
  const UpdateVerificationException(this.failure, this.message);
  @override
  String toString() => message;
}

class UpdateVerifier {
  const UpdateVerifier();

  Future<void> verifyFile(String path, UpdateManifest manifest) async {
    final file = File(path);
    if (!await file.exists()) {
      throw const UpdateVerificationException(
        VerificationFailure.missing,
        'The downloaded APK is missing.',
      );
    }
    final length = await file.length();
    if (manifest.apkSize != null && length != manifest.apkSize) {
      throw UpdateVerificationException(
        VerificationFailure.sizeMismatch,
        'Expected ${manifest.apkSize} bytes but downloaded $length bytes.',
      );
    }
    final digest = await sha256.bind(file.openRead()).first;
    if (digest.toString().toLowerCase() != manifest.sha256) {
      throw const UpdateVerificationException(
        VerificationFailure.checksumMismatch,
        'The downloaded APK SHA-256 did not match the manifest.',
      );
    }
  }
}
