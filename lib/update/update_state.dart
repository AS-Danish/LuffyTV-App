import 'update_manifest.dart';

enum UpdateStatus {
  idle,
  checking,
  updateRequired,
  noUpdate,
  preparingDownload,
  downloading,
  verifying,
  awaitingInstallPermission,
  readyToInstall,
  launchingInstaller,
  waitingForInstaller,
  installed,
  failed,
}

enum UpdateFailureType {
  noInternet,
  timeout,
  serverError,
  invalidManifest,
  insufficientStorage,
  downloadFailed,
  checksumMismatch,
  invalidApk,
  packageMismatch,
  signatureMismatch,
  permissionDenied,
  installerUnavailable,
  installationCancelled,
  installationFailed,
  unsupportedDistribution,
  unknown,
}

class UpdateFailure {
  final UpdateFailureType type;
  final String technicalMessage;
  const UpdateFailure(this.type, this.technicalMessage);

  String get userMessage => switch (type) {
    UpdateFailureType.noInternet =>
      'No internet connection. Connect to the internet and try again.',
    UpdateFailureType.timeout =>
      'The update service took too long to respond. Please retry.',
    UpdateFailureType.serverError =>
      'The update service is temporarily unavailable. Please retry.',
    UpdateFailureType.invalidManifest =>
      'The update information is invalid. Please contact Luffy TV support.',
    UpdateFailureType.insufficientStorage =>
      'Not enough device storage. Free some space and try again.',
    UpdateFailureType.downloadFailed =>
      'The update could not be downloaded. Please retry.',
    UpdateFailureType.checksumMismatch || UpdateFailureType.invalidApk =>
      'The downloaded update is corrupted or invalid. Download it again.',
    UpdateFailureType.packageMismatch =>
      'The update is not a Luffy TV APK and was rejected.',
    UpdateFailureType.signatureMismatch =>
      'The update was signed with a different key and cannot replace this app.',
    UpdateFailureType.permissionDenied =>
      'Android still needs permission to install this update.',
    UpdateFailureType.installerUnavailable =>
      'No compatible Android package installer is available.',
    UpdateFailureType.installationCancelled =>
      'Installation was cancelled. Tap Install update when you are ready.',
    UpdateFailureType.installationFailed =>
      'Android could not install the update. Check the details and retry.',
    UpdateFailureType.unsupportedDistribution =>
      'Self-updating is disabled for this distribution of Luffy TV.',
    UpdateFailureType.unknown => 'The update failed. Please retry.',
  };
}

class AppUpdateState {
  static const _unset = Object();
  final UpdateStatus status;
  final UpdateManifest? manifest;
  final UpdateFailure? failure;
  final String installedVersion;
  final int installedVersionCode;
  final int bytesDownloaded;
  final int totalBytes;
  final double bytesPerSecond;
  final String? verifiedApkPath;
  final bool manifestFromCache;
  final bool networkUnavailable;

  const AppUpdateState({
    this.status = UpdateStatus.idle,
    this.manifest,
    this.failure,
    this.installedVersion = '',
    this.installedVersionCode = 0,
    this.bytesDownloaded = 0,
    this.totalBytes = 0,
    this.bytesPerSecond = 0,
    this.verifiedApkPath,
    this.manifestFromCache = false,
    this.networkUnavailable = false,
  });

  bool get blocksStreaming =>
      manifest != null && manifest!.versionCode > installedVersionCode;
  double? get progress =>
      totalBytes > 0 ? (bytesDownloaded / totalBytes).clamp(0.0, 1.0) : null;
  bool get busy => const {
    UpdateStatus.checking,
    UpdateStatus.preparingDownload,
    UpdateStatus.downloading,
    UpdateStatus.verifying,
    UpdateStatus.launchingInstaller,
  }.contains(status);

  AppUpdateState copyWith({
    UpdateStatus? status,
    Object? manifest = _unset,
    Object? failure = _unset,
    String? installedVersion,
    int? installedVersionCode,
    int? bytesDownloaded,
    int? totalBytes,
    double? bytesPerSecond,
    Object? verifiedApkPath = _unset,
    bool? manifestFromCache,
    bool? networkUnavailable,
  }) => AppUpdateState(
    status: status ?? this.status,
    manifest: identical(manifest, _unset)
        ? this.manifest
        : manifest as UpdateManifest?,
    failure: identical(failure, _unset)
        ? this.failure
        : failure as UpdateFailure?,
    installedVersion: installedVersion ?? this.installedVersion,
    installedVersionCode: installedVersionCode ?? this.installedVersionCode,
    bytesDownloaded: bytesDownloaded ?? this.bytesDownloaded,
    totalBytes: totalBytes ?? this.totalBytes,
    bytesPerSecond: bytesPerSecond ?? this.bytesPerSecond,
    verifiedApkPath: identical(verifiedApkPath, _unset)
        ? this.verifiedApkPath
        : verifiedApkPath as String?,
    manifestFromCache: manifestFromCache ?? this.manifestFromCache,
    networkUnavailable: networkUnavailable ?? this.networkUnavailable,
  );
}
