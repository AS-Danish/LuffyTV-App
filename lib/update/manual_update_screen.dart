import 'dart:async';

import 'package:flutter/material.dart';
import 'package:luffytv/core/theme/app_colors.dart';

import 'update_controller.dart';
import 'update_state.dart';

class ManualUpdateScreen extends StatefulWidget {
  const ManualUpdateScreen({super.key});

  @override
  State<ManualUpdateScreen> createState() => _ManualUpdateScreenState();
}

class _ManualUpdateScreenState extends State<ManualUpdateScreen> {
  final controller = UpdateController.instance;

  @override
  void initState() {
    super.initState();
    controller.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    controller.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = controller.value;
    final checking = state.status == UpdateStatus.checking;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('App updates')),
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'INSTALLED VERSION',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${state.installedVersion} (${state.installedVersionCode})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (state.failure != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      state.failure!.userMessage,
                      style: const TextStyle(
                        color: AppColors.error,
                        height: 1.45,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    Text(
                      checking
                          ? 'Checking the secure release manifest…'
                          : 'You are up to date. Every published APK update is compulsory.',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: checking
                  ? null
                  : () => unawaited(controller.checkForUpdate(manual: true)),
              icon: checking
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
              label: Text(checking ? 'Checking…' : 'Check for updates'),
            ),
          ],
        ),
      ),
    );
  }
}
