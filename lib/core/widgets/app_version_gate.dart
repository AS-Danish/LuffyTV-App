import 'dart:async';

import 'package:flutter/material.dart';
import 'package:luffytv/core/services/network_monitor.dart';
import 'package:luffytv/core/theme/app_colors.dart';
import 'package:luffytv/features/downloads/data/models/download_item.dart';
import 'package:luffytv/features/downloads/providers/download_providers.dart';
import 'package:luffytv/features/profile/presentation/downloads_screen.dart';
import 'package:luffytv/update/update_controller.dart';
import 'package:luffytv/update/update_state.dart';

class AppVersionGate extends StatefulWidget {
  final Widget child;
  const AppVersionGate({super.key, required this.child});

  @override
  State<AppVersionGate> createState() => _AppVersionGateState();
}

class _AppVersionGateState extends State<AppVersionGate>
    with WidgetsBindingObserver {
  final controller = UpdateController.instance;
  final _networkMonitor = NetworkMonitor();
  bool hasDownloads = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller.addListener(_changed);
    _networkMonitor.addListener(_networkChanged);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(_initialize()),
    );
  }

  Future<void> _initialize() async {
    await Future.wait([
      _loadDownloads(),
      _networkMonitor.start(),
      controller.initialize(),
    ]);
  }

  Future<void> _loadDownloads() async {
    final downloads = await DownloadNotifier.loadStoredDownloads();
    if (!mounted) return;
    setState(() {
      hasDownloads = downloads.any(
        (item) =>
            item.state == DownloadState.completed &&
            item.localM3u8Path?.isNotEmpty == true,
      );
    });
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
  }

  void _networkChanged() {
    if (!mounted) return;
    if (_networkMonitor.isOnline && controller.value.networkUnavailable) {
      unawaited(controller.checkForUpdate());
    }
    setState(() {});
  }

  bool _showOfflineDownloads(AppUpdateState state) {
    final unavailable = _networkMonitor.isOffline || state.networkUnavailable;
    if (!unavailable || state.verifiedApkPath != null) {
      return false;
    }
    return !const {
      UpdateStatus.launchingInstaller,
      UpdateStatus.waitingForInstaller,
      UpdateStatus.installed,
    }.contains(state.status);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(controller.handleResume());
      unawaited(_networkMonitor.refresh());
      if (_networkMonitor.isOnline && controller.value.networkUnavailable) {
        unawaited(controller.checkForUpdate());
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.removeListener(_changed);
    _networkMonitor.removeListener(_networkChanged);
    _networkMonitor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = controller.value;
    if (!_networkMonitor.hasChecked) {
      return const _ConnectionCheckScreen();
    }
    if (_showOfflineDownloads(state)) {
      return const PopScope(
        canPop: false,
        child: DownloadsScreen(offlineMode: true),
      );
    }
    if (!state.blocksStreaming) return widget.child;
    return PopScope(
      canPop: false,
      child: MandatoryUpdateScreen(
        state: state,
        controller: controller,
        hasDownloads: hasDownloads,
      ),
    );
  }
}

class _ConnectionCheckScreen extends StatelessWidget {
  const _ConnectionCheckScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Center(
          child: Semantics(
            label: 'Checking internet connection',
            child: CircularProgressIndicator(),
          ),
        ),
      ),
    );
  }
}

class MandatoryUpdateScreen extends StatelessWidget {
  final AppUpdateState state;
  final UpdateController controller;
  final bool hasDownloads;
  const MandatoryUpdateScreen({
    super.key,
    required this.state,
    required this.controller,
    required this.hasDownloads,
  });

