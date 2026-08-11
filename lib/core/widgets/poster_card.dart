import 'package:flutter/material.dart';
import 'package:luffytv/core/theme/app_colors.dart';
import 'package:luffytv/core/theme/app_theme.dart';
import 'package:luffytv/features/home/data/models/anime.dart';
import 'package:luffytv/features/details/presentation/anime_details_screen.dart';
import 'package:luffytv/core/widgets/bouncing_button.dart';

/// One card, one job: render an Anime as a poster. Used for both the
/// hero carousel and horizontal rows — sizing is passed in, not
/// hardcoded, which is what makes it responsive-friendly.
class PosterCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final gradient = AppColors.cardGradients[anime.gradientIndex % AppColors.cardGradients.length];

    return BouncingButton(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => AnimeDetailsScreen(anime: anime)),
        );
      },
      child: Opacity(
        opacity: opacity,
        child: GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => AnimeDetailsScreen(anime: anime)),
            );
          },
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
              ],
            ),
        ),
      ),
    ));
  }
}
