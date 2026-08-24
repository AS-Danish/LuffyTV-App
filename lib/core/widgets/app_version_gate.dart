import 'package:flutter/material.dart';
import 'package:luffytv/core/services/app_version_service.dart';
import 'package:luffytv/core/theme/app_colors.dart';
import 'package:luffytv/features/downloads/data/models/download_item.dart';
import 'package:luffytv/features/downloads/providers/download_providers.dart';
import 'package:luffytv/features/profile/presentation/downloads_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class AppVersionGate extends StatefulWidget {
  final Widget child;
  const AppVersionGate({super.key, required this.child});

  @override
  State<AppVersionGate> createState() => _AppVersionGateState();
}

class _GateState {
  final AppVersionDecision? decision;
  final bool hasDownloads;
  const _GateState(this.decision, this.hasDownloads);
}

class _AppVersionGateState extends State<AppVersionGate>
    with WidgetsBindingObserver {
  late Future<_GateState> _future = _load();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() => _future = _load());
    }
  }

  Future<_GateState> _load() async {
    final values = await Future.wait<dynamic>([
      AppVersionService.check(),
      DownloadNotifier.loadStoredDownloads(),
    ]);
    final downloads = values[1] as List<DownloadItem>;
    return _GateState(
      values[0] as AppVersionDecision?,
      downloads.any(
        (item) =>
            item.state == DownloadState.completed &&
            item.localM3u8Path?.isNotEmpty == true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_GateState>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: AppColors.bg,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final state = snapshot.data!;
        if (state.decision?.updateRequired != true) return widget.child;
        return _MandatoryUpdateScreen(
          decision: state.decision!,
          hasDownloads: state.hasDownloads,
          retry: () => setState(() => _future = _load()),
        );
      },
    );
  }
}

class _MandatoryUpdateScreen extends StatelessWidget {
  final AppVersionDecision decision;
  final bool hasDownloads;
  final VoidCallback retry;
  const _MandatoryUpdateScreen({
    required this.decision,
    required this.hasDownloads,
    required this.retry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  children: [
                    Container(
                      width: 92,
                      height: 92,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        gradient: AppColors.accentGradient,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Image.asset('assets/images/LuffyTVLogo.png'),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Update required',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      decision.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Installed ${decision.installedVersion}  •  Required ${decision.minimumVersion}',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: decision.updateUrl.isEmpty
                            ? retry
                            : () => launchUrl(
                                Uri.parse(decision.updateUrl),
                                mode: LaunchMode.externalApplication,
                              ),
                        icon: const Icon(Icons.system_update_alt_rounded),
                        label: Text(
                          decision.updateUrl.isEmpty
                              ? 'Check again'
                              : 'Update now',
                        ),
                      ),
                    ),
                    if (hasDownloads) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const DownloadsScreen(),
                            ),
                          ),
                          icon: const Icon(Icons.download_done_rounded),
                          label: const Text('Watch my downloads'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Streaming stays locked, but completed downloads remain available.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
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
    );
  }
}
