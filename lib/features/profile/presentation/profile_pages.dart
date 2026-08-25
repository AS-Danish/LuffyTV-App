import 'package:flutter/material.dart';
import 'package:luffytv/core/services/local_db_service.dart';
import 'package:luffytv/core/theme/app_colors.dart';
import 'package:luffytv/core/widgets/cached_artwork_image.dart';
import 'package:luffytv/features/details/presentation/anime_details_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:luffytv/update/manual_update_screen.dart';

class WatchHistoryScreen extends StatefulWidget {
  const WatchHistoryScreen({super.key});

  @override
  State<WatchHistoryScreen> createState() => _WatchHistoryScreenState();
}

class _WatchHistoryScreenState extends State<WatchHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    final history = LocalDbService.getAllProgress();
    return _PageShell(
      title: 'Watch history',
      action: history.isEmpty
          ? null
          : TextButton(
              onPressed: () async {
                await LocalDbService.clearWatchHistory();
                if (mounted) setState(() {});
              },
              child: const Text('Clear'),
            ),
      child: history.isEmpty
          ? const _EmptyPage(
              icon: Icons.history_rounded,
              title: 'Nothing watched yet',
              copy: 'Anime you start watching will appear here.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 40),
              itemCount: history.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = history[index];
                final episode =
                    item.episodes[item.lastWatchedEpisode.toString()];
                final percent = episode == null || episode.durationSeconds <= 0
                    ? 0.0
                    : (episode.positionSeconds / episode.durationSeconds)
                          .clamp(0.0, 1.0)
                          .toDouble();
                return ListTile(
                  tileColor: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  contentPadding: const EdgeInsets.all(10),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: SizedBox(
                      width: 54,
                      height: 76,
                      child: item.anime.posterUrl?.isNotEmpty == true
                          ? CachedArtworkImage(
                              imageUrl: item.anime.posterUrl!,
                              previewUrl: item.anime.posterPreviewUrl,
                            )
                          : const ColoredBox(color: AppColors.surfaceSoft),
                    ),
                  ),
                  title: Text(item.anime.title, maxLines: 2),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Episode ${item.lastWatchedEpisode}'),
                        const SizedBox(height: 7),
                        LinearProgressIndicator(value: percent),
                      ],
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AnimeDetailsScreen(anime: item.anime),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class PlaybackSettingsScreen extends StatefulWidget {
  const PlaybackSettingsScreen({super.key});

  @override
  State<PlaybackSettingsScreen> createState() => _PlaybackSettingsScreenState();
}

class _PlaybackSettingsScreenState extends State<PlaybackSettingsScreen> {
  bool subtitles = true;
  bool autoplay = true;
  bool highQuality = true;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      setState(() {
        subtitles = prefs.getBool('playback_subtitles') ?? true;
        autoplay = prefs.getBool('playback_autoplay') ?? true;
        highQuality = prefs.getBool('playback_high_quality') ?? true;
      });
    });
  }

  Future<void> save(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) => _PageShell(
    title: 'Playback & captions',
    child: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        _SwitchTile(
          'Subtitles by default',
          'Show available English captions',
          subtitles,
          (value) {
            setState(() => subtitles = value);
            save('playback_subtitles', value);
          },
        ),
        _SwitchTile(
          'Autoplay next episode',
          'Continue without returning to details',
          autoplay,
          (value) {
            setState(() => autoplay = value);
            save('playback_autoplay', value);
          },
        ),
        _SwitchTile(
          'Prefer highest quality',
          'Use the clearest stream available',
          highQuality,
          (value) {
            setState(() => highQuality = value);
            save('playback_high_quality', value);
          },
        ),
      ],
    ),
  );
}

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool downloadAlerts = true;
  bool episodeAlerts = false;

  Future<void> save(String key, bool value) async =>
      (await SharedPreferences.getInstance()).setBool(key, value);

  @override
  Widget build(BuildContext context) => _PageShell(
    title: 'Notifications',
    child: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        _SwitchTile(
          'Download updates',
          'Know when an offline episode is ready',
          downloadAlerts,
          (value) {
            setState(() => downloadAlerts = value);
            save('notify_downloads', value);
          },
        ),
        _SwitchTile(
          'New episode reminders',
          'Saved for notification support',
          episodeAlerts,
          (value) {
            setState(() => episodeAlerts = value);
            save('notify_episodes', value);
          },
        ),
      ],
    ),
  );
}

class DataStorageScreen extends StatefulWidget {
  const DataStorageScreen({super.key});

  @override
  State<DataStorageScreen> createState() => _DataStorageScreenState();
}

class _DataStorageScreenState extends State<DataStorageScreen> {
  bool working = false;

