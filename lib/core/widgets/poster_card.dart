import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luffytv/core/theme/app_colors.dart';
import 'package:luffytv/core/theme/app_theme.dart';
import 'package:luffytv/features/home/data/models/anime.dart';
import 'package:luffytv/features/details/presentation/anime_details_screen.dart';
import 'package:luffytv/core/widgets/bouncing_button.dart';
import 'package:luffytv/core/services/local_db_service.dart';
import 'package:luffytv/features/home/providers/anime_providers.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:luffytv/features/home/providers/anime_providers.dart';
import 'package:hive_flutter/hive_flutter.dart';

class PosterCard extends ConsumerWidget {
  final Anime anime;
  final double width;
  final double height;
  final double radius;
  final double opacity;
  final bool highlighted;

  const PosterCard({
    super.key,
    required this.anime,
    required this.width,
    required this.height,
    this.radius = AppRadius.md,
    this.opacity = 1,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gradient = AppColors.cardGradients[anime.gradientIndex % AppColors.cardGradients.length];
    
    // Check if it's a new episode
    final newEpisodes = ref.watch(newEpisodesProvider).value ?? [];
    final isNewEpisode = newEpisodes.any((a) => a.id == anime.id);

    return BouncingButton(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => AnimeDetailsScreen(anime: anime)),
        );
      },
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(colors: gradient, begin: Alignment.topCenter, end: Alignment.bottomCenter),
            border: highlighted ? Border.all(color: AppColors.accentStart.withValues(alpha: 0.6), width: 1.5) : null,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20, offset: const Offset(0, 10))],
            image: anime.posterUrl != null
                ? DecorationImage(
                    image: NetworkImage(anime.posterUrl!), 
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                  )
                : null,
          ),
          child: Stack(
            children: [
              if (anime.posterUrl == null)
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Text(
                    anime.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: width > 150 ? 15 : 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (isNewEpisode)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accentStart,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'NEW',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(radius)),
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.black.withValues(alpha: 0.9)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Text(
                    anime.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: width > 150 ? 14 : 11,
                      fontWeight: FontWeight.w600,
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 2, offset: Offset(1, 1))
                      ],
                    ),
                  ),
                ),
              ),
              ValueListenableBuilder(
                valueListenable: Hive.box('watch_progress').listenable(keys: [anime.id]),
                builder: (context, _, __) {
                  final prog = LocalDbService.getProgress(anime.id);
                  if (prog != null) {
                    final epProgress = prog.episodes[prog.lastWatchedEpisode.toString()];
                    if (epProgress != null && epProgress.durationSeconds > 0) {
                      final percentage = (epProgress.positionSeconds / epProgress.durationSeconds).clamp(0.0, 1.0);
                      return Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: LinearProgressIndicator(
                          value: percentage,
                          backgroundColor: Colors.black54,
                          color: AppColors.accentStart,
                          minHeight: 4,
                        ),
                      );
                    }
                  }
                  return const SizedBox.shrink();
                }
              ),
            ],
          ),
        ),
      ),
    );
  }
}
