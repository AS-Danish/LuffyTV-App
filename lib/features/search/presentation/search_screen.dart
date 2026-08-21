import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:luffytv/core/services/local_db_service.dart';
import 'package:luffytv/core/theme/app_colors.dart';
import 'package:luffytv/core/theme/app_theme.dart';
import 'package:luffytv/core/utils/responsive.dart';
import 'package:luffytv/core/widgets/poster_card.dart';
import 'package:luffytv/features/home/data/models/anime.dart';
import 'package:luffytv/features/search/providers/search_providers.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounce;
  bool _isSearching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    final normalized = query.trim();
    setState(() => _isSearching = normalized.isNotEmpty);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (normalized.length >= 2) LocalDbService.saveSearchQuery(normalized);
      ref.read(searchQueryProvider.notifier).state = normalized;
    });
  }

  void _useQuery(String query) {
    _searchController.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    _onSearchChanged(query);
    _searchFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchAnimeProvider);
    final responsive = Responsive.of(context);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  responsive.screenPadding,
                  24,
                  responsive.screenPadding,
                  16,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 920),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Discover',
                          style: AppTextStyles.label.copyWith(
                            color: AppColors.accentEnd,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'What are you in the mood for?',
                          style: AppTextStyles.heroTitle,
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: _searchController,
                          focusNode: _searchFocus,
                          textInputAction: TextInputAction.search,
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                          ),
                          onChanged: _onSearchChanged,
                          decoration: InputDecoration(
                            hintText: 'Search titles, genres, or moods',
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: AppColors.textMuted,
                            ),
                            suffixIcon: _isSearching
                                ? IconButton(
                                    tooltip: 'Clear search',
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      color: AppColors.textSecondary,
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      _onSearchChanged('');
                                      _searchFocus.requestFocus();
                                    },
                                  )
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _isSearching
                      ? _SearchResults(
                          results: results,
                          responsive: responsive,
                          query: _searchController.text,
                        )
                      : _SearchLanding(
                          responsive: responsive,
                          onQuerySelected: _useQuery,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchLanding extends StatelessWidget {
  final Responsive responsive;
  final ValueChanged<String> onQuerySelected;
  const _SearchLanding({
    required this.responsive,
    required this.onQuerySelected,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box<List<String>>('recent_searches').listenable(),
      builder: (context, Box<List<String>> box, _) {
        final recent = box.get('queries', defaultValue: <String>[])!;
        const suggestions = [
          'Action',
          'Romance',
          'Dark fantasy',
          'Comedy',
          'Isekai',
          'Sports',
        ];
        return ListView(
          key: const ValueKey('search-landing'),
          padding: EdgeInsets.fromLTRB(
            responsive.screenPadding,
            12,
            responsive.screenPadding,
            130,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Explore a vibe', style: AppTextStyles.sectionTitle),
                    const SizedBox(height: 13),
                    Wrap(
                      spacing: 9,
                      runSpacing: 9,
                      children: suggestions
                          .map(
                            (query) => ActionChip(
                              avatar: const Icon(
                                Icons.auto_awesome_rounded,
                                size: 15,
                                color: AppColors.accentEnd,
                              ),
                              label: Text(query),
                              onPressed: () => onQuerySelected(query),
                            ),
                          )
                          .toList(),
                    ),
                    if (recent.isNotEmpty) ...[
                      const SizedBox(height: 36),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Recent searches',
                              style: AppTextStyles.sectionTitle,
                            ),
                          ),
                          TextButton(
                            onPressed: LocalDbService.clearRecentSearches,
                            child: const Text('Clear all'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...recent.map(
                        (query) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.history_rounded,
                            color: AppColors.textMuted,
                          ),
                          title: Text(
                            query,
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.north_west_rounded,
                            color: AppColors.textMuted,
                            size: 18,
                          ),
                          onTap: () => onQuerySelected(query),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SearchResults extends StatelessWidget {
  final AsyncValue<List<Anime>> results;
  final Responsive responsive;
  final String query;
  const _SearchResults({
    required this.results,
    required this.responsive,
    required this.query,
  });

  @override
  Widget build(BuildContext context) {
    return results.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _SearchMessage(
        icon: Icons.cloud_off_outlined,
        title: 'Search is temporarily unavailable',
        message: 'Check your connection and try again.',
      ),
      data: (animes) {
        if (animes.isEmpty) {
          return _SearchMessage(
            icon: Icons.search_off_rounded,
            title: 'No matches for “$query”',
            message: 'Try a shorter title or a broader genre.',
          );
        }
        return GridView.builder(
          key: ValueKey('results-$query'),
          padding: EdgeInsets.fromLTRB(
            responsive.screenPadding,
            10,
            responsive.screenPadding,
            130,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: responsive.gridColumns,
            childAspectRatio: .57,
            crossAxisSpacing: 12,
            mainAxisSpacing: 18,
          ),
          itemCount: animes.length,
          itemBuilder: (context, index) {
            final anime = animes[index];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: PosterCard(
                    anime: anime,
                    width: double.infinity,
                    height: double.infinity,
                    radius: AppRadius.md,
                    showTitleOverlay: false,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  anime.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.cardTitle,
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (anime.year > 0) '${anime.year}',
                    if (anime.genre.isNotEmpty) anime.genre,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(fontSize: 10),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _SearchMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const _SearchMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 20, 32, 120),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.surfaceRaised,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.textMuted, size: 29),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.sectionTitle,
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.body,
            ),
          ],
        ),
      ),
    );
  }
}
