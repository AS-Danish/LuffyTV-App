import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luffytv/core/services/local_db_service.dart';
import 'package:luffytv/core/theme/app_colors.dart';
import 'package:luffytv/core/theme/app_theme.dart';
import 'package:luffytv/core/utils/responsive.dart';
import 'package:luffytv/core/widgets/bouncing_button.dart';
import 'package:luffytv/features/details/presentation/anime_details_screen.dart';
import 'package:luffytv/features/home/data/models/anime.dart';
import 'package:luffytv/features/home/providers/anime_providers.dart';
import 'package:luffytv/features/player/presentation/video_player_screen.dart';

class HeroSection extends ConsumerStatefulWidget {
  const HeroSection({super.key});

  @override
  ConsumerState<HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends ConsumerState<HeroSection> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final picks = ref.watch(editorsPicksProvider);
    final responsive = Responsive.of(context);

    return picks.when(
      loading: () => Container(
        height: responsive.heroCardHeight,
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
      ),
      error: (_, _) => Container(
        height: 180,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.movie_filter_outlined,
              color: AppColors.textMuted,
              size: 34,
            ),
            const SizedBox(height: 10),
            Text(
              'Featured titles are taking a little longer',
              style: AppTextStyles.body,
            ),
          ],
        ),
      ),
      data: (animes) {
        if (animes.isEmpty) return const SizedBox.shrink();
        if (_currentIndex >= animes.length) _currentIndex = 0;
        return Column(
          children: [
            CarouselSlider.builder(
              itemCount: animes.length,
              options: CarouselOptions(
                height: responsive.heroCardHeight,
                viewportFraction: responsive.isMobile ? 1 : .88,
                enlargeCenterPage: !responsive.isMobile,
                enlargeFactor: .06,
                enableInfiniteScroll: animes.length > 1,
                onPageChanged: (index, _) =>
                    setState(() => _currentIndex = index),
              ),
              itemBuilder: (context, index, _) => Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: responsive.isMobile ? 0 : 8,
                ),
                child: _HeroCard(
                  anime: animes[index],
                  active: index == _currentIndex,
                ),
              ),
            ),
            if (animes.length > 1) ...[
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  animes.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    width: index == _currentIndex ? 28 : 7,
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: index == _currentIndex
                          ? AppColors.accentStart
                          : AppColors.border,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _HeroCard extends StatelessWidget {
  final Anime anime;
  final bool active;
  const _HeroCard({required this.anime, required this.active});

  @override
  Widget build(BuildContext context) {
    final gradient = AppColors
        .cardGradients[anime.gradientIndex % AppColors.cardGradients.length];
    return AnimatedScale(
      scale: active ? 1 : .985,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (anime.posterUrl != null)
                Image.network(
                  anime.posterUrl!,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0x11000000),
                      Color(0x33000000),
                      Color(0xF208090B),
                    ],
                    stops: [0, .38, 1],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withValues(alpha: .1)),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.accentStart,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'LUFFY TV SPOTLIGHT',
                          style: AppTextStyles.label.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      anime.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.display.copyWith(
                        fontSize: 31,
                        shadows: const [
                          Shadow(color: Colors.black, blurRadius: 24),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 5,
                      children: [
                        Text(
                          '${anime.matchPercentage}% match',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (anime.year > 0)
                          Text(
                            '${anime.year}',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        if (anime.genre.isNotEmpty)
                          Text(
                            anime.genre,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                    if (anime.description.isNotEmpty) ...[
                      const SizedBox(height: 9),
                      Text(
                        anime.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body.copyWith(
                          color: Colors.white.withValues(alpha: .78),
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _HeroActions(anime: anime),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroActions extends StatefulWidget {
  final Anime anime;
  const _HeroActions({required this.anime});

  @override
  State<_HeroActions> createState() => _HeroActionsState();
}

class _HeroActionsState extends State<_HeroActions> {
  late bool _isInMyList;

  @override
  void initState() {
    super.initState();
    _isInMyList = LocalDbService.isInMyList(widget.anime.id);
  }

  @override
  void didUpdateWidget(covariant _HeroActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.anime.id != widget.anime.id) {
      _isInMyList = LocalDbService.isInMyList(widget.anime.id);
    }
  }

  void _toggleList() {
    setState(() => _isInMyList = !_isInMyList);
    if (_isInMyList) {
      LocalDbService.addToMyList(widget.anime);
    } else {
      LocalDbService.removeFromMyList(widget.anime.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: BouncingButton(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => VideoPlayerScreen(
                  animeTitle: widget.anime.title,
                  animeSlug: widget.anime.id,
                  episodeNumber: 1,
                  anime: widget.anime,
                ),
              ),
            ),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentStart.withValues(alpha: .25),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.play_arrow_rounded, color: Colors.white),
                    const SizedBox(width: 5),
                    Text('Watch now', style: AppTextStyles.button),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 9),
        _HeroIconButton(
          icon: _isInMyList ? Icons.check_rounded : Icons.add_rounded,
          label: _isInMyList ? 'Saved' : 'Add to My List',
          onTap: _toggleList,
        ),
        const SizedBox(width: 9),
        _HeroIconButton(
          icon: Icons.info_outline_rounded,
          label: 'More information',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AnimeDetailsScreen(anime: widget.anime),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _HeroIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: label,
      onPressed: onTap,
      style: IconButton.styleFrom(
        fixedSize: const Size(48, 48),
        backgroundColor: Colors.white.withValues(alpha: .1),
        side: BorderSide(color: Colors.white.withValues(alpha: .16)),
      ),
      icon: Icon(icon, color: Colors.white, size: 21),
    );
  }
}
