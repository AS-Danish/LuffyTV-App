import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:luffytv/core/theme/app_colors.dart';
import 'package:luffytv/core/theme/app_theme.dart';
import 'package:luffytv/core/utils/responsive.dart';
import 'package:luffytv/features/home/providers/anime_providers.dart';
import 'package:luffytv/core/widgets/bouncing_button.dart';
import '../../features/details/presentation/anime_details_screen.dart';
import '../../features/home/data/models/anime.dart';
import '../../features/player/presentation/video_player_screen.dart';
import '../../core/services/local_db_service.dart';
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
            _ActionButtons(currentAnime: currentAnime),
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

class _ActionButtons extends StatefulWidget {
  final Anime currentAnime;
  const _ActionButtons({required this.currentAnime});

  @override
  State<_ActionButtons> createState() => _ActionButtonsState();
}

class _ActionButtonsState extends State<_ActionButtons> {
  late bool _isInMyList;

  @override
  void initState() {
    super.initState();
    _checkMyList();
  }

  @override
  void didUpdateWidget(covariant _ActionButtons oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentAnime.id != widget.currentAnime.id) {
      _checkMyList();
    }
  }

  void _checkMyList() {
    _isInMyList = LocalDbService.isInMyList(widget.currentAnime.id);
  }

  void _toggleMyList() {
    setState(() {
      _isInMyList = !_isInMyList;
    });
    if (_isInMyList) {
      LocalDbService.addToMyList(widget.currentAnime);
    } else {
      LocalDbService.removeFromMyList(widget.currentAnime.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(width: 20),
        _buildActionIcon(_isInMyList ? Icons.check : Icons.add, 'My List', onTap: _toggleMyList),
        const Spacer(),
        BouncingButton(
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => VideoPlayerScreen(
                animeTitle: widget.currentAnime.title,
                animeSlug: widget.currentAnime.id,
                episodeNumber: 1,
                anime: widget.currentAnime,
              ),
            ));
          },
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              gradient: AppColors.accentGradient,
              borderRadius: BorderRadius.circular(999),
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
        ),
        const Spacer(),
        _buildActionIcon(Icons.info_outline, 'Info', onTap: () {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => AnimeDetailsScreen(anime: widget.currentAnime)));
        }),
        const SizedBox(width: 20),
      ],
    );
  }

  Widget _buildActionIcon(IconData icon, String label, {required VoidCallback onTap}) {
    return BouncingButton(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }
}
