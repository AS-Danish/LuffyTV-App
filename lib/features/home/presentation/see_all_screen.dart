import 'package:flutter/material.dart';
import 'package:luffytv/core/theme/app_colors.dart';
import 'package:luffytv/core/theme/app_theme.dart';
import 'package:luffytv/features/home/data/models/anime.dart';
import 'package:luffytv/core/widgets/poster_card.dart';

class SeeAllScreen extends StatelessWidget {
  final String title;
  final List<Anime> animes;

  const SeeAllScreen({
    super.key,
    required this.title,
    required this.animes,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(title, style: AppTextStyles.heroTitle.copyWith(fontSize: 20)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.65,
          crossAxisSpacing: 12,
          mainAxisSpacing: 16,
        ),
        itemCount: animes.length,
        itemBuilder: (context, index) {
          return PosterCard(
            anime: animes[index],
            width: double.infinity,
            height: double.infinity,
          );
        },
      ),
    );
  }
}
