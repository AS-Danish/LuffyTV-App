import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'update_downloader.dart';
import 'update_installer.dart';
import 'update_manifest.dart';
import 'update_repository.dart';
import 'update_state.dart';
import 'update_verifier.dart';

class UpdateController extends ValueNotifier<AppUpdateState> {
  static final UpdateController instance = UpdateController();
  static const _previousBuildKey = 'luffytv_previous_build_code';

  final UpdateRepository repository;
  final UpdateDownloader downloader;
  final UpdateVerifier verifier;
  final AppUpdateInstaller installer;
  final Future<PackageInfo> Function() packageInfoLoader;
  Future<void>? _checkOperation;
  Future<void>? _downloadOperation;
  bool _initialized = false;
  bool _runtimeEnabled = true;

  UpdateController({
    UpdateRepository? repository,
    UpdateDownloader? downloader,
    UpdateVerifier? verifier,
    AppUpdateInstaller? installer,
    Future<PackageInfo> Function()? packageInfoLoader,
  }) : repository = repository ?? UpdateRepository(),
       downloader = downloader ?? UpdateDownloader(),
       verifier = verifier ?? const UpdateVerifier(),
       installer = installer ?? AndroidUpdateInstaller(),
       packageInfoLoader = packageInfoLoader ?? PackageInfo.fromPlatform,
       super(const AppUpdateState());

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    final info = await packageInfoLoader();
    final buildCode = int.tryParse(info.buildNumber) ?? 0;
    value = value.copyWith(
      installedVersion: info.version,
      installedVersionCode: buildCode,
    );
    final prefs = await SharedPreferences.getInstance();
    final previousCode = prefs.getInt(_previousBuildKey);
    await prefs.setInt(_previousBuildKey, buildCode);
    if (previousCode != null && buildCode > previousCode) {
      await installer.clearInstallationStatus();
      await downloader.cleanup();
    } else {
      await downloader.cleanup(keepVersionCode: value.manifest?.versionCode);
    }

