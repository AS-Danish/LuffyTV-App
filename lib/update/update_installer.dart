import 'dart:io';

import 'package:flutter/services.dart';

class ApkInspection {
  final String packageName;
  final int versionCode;
  final bool signatureMatches;
  const ApkInspection({
    required this.packageName,
    required this.versionCode,
    required this.signatureMatches,
  });
}

class NativeInstallStatus {
  final String status;
  final String? message;
  final int? versionCode;
  const NativeInstallStatus(this.status, this.message, this.versionCode);
}

abstract interface class AppUpdateInstaller {
  Future<bool> isSelfUpdaterSupported();
  Future<int> availableBytes();
  Future<bool> canRequestPackageInstalls();
  Future<void> openUnknownSourcesSettings();
  Future<ApkInspection> inspectApk(String path);
  Future<int> installApk(String path, int expectedVersionCode);
  Future<NativeInstallStatus> getInstallationStatus();
  Future<void> clearInstallationStatus();
}

class AndroidUpdateInstaller implements AppUpdateInstaller {
  static const _channel = MethodChannel('com.luffytv/update_installer');

  @override
  Future<bool> isSelfUpdaterSupported() async {
    if (!Platform.isAndroid) return false;
    return await _channel.invokeMethod<bool>('isSelfUpdaterSupported') ?? false;
  }

  @override
  Future<int> availableBytes() async =>
      await _channel.invokeMethod<int>('getAvailableBytes') ?? 0;

  @override
  Future<bool> canRequestPackageInstalls() async =>
      await _channel.invokeMethod<bool>('canRequestPackageInstalls') ?? false;

  @override
  Future<void> openUnknownSourcesSettings() =>
      _channel.invokeMethod<void>('openUnknownSourcesSettings');

  @override
  Future<ApkInspection> inspectApk(String path) async {
    final raw = await _channel.invokeMapMethod<String, dynamic>('inspectApk', {
      'path': path,
    });
    if (raw == null) throw const FormatException('APK inspection failed.');
    return ApkInspection(
      packageName: raw['packageName']?.toString() ?? '',
      versionCode: (raw['versionCode'] as num?)?.toInt() ?? 0,
      signatureMatches: raw['signatureMatches'] == true,
    );
  }

  @override
  Future<int> installApk(String path, int expectedVersionCode) async =>
      await _channel.invokeMethod<int>('installApk', {
        'path': path,
        'expectedVersionCode': expectedVersionCode,
      }) ??
      -1;

  @override
  Future<NativeInstallStatus> getInstallationStatus() async {
    final raw = await _channel.invokeMapMethod<String, dynamic>(
      'getInstallationStatus',
    );
    return NativeInstallStatus(
      raw?['status']?.toString() ?? 'none',
      raw?['message']?.toString(),
      (raw?['versionCode'] as num?)?.toInt(),
    );
  }

  @override
  Future<void> clearInstallationStatus() =>
      _channel.invokeMethod<void>('clearInstallationStatus');
}
