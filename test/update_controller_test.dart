import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:luffytv/update/update_controller.dart';
import 'package:luffytv/update/update_downloader.dart';
import 'package:luffytv/update/update_installer.dart';
import 'package:luffytv/update/update_manifest.dart';
import 'package:luffytv/update/update_repository.dart';
import 'package:luffytv/update/update_state.dart';
import 'package:luffytv/update/update_verifier.dart';
import 'package:package_info_plus/package_info_plus.dart';

UpdateManifest controllerManifest() => UpdateManifest.fromJson({
  'version': '1.1.0',
  'versionCode': 2,
  'minimumSupportedVersionCode': 2,
  'apkUrl': 'https://releases.example/app.apk',
  'sha256': List.filled(64, 'a').join(),
  'apkSize': 1024,
  'mandatory': true,
});

PackageInfo installedInfo() => PackageInfo(
  appName: 'Luffy TV',
  packageName: 'com.luffytv.luffytv',
  version: '1.0.0',
  buildNumber: '1',
  buildSignature: '',
);

class FakeRepository extends UpdateRepository {
  final Completer<void>? wait;
  int calls = 0;
  FakeRepository({this.wait})
    : super(manifestUri: Uri.parse('https://updates.example/manifest'));

  @override
  Future<UpdateFetchResult> fetch({bool allowCached = true}) async {
    calls++;
    await wait?.future;
    return UpdateFetchResult(controllerManifest(), fromCache: false);
  }
}

class FakeDownloader extends UpdateDownloader {
  final Completer<void>? wait;
  final started = Completer<void>();
  int calls = 0;
  String? path;
  FakeDownloader({this.wait});

  @override
  Future<void> cleanup({int? keepVersionCode}) async {}

  @override
  Future<File> apkFile(UpdateManifest manifest) async => File(
    '${Directory.systemTemp.path}/missing-luffy-update-${manifest.versionCode}.apk',
  );

  @override
  Future<String> download(
    UpdateManifest manifest,
    void Function(UpdateDownloadProgress progress) onProgress,
  ) async {
    calls++;
    if (!started.isCompleted) started.complete();
    onProgress(const UpdateDownloadProgress(512, 1024, 100));
    await wait?.future;
    final directory = await Directory.systemTemp.createTemp(
      'luffy-controller-',
    );
    path = '${directory.path}/validated.apk';
    await File(path!).writeAsBytes([1]);
    return path!;
  }

  @override
  Future<String> promoteVerified(
    UpdateManifest manifest,
    String partPath,
  ) async => path!;
}

class FakeVerifier extends UpdateVerifier {
  const FakeVerifier();
  @override
  Future<void> verifyFile(String path, UpdateManifest manifest) async {}
}

class FakeInstaller implements AppUpdateInstaller {
  @override
  Future<int> availableBytes() async => 1024 * 1024 * 1024;
  @override
  Future<bool> canRequestPackageInstalls() async => false;
  @override
  Future<void> clearInstallationStatus() async {}
  @override
  Future<NativeInstallStatus> getInstallationStatus() async =>
      const NativeInstallStatus('none', null, null);
  @override
  Future<ApkInspection> inspectApk(String path) async => const ApkInspection(
    packageName: 'com.luffytv.luffytv',
    versionCode: 2,
    signatureMatches: true,
  );
  @override
  Future<int> installApk(String path, int expectedVersionCode) async => 1;
  @override
  Future<bool> isSelfUpdaterSupported() async => true;
  @override
  Future<void> openUnknownSourcesSettings() async {}
}

void main() {
  test('duplicate update checks share one repository request', () async {
    final wait = Completer<void>();
    final repository = FakeRepository(wait: wait);
    final controller = UpdateController(
      repository: repository,
      downloader: FakeDownloader(),
      installer: FakeInstaller(),
      packageInfoLoader: () async => installedInfo(),
    );
    controller.value = const AppUpdateState(installedVersionCode: 1);
    final first = controller.checkForUpdate();
    final second = controller.checkForUpdate();
    await Future<void>.delayed(Duration.zero);
    expect(repository.calls, 1);
    wait.complete();
    await Future.wait([first, second]);
    expect(controller.value.status, UpdateStatus.updateRequired);
  });

  test(
    'duplicate update taps start one download and reach permission state',
    () async {
      final wait = Completer<void>();
      final downloader = FakeDownloader(wait: wait);
      final controller = UpdateController(
        repository: FakeRepository(),
        downloader: downloader,
        verifier: const FakeVerifier(),
        installer: FakeInstaller(),
        packageInfoLoader: () async => installedInfo(),
      );
      controller.value = AppUpdateState(
        status: UpdateStatus.updateRequired,
        manifest: controllerManifest(),
        installedVersion: '1.0.0',
        installedVersionCode: 1,
      );
      final first = controller.startUpdate();
      final second = controller.startUpdate();
      await downloader.started.future;
      expect(downloader.calls, 1);
      wait.complete();
      await Future.wait([first, second]);
      expect(controller.value.status, UpdateStatus.awaitingInstallPermission);
    },
  );
}
