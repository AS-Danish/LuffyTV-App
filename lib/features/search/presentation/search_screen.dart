import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luffytv/core/theme/app_colors.dart';
import 'package:luffytv/core/theme/app_theme.dart';
import 'package:luffytv/features/search/providers/search_providers.dart';
import 'package:luffytv/core/widgets/poster_card.dart';
import 'package:luffytv/core/services/local_db_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _isSearching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _isSearching = query.isNotEmpty;
      });
      if (query.trim().isNotEmpty) {
        LocalDbService.saveSearchQuery(query.trim());
      }
      ref.read(searchQueryProvider.notifier).state = query;
    });
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(searchAnimeProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search anime, movies, genres...',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                    prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.5)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white70),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              if (!_isSearching)
                Expanded(
                  child: ValueListenableBuilder(
                    valueListenable: Hive.box<List<String>>('recent_searches').listenable(),
                    builder: (context, Box<List<String>> box, _) {
                      final recentSearches = box.get('queries', defaultValue: <String>[])!;
                      
                      if (recentSearches.isEmpty) {
                        return const Center(
                          child: Text('Type to search...', style: TextStyle(color: Colors.white54, fontSize: 16)),
                        );
                      }
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Recent Searches', style: AppTextStyles.sectionTitle),
                                GestureDetector(
                                  onTap: LocalDbService.clearRecentSearches,
                                  child: const Text('Clear', style: TextStyle(color: AppColors.accentStart, fontSize: 14)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: recentSearches.map((query) {
                                return ActionChip(
                                  label: Text(query, style: const TextStyle(color: Colors.white)),
                                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                                  side: BorderSide.none,
                                  onPressed: () {
                                    _searchController.text = query;
                                    _onSearchChanged(query);
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                )
              else
                Expanded(
                  child: searchResults.when(
                    loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accentStart)),
                    error: (err, _) => Center(child: Text('Error loading results: $err', style: AppTextStyles.body)),
                    data: (animes) {
                      if (animes.isEmpty) {
                        return Center(
                          child: Text("No results found for '${_searchController.text}'", style: const TextStyle(color: Colors.white54, fontSize: 16)),
                        );
                      }

                      return GridView.builder(
                        padding: const EdgeInsets.only(left: 12, right: 12, bottom: 120, top: 16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.65,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
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
                                  radius: 8.0,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                anime.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