  @override
  Widget build(BuildContext context) {
    final manifest = state.manifest!;
    final downloading = state.status == UpdateStatus.downloading;
    final statusLabel = switch (state.status) {
      UpdateStatus.preparingDownload => 'Preparing secure download…',
      UpdateStatus.downloading => 'Downloading update…',
      UpdateStatus.verifying => 'Verifying APK integrity and identity…',
      UpdateStatus.awaitingInstallPermission =>
        'Android needs permission to let Luffy TV open its update installer.',
      UpdateStatus.readyToInstall => 'Update downloaded and verified.',
      UpdateStatus.launchingInstaller => 'Opening Android installer…',
      UpdateStatus.waitingForInstaller =>
        'Confirm the update in Android’s installer.',
      UpdateStatus.failed => state.failure?.userMessage ?? 'Update failed.',
      _ => manifest.message,
    };

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(26),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Semantics(
                  liveRegion: true,
                  child: Column(
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: AppColors.accentGradient,
                          borderRadius: BorderRadius.circular(27),
                        ),
                        child: Image.asset('assets/images/LuffyTVLogo.png'),
                      ),
                      const SizedBox(height: 25),
                      Text(
                        manifest.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 29,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Version ${manifest.version} (${manifest.versionCode})',
                        style: const TextStyle(color: AppColors.accentEnd),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        statusLabel,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      if (downloading ||
                          state.status == UpdateStatus.verifying) ...[
                        const SizedBox(height: 22),
                        LinearProgressIndicator(
                          value: downloading ? state.progress : null,
                        ),
                        const SizedBox(height: 9),
                        Text(
                          downloading
                              ? '${_bytes(state.bytesDownloaded)} / ${state.totalBytes > 0 ? _bytes(state.totalBytes) : 'Unknown'}  •  ${state.progress == null ? '—' : '${(state.progress! * 100).round()}%'}${state.bytesPerSecond > 0 ? '  •  ${_bytes(state.bytesPerSecond.round())}/s' : ''}'
                              : 'SHA-256, package name, version code, and signing key',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                      if (manifest.changelog.isNotEmpty &&
                          !state.busy &&
                          state.status !=
                              UpdateStatus.awaitingInstallPermission) ...[
                        const SizedBox(height: 22),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'WHAT\'S NEW',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 9),
                              for (final item in manifest.changelog)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text(
                                    '• $item',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed:
                              state.busy ||
                                  state.status ==
                                      UpdateStatus.waitingForInstaller
                              ? null
                              : () => _primaryAction(state, controller),
                          icon: Icon(_primaryIcon(state.status)),
                          label: Text(_primaryLabel(state.status)),
                        ),
                      ),
                      if (hasDownloads) ...[
                        const SizedBox(height: 11),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: state.busy
                                ? null
                                : () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const DownloadsScreen(),
                                    ),
                                  ),
                            icon: const Icon(Icons.download_done_rounded),
                            label: const Text('Watch completed downloads'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Streaming is locked until installation. Completed offline episodes remain available.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> _primaryAction(
    AppUpdateState state,
    UpdateController controller,
  ) async {
    switch (state.status) {
      case UpdateStatus.awaitingInstallPermission:
        await controller.openInstallPermissionSettings();
        return;
      case UpdateStatus.readyToInstall:
      case UpdateStatus.waitingForInstaller:
        await controller.requestInstallation();
        return;
      case UpdateStatus.failed:
        if (state.verifiedApkPath != null) {
          await controller.requestInstallation();
        } else {
          await controller.retry();
        }
        return;
      default:
        await controller.startUpdate();
    }
  }

  static String _primaryLabel(UpdateStatus status) => switch (status) {
    UpdateStatus.awaitingInstallPermission => 'Open installation settings',
    UpdateStatus.readyToInstall => 'Install update',
    UpdateStatus.waitingForInstaller => 'Open installer again',
    UpdateStatus.failed => 'Retry update',
    _ => 'Download compulsory update',
  };

  static IconData _primaryIcon(UpdateStatus status) => switch (status) {
    UpdateStatus.awaitingInstallPermission => Icons.settings_rounded,
    UpdateStatus.readyToInstall ||
    UpdateStatus.waitingForInstaller => Icons.install_mobile_rounded,
    UpdateStatus.failed => Icons.refresh_rounded,
    _ => Icons.download_rounded,
  };

  static String _bytes(int value) {
    if (value >= 1024 * 1024 * 1024) {
      return '${(value / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    if (value >= 1024 * 1024) {
      return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (value >= 1024) return '${(value / 1024).toStringAsFixed(1)} KB';
    return '$value B';
  }
}
