import 'package:flutter/material.dart';
import 'package:luffytv/core/theme/app_colors.dart';
import 'package:luffytv/features/home/data/models/anime.dart';
import 'package:luffytv/core/widgets/bouncing_button.dart';

import 'package:luffytv/features/home/data/models/episode.dart';

class DownloadedEpisodesScreen extends StatefulWidget {
  final Anime anime;

  const DownloadedEpisodesScreen({super.key, required this.anime});

  @override
  State<DownloadedEpisodesScreen> createState() => _DownloadedEpisodesScreenState();
}

class _DownloadedEpisodesScreenState extends State<DownloadedEpisodesScreen> {
  late List<Episode> _localEpisodes;

  @override
  void initState() {
    super.initState();
    // Collect all episodes from all seasons to flatten them
    _localEpisodes = widget.anime.seasons.expand((s) => s.episodes).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.anime.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: _localEpisodes.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.download_done_rounded, size: 80, color: Colors.white.withValues(alpha: 0.1)),
                    const SizedBox(height: 16),
                    Text('No downloaded episodes', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 16)),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: _localEpisodes.length,
                itemBuilder: (context, index) {
                  final episode = _localEpisodes[index];
                  return BouncingButton(
                    onTap: () {}, // Play downloaded video
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Thumbnail
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 140,
                                height: 80,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  image: widget.anime.posterUrl != null 
                                    ? DecorationImage(image: NetworkImage(widget.anime.posterUrl!), fit: BoxFit.cover)
                                    : null,
                                  color: Colors.grey[900],
                                ),
                              ),
                              const Icon(Icons.play_circle_outline, color: Colors.white, size: 36),
                              // Progress bar
                              if (episode.progress > 0)
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: LinearProgressIndicator(
                                    value: episode.progress,
                                    backgroundColor: Colors.white24,
                                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentStart),
                                    minHeight: 4,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          // Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(episode.title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text('${episode.durationMinutes}m • ${(episode.progress * episode.durationMinutes).toInt()}m watched', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                                const SizedBox(height: 8),
                                Text(
                                  episode.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.white54),
                            onPressed: () {
                              setState(() {
                                _localEpisodes.removeAt(index);
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${episode.title} removed from downloads'),
                                  backgroundColor: AppColors.surface,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