  Future<void> clearArtwork() async {
    setState(() => working = true);
    await ArtworkCache.instance.emptyCache();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    if (mounted) {
      setState(() => working = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Artwork cache cleared.')));
    }
  }

  @override
  Widget build(BuildContext context) => _PageShell(
    title: 'Data & storage',
    child: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const _InfoCard(
          Icons.bolt_rounded,
          '90-day artwork cache',
          'Posters and backdrops stay on disk so revisiting pages is immediate.',
        ),
        const SizedBox(height: 12),
        ListTile(
          tileColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.border),
          ),
          leading: const Icon(Icons.cleaning_services_outlined),
          title: const Text('Clear artwork cache'),
          subtitle: const Text('Images will be downloaded again when needed.'),
          trailing: working
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.chevron_right_rounded),
          onTap: working ? null : clearArtwork,
        ),
      ],
    ),
  );
}

class HelpFeedbackScreen extends StatelessWidget {
  const HelpFeedbackScreen({super.key});
  @override
  Widget build(BuildContext context) => const _DocumentPage(
    title: 'Help & feedback',
    sections: {
      'Playback problems':
          'Try another server, confirm your connection, then retry. Luffy TV automatically retries temporary source failures.',
      'Downloads':
          'Completed downloads remain available without a connection and during a compulsory app update.',
      'Posters or captions':
          'Clear the artwork cache only if an image is corrupted. Caption position automatically rises when player controls are visible.',
      'Feedback':
          'When reporting a problem, include the anime name, episode number, server, and app version shown on the Profile page.',
    },
  );
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext context) => const _DocumentPage(
    title: 'About Luffy TV',
    sections: {
      'A complete anime home':
          'Discover titles, keep a personal list, track progress, stream episodes, and save supported episodes for offline viewing.',
      'Local by design':
          'Your list, playback progress, preferences, and download records are stored on this device.',
    },
  );
}

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});
  @override
  Widget build(BuildContext context) => const _DocumentPage(
    title: 'Privacy Policy',
    sections: {
      'Information stored locally':
          'Luffy TV stores your list, watch progress, settings, cached artwork, and download records on your device so the app works quickly.',
      'Network requests':
          'The app requests catalog data, artwork, captions, version policy, and playable sources from Luffy TV services and their content providers. Standard technical data such as IP address may be processed by those services.',
      'Your controls':
          'You can remove downloads, clear history, and clear cached artwork from inside the app or erase all app data through Android settings.',
      'Last updated': '24 August 2026.',
    },
  );
}

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});
  @override
  Widget build(BuildContext context) => const _DocumentPage(
    title: 'Terms of Use',
    sections: {
      'Using Luffy TV':
          'Use the service lawfully and do not attempt to disrupt, scrape excessively, reverse engineer access controls, or redistribute downloaded media.',
      'Availability':
          'Catalog entries, subtitles, servers, and episodes can change or become unavailable. Luffy TV does not guarantee uninterrupted availability.',
      'Offline content':
          'Downloads are for personal offline viewing inside Luffy TV and may stop working when removed, corrupted, or no longer supported.',
      'Updates':
          'A security or compatibility release may be made compulsory. On an outdated release, streaming is locked while completed downloads remain watchable.',
      'Last updated': '24 August 2026.',
    },
  );
}

class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => _PageShell(
    title: 'App settings',
    child: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        _LinkTile(
          'Check for updates',
          Icons.system_update_alt_rounded,
          const ManualUpdateScreen(),
        ),
        _LinkTile(
          'About Luffy TV',
          Icons.info_outline_rounded,
          const AboutScreen(),
        ),
        _LinkTile(
          'Privacy Policy',
          Icons.privacy_tip_outlined,
          const PrivacyPolicyScreen(),
        ),
        _LinkTile(
          'Terms of Use',
          Icons.description_outlined,
          const TermsScreen(),
        ),
      ],
    ),
  );
}

class _PageShell extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? action;
  const _PageShell({required this.title, required this.child, this.action});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: AppBar(
      title: Text(title),
      actions: action == null ? null : [action!],
    ),
    body: DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
      child: child,
    ),
  );
}

class _SwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchTile(this.title, this.subtitle, this.value, this.onChanged);
  @override
  Widget build(BuildContext context) => SwitchListTile(
    tileColor: AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: AppColors.border),
    ),
    title: Text(title),
    subtitle: Text(subtitle),
    value: value,
    onChanged: onChanged,
  );
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String copy;
  const _InfoCard(this.icon, this.title, this.copy);
  @override
  Widget build(BuildContext context) => ListTile(
    tileColor: AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: AppColors.border),
    ),
    leading: Icon(icon, color: AppColors.accentEnd),
    title: Text(title),
    subtitle: Text(copy),
  );
}

class _LinkTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget page;
  const _LinkTile(this.title, this.icon, this.page);
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: () =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)),
  );
}

class _DocumentPage extends StatelessWidget {
  final String title;
  final Map<String, String> sections;
  const _DocumentPage({required this.title, required this.sections});
  @override
  Widget build(BuildContext context) => _PageShell(
    title: title,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 50),
      children: [
        for (final entry in sections.entries) ...[
          Text(
            entry.key,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          Text(
            entry.value,
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ],
    ),
  );
}

class _EmptyPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String copy;
  const _EmptyPage({
    required this.icon,
    required this.title,
    required this.copy,
  });
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          Text(
            copy,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    ),
  );
}
