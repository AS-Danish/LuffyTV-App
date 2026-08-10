import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:luffytv/core/theme/app_colors.dart';
import 'package:luffytv/core/theme/app_theme.dart';
import 'package:luffytv/core/utils/responsive.dart';
import 'package:luffytv/features/home/providers/anime_providers.dart';
import 'poster_card.dart';

class HeroSection extends ConsumerStatefulWidget {
  const HeroSection({super.key});

  @override
  ConsumerState<HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends ConsumerState<HeroSection> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // We use editorsPicksProvider for the carousel instead of a single featured item.
    final editorsPicks = ref.watch(editorsPicksProvider);
    final r = Responsive.of(context);

    return editorsPicks.when(
      loading: () => SizedBox(
        height: r.heroCardHeight + 100,
        child: const Center(child: CircularProgressIndicator(color: AppColors.accentStart)),
      ),
      error: (err, _) => SizedBox(
        height: 120,
        child: Center(child: Text('Couldn\'t load featured titles', style: AppTextStyles.body)),
      ),
      data: (animes) {
        if (animes.isEmpty) return const SizedBox();
        final currentAnime = animes[_currentIndex];
        
        return Column(
          children: [
            CarouselSlider.builder(
              itemCount: animes.length,
              options: CarouselOptions(
                height: r.heroCardHeight,
                enlargeCenterPage: true,
                enlargeFactor: 0.22, // Makes side cards slightly larger to reduce gap
                viewportFraction: 0.55, // Lower fraction brings cards closer together
                enableInfiniteScroll: true,
                onPageChanged: (index, reason) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
              ),
              itemBuilder: (context, index, realIndex) {
                final anime = animes[index];
                return PosterCard(
                  anime: anime,
                  width: r.heroCardWidth,
                  height: r.heroCardHeight,
                  radius: AppRadius.lg,
                  highlighted: index == _currentIndex,
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
            Text(currentAnime.title, style: AppTextStyles.heroTitle, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xs),
            Text('${currentAnime.year}  •  ${currentAnime.genre}', style: AppTextStyles.body),
            const SizedBox(height: AppSpacing.md),
            _ActionButtons(),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: animes.asMap().entries.map((entry) {
                return Container(
                  width: 8.0,
                  height: 8.0,
                  margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentIndex == entry.key
                        ? AppColors.accentStart
                        : Colors.white.withValues(alpha: 0.2),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }
}

class _ActionButtons extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(width: 20),
        _buildActionIcon(Icons.add, 'My List'),
        const Spacer(),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            gradient: AppColors.accentGradient,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [BoxShadow(color: AppColors.accentStart.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.play_arrow, color: Colors.white, size: 28),
              const SizedBox(width: 4),
              Text('Play', style: AppTextStyles.button.copyWith(color: Colors.white, fontSize: 16)),
            ],
          ),
        ),
        const Spacer(),
        _buildActionIcon(Icons.info_outline, 'Info'),
        const SizedBox(width: 20),
      ],
    );
  }

  Widget _buildActionIcon(IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }
}
