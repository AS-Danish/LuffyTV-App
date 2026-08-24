import 'package:flutter/material.dart';
import 'package:luffytv/core/theme/app_colors.dart';
import 'package:luffytv/core/theme/app_theme.dart';
import 'package:luffytv/core/utils/responsive.dart';
import 'downloads_screen.dart';
import 'profile_pages.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  responsive.screenPadding,
                  28,
                  responsive.screenPadding,
                  130,
                ),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'YOUR SPACE',
                              style: AppTextStyles.label.copyWith(
                                color: AppColors.accentEnd,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text('Profile', style: AppTextStyles.display),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'App settings',
                        onPressed: () =>
                            _open(context, const AppSettingsScreen()),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.surfaceRaised,
                          side: const BorderSide(color: AppColors.border),
                        ),
                        icon: const Icon(Icons.settings_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: .88),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .25),
                          blurRadius: 30,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 76,
                          height: 76,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: AppColors.accentGradient,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accentStart.withValues(
                                  alpha: .25,
                                ),
                                blurRadius: 24,
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/LuffyTVLogo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(width: 17),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Luffy TV Viewer',
                                style: AppTextStyles.sectionTitle,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Local profile · your activity stays on this device',
                                style: AppTextStyles.body,
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(
                                    alpha: .1,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.full,
                                  ),
                                  border: Border.all(
                                    color: AppColors.success.withValues(
                                      alpha: .25,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  'STREAM READY',
                                  style: AppTextStyles.label.copyWith(
                                    color: AppColors.success,
                                    fontSize: 9,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text('WATCHING', style: AppTextStyles.label),
                  const SizedBox(height: 10),
                  _SettingsCard(
                    children: [
                      _SettingsTile(
                        icon: Icons.download_for_offline_outlined,
                        title: 'Downloads',
                        subtitle: 'Watch offline and manage storage',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const DownloadsScreen(),
                          ),
                        ),
                      ),
                      _SettingsTile(
                        icon: Icons.history_rounded,
                        title: 'Watch history',
                        subtitle: 'Continue from where you stopped',
                        onTap: () => _open(context, const WatchHistoryScreen()),
                      ),
                      _SettingsTile(
                        icon: Icons.subtitles_outlined,
                        title: 'Playback & captions',
                        subtitle: 'Quality, audio, and subtitle preferences',
                        onTap: () =>
                            _open(context, const PlaybackSettingsScreen()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('APP', style: AppTextStyles.label),
                  const SizedBox(height: 10),
                  _SettingsCard(
                    children: [
                      _SettingsTile(
                        icon: Icons.notifications_none_rounded,
                        title: 'Notifications',
                        subtitle: 'Episode and download updates',
                        onTap: () =>
                            _open(context, const NotificationSettingsScreen()),
                      ),
                      _SettingsTile(
                        icon: Icons.storage_outlined,
                        title: 'Data & storage',
                        subtitle: 'Cache, downloads, and streaming data',
                        onTap: () => _open(context, const DataStorageScreen()),
                      ),
                      _SettingsTile(
                        icon: Icons.help_outline_rounded,
                        title: 'Help & feedback',
                        subtitle: 'Get support or share an idea',
                        onTap: () => _open(context, const HelpFeedbackScreen()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Center(
                    child: FutureBuilder<PackageInfo>(
                      future: PackageInfo.fromPlatform(),
                      builder: (context, snapshot) {
                        final info = snapshot.data;
                        return Text(
                          info == null
                              ? 'Luffy TV'
                              : 'Luffy TV · Version ${info.version} (${info.buildNumber})',
                          style: AppTextStyles.caption,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index < children.length - 1)
              const Divider(height: 1, indent: 64),
          ],
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: 72,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Icon(icon, color: AppColors.textSecondary, size: 20),
      ),
      title: Text(title, style: AppTextStyles.cardTitle),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textMuted,
      ),
      onTap: onTap,
    );
  }
}