    const explicitlyEnabled = bool.fromEnvironment('ENABLE_SELF_UPDATER');
    if (kDebugMode && !explicitlyEnabled) {
      _runtimeEnabled = false;
      value = value.copyWith(status: UpdateStatus.noUpdate);
      return;
    }
    await checkForUpdate();
  }

  Future<void> checkForUpdate({bool manual = false}) {
    final existing = _checkOperation;
    if (existing != null) return existing;
    final operation = _performCheck(manual: manual);
    _checkOperation = operation;
    return operation.whenComplete(() => _checkOperation = null);
  }

  Future<void> _performCheck({required bool manual}) async {
    if (!_runtimeEnabled) {
      value = value.copyWith(
        status: manual ? UpdateStatus.failed : UpdateStatus.noUpdate,
        failure: manual
            ? const UpdateFailure(
                UpdateFailureType.unsupportedDistribution,
                'The updater is disabled in debug builds. Start with '
                '--dart-define=ENABLE_SELF_UPDATER=true to test it.',
              )
            : null,
      );
      return;
    }
    if (!await installer.isSelfUpdaterSupported()) {
      value = value.copyWith(
        status: manual ? UpdateStatus.failed : UpdateStatus.noUpdate,
        failure: manual
            ? const UpdateFailure(
                UpdateFailureType.unsupportedDistribution,
                'Native self updater is disabled.',
              )
            : null,
      );
      return;
    }
    value = value.copyWith(status: UpdateStatus.checking, failure: null);
    try {
      final result = await repository.fetch();
      final manifest = result.manifest;
      if (manifest.versionCode <= value.installedVersionCode) {
        value = value.copyWith(
          status: UpdateStatus.noUpdate,
          manifest: null,
          failure: null,
          manifestFromCache: false,
        );
        await downloader.cleanup();
        return;
      }
      value = value.copyWith(
        status: UpdateStatus.updateRequired,
        manifest: manifest,
        failure: null,
        manifestFromCache: result.fromCache,
      );
      await downloader.cleanup(keepVersionCode: manifest.versionCode);
      _log('UPDATE_REQUIRED versionCode=${manifest.versionCode}');
    } on UpdateRepositoryException catch (error) {
      final failure = error.invalidManifest
          ? UpdateFailureType.invalidManifest
          : error.timeout
          ? UpdateFailureType.timeout
          : error.network
          ? UpdateFailureType.noInternet
          : UpdateFailureType.serverError;
      value = value.copyWith(
        status: UpdateStatus.failed,
        failure: UpdateFailure(failure, error.toString()),
      );
      _log('UPDATE_CHECK_FAILED $error');
    } catch (error) {
      value = value.copyWith(
        status: UpdateStatus.failed,
        failure: UpdateFailure(UpdateFailureType.unknown, error.toString()),
      );
    }
  }

  Future<void> startUpdate() {
    final existing = _downloadOperation;
    if (existing != null) return existing;
    final operation = _performUpdate();
    _downloadOperation = operation;
    return operation.whenComplete(() => _downloadOperation = null);
  }

  Future<void> _performUpdate() async {
    final initialManifest = value.manifest;
    if (initialManifest == null ||
        initialManifest.versionCode <= value.installedVersionCode) {
      return;
    }
    var manifest = initialManifest;
    value = value.copyWith(
      status: UpdateStatus.preparingDownload,
      failure: null,
      bytesDownloaded: 0,
      totalBytes: manifest.apkSize ?? 0,
      bytesPerSecond: 0,
    );
    try {
      if (value.manifestFromCache) {
        final fresh = await repository.fetch(allowCached: false);
        if (fresh.manifest.versionCode < manifest.versionCode) {
          throw const FormatException('Fresh manifest attempted a downgrade.');
        }
        manifest = fresh.manifest;
        value = value.copyWith(manifest: manifest, manifestFromCache: false);
      }

      final existingApk = await downloader.apkFile(manifest);
      if (await existingApk.exists()) {
        value = value.copyWith(status: UpdateStatus.verifying);
        try {
          await verifier.verifyFile(existingApk.path, manifest);
          await _validateApkIdentity(existingApk.path, manifest);
          value = value.copyWith(
            status: UpdateStatus.readyToInstall,
            verifiedApkPath: existingApk.path,
          );
          await requestInstallation();
          return;
        } catch (_) {
          await existingApk.delete();
        }
      }

      final available = await installer.availableBytes();
      final expected = manifest.apkSize;
      if (expected != null && available > 0) {
        final required = expected * 2 + 50 * 1024 * 1024;
        if (available < required) {
          throw const _UpdateFlowException(
            UpdateFailureType.insufficientStorage,
            'Insufficient free space.',
          );
        }
      }

      value = value.copyWith(status: UpdateStatus.downloading);
      _log('UPDATE_DOWNLOAD_STARTED versionCode=${manifest.versionCode}');
      final partPath = await downloader.download(manifest, (progress) {
        value = value.copyWith(
          status: UpdateStatus.downloading,
          bytesDownloaded: progress.bytesDownloaded,
          totalBytes: progress.totalBytes,
          bytesPerSecond: progress.bytesPerSecond,
        );
      });

      value = value.copyWith(status: UpdateStatus.verifying);
      await verifier.verifyFile(partPath, manifest);
      await _validateApkIdentity(partPath, manifest);
      final apkPath = await downloader.promoteVerified(manifest, partPath);
      value = value.copyWith(
        status: UpdateStatus.readyToInstall,
        verifiedApkPath: apkPath,
      );
      _log('UPDATE_HASH_AND_IDENTITY_VERIFIED');
      await requestInstallation();
    } on UpdateVerificationException catch (error) {
      await _deleteActiveFiles(manifest);
      _fail(
        error.failure == VerificationFailure.checksumMismatch
            ? UpdateFailureType.checksumMismatch
            : UpdateFailureType.invalidApk,
        error.toString(),
      );
    } on UpdateDownloadException catch (error) {
      _fail(
        error.noSpace
            ? UpdateFailureType.insufficientStorage
            : UpdateFailureType.downloadFailed,
        error.toString(),
      );
    } on _UpdateFlowException catch (error) {
      if ({
        UpdateFailureType.invalidApk,
        UpdateFailureType.packageMismatch,
        UpdateFailureType.signatureMismatch,
      }.contains(error.type)) {
        await _deleteActiveFiles(manifest);
      }
      _fail(error.type, error.message);
    } catch (error) {
      _fail(UpdateFailureType.unknown, error.toString());
    }
  }

  Future<void> requestInstallation() async {
    final manifest = value.manifest;
    final path = value.verifiedApkPath;
    if (manifest == null || path == null || !await File(path).exists()) {
      value = value.copyWith(
        status: UpdateStatus.updateRequired,
        verifiedApkPath: null,
      );
      return;
    }
    if (!await installer.canRequestPackageInstalls()) {
      value = value.copyWith(status: UpdateStatus.awaitingInstallPermission);
      return;
    }
    value = value.copyWith(
      status: UpdateStatus.launchingInstaller,
      failure: null,
    );
    try {
      await installer.clearInstallationStatus();
      await installer.installApk(path, manifest.versionCode);
      value = value.copyWith(status: UpdateStatus.waitingForInstaller);
      _log('UPDATE_INSTALLER_LAUNCHED');
    } catch (error) {
      _fail(UpdateFailureType.installerUnavailable, error.toString());
    }
  }

  Future<void> _validateApkIdentity(
    String path,
    UpdateManifest manifest,
  ) async {
    final inspection = await installer.inspectApk(path);
    final info = await packageInfoLoader();
    if (inspection.packageName != info.packageName) {
      throw _UpdateFlowException(
        UpdateFailureType.packageMismatch,
        'Expected ${info.packageName}, received ${inspection.packageName}.',
      );
    }
    if (inspection.versionCode != manifest.versionCode ||
        inspection.versionCode <= value.installedVersionCode) {
      throw _UpdateFlowException(
        UpdateFailureType.invalidApk,
        'APK versionCode ${inspection.versionCode} did not match ${manifest.versionCode}.',
      );
    }
    if (!inspection.signatureMatches) {
      throw const _UpdateFlowException(
        UpdateFailureType.signatureMismatch,
        'APK signer did not match the installed application.',
      );
    }
  }

  Future<void> openInstallPermissionSettings() async {
    try {
      await installer.openUnknownSourcesSettings();
    } catch (error) {
      _fail(UpdateFailureType.permissionDenied, error.toString());
    }
  }

  Future<void> handleResume() async {
    if (value.status == UpdateStatus.awaitingInstallPermission) {
      if (await installer.canRequestPackageInstalls()) {
        await requestInstallation();
      }
      return;
    }
    if (value.status != UpdateStatus.waitingForInstaller) return;
    final info = await packageInfoLoader();
    final currentCode = int.tryParse(info.buildNumber) ?? 0;
    final target = value.manifest?.versionCode ?? 0;
    if (currentCode >= target && target > 0) {
      value = value.copyWith(
        status: UpdateStatus.installed,
        installedVersion: info.version,
        installedVersionCode: currentCode,
        manifest: null,
        verifiedApkPath: null,
      );
      await downloader.cleanup();
      await installer.clearInstallationStatus();
      return;
    }
    final nativeStatus = await installer.getInstallationStatus();
    switch (nativeStatus.status) {
      case 'failed_aborted':
        value = value.copyWith(
          status: UpdateStatus.readyToInstall,
          failure: UpdateFailure(
            UpdateFailureType.installationCancelled,
            nativeStatus.message ?? 'Installer cancelled.',
          ),
        );
      case 'failed_storage':
        _fail(
          UpdateFailureType.insufficientStorage,
          nativeStatus.message ?? 'Installer storage failure.',
        );
      case 'failed_conflict':
        _fail(
          UpdateFailureType.signatureMismatch,
          nativeStatus.message ?? 'Package conflict.',
        );
      case 'failed_invalid' || 'failed_incompatible':
        _fail(
          UpdateFailureType.invalidApk,
          nativeStatus.message ?? 'Invalid APK.',
        );
      case 'failed_blocked':
        _fail(
          UpdateFailureType.permissionDenied,
          nativeStatus.message ?? 'Installation blocked.',
        );
      case 'failed':
        _fail(
          UpdateFailureType.installationFailed,
          nativeStatus.message ?? 'Installation failed.',
        );
      default:
        value = value.copyWith(status: UpdateStatus.readyToInstall);
    }
  }

  Future<void> retry() async {
    if (value.manifest != null && value.blocksStreaming) {
      await startUpdate();
    } else {
      await checkForUpdate(manual: true);
    }
  }

  void _fail(UpdateFailureType type, String technical) {
    _log('UPDATE_FAILED type=$type detail=$technical');
    value = value.copyWith(
      status: UpdateStatus.failed,
      failure: UpdateFailure(type, technical),
    );
  }

  Future<void> _deleteActiveFiles(UpdateManifest manifest) async {
    for (final file in [
      await downloader.partFile(manifest),
      await downloader.apkFile(manifest),
    ]) {
      if (await file.exists()) await file.delete();
      final metadata = File('${file.path}.json');
      if (await metadata.exists()) await metadata.delete();
    }
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('[LuffyUpdate] $message');
  }
}

class _UpdateFlowException implements Exception {
  final UpdateFailureType type;
  final String message;
  const _UpdateFlowException(this.type, this.message);
  @override
  String toString() => message;
}
