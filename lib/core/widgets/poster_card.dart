import 'package:flutter/material.dart';
import 'package:luffytv/core/theme/app_colors.dart';
import 'package:luffytv/core/theme/app_theme.dart';
import 'package:luffytv/features/home/data/models/anime.dart';

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

    return Opacity(
      opacity: opacity,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(colors: gradient, begin: Alignment.topCenter, end: Alignment.bottomCenter),
          border: highlighted ? Border.all(color: AppColors.accentStart.withOpacity(0.6), width: 1.5) : null,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 10))],
          image: anime.posterUrl != null
              ? DecorationImage(image: NetworkImage(anime.posterUrl!), fit: BoxFit.cover)
              : null,
        ),
        child: Stack(
          children: [
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Text(
                anime.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: width > 150 ? 15 : 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: height * 0.35,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(radius)),
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
