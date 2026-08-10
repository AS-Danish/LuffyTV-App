import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luffytv/core/theme/app_colors.dart';
import 'package:luffytv/core/theme/app_theme.dart';
import 'package:luffytv/features/home/providers/anime_providers.dart';
import 'package:luffytv/core/widgets/poster_card.dart';
import 'package:luffytv/features/details/presentation/anime_details_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use allAnimeProvider for comprehensive search
    final mockResults = ref.watch(allAnimeProvider);

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
                  onChanged: (val) {
                    setState(() {
                      _isSearching = val.isNotEmpty;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search anime, movies, genres...',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                    prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.5)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white70),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _isSearching = false;
                              });
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
                  child: mockResults.when(
                    loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accentStart)),
                    error: (err, _) => Center(child: Text('Error loading results', style: AppTextStyles.body)),
                    data: (animes) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            child: Text('Top Searches', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          ),
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.only(bottom: 120),
                              itemCount: animes.take(5).length,
                              itemBuilder: (context, index) {
                                final anime = animes[index];
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                  leading: Container(
                                    width: 130,
                                    height: 75,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4),
                                      gradient: anime.posterUrl == null ? LinearGradient(
                                        colors: AppColors.cardGradients[anime.gradientIndex % AppColors.cardGradients.length],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ) : null,
                                      image: anime.posterUrl != null ? DecorationImage(image: NetworkImage(anime.posterUrl!), fit: BoxFit.cover) : null,
                                    ),
                                  ),
                                  title: Text(anime.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                  trailing: const Icon(Icons.play_circle_outline, color: Colors.white, size: 32),
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(builder: (context) => AnimeDetailsScreen(anime: anime)),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                )
              else
                Expanded(
                  child: mockResults.when(
                    loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accentStart)),
                    error: (err, _) => Center(child: Text('Error loading results', style: AppTextStyles.body)),
                    data: (animes) {
                      final searchTerm = _searchController.text.trim().toLowerCase();
                      final filtered = animes.where((a) => a.title.toLowerCase().contains(searchTerm) || a.genre.toLowerCase().contains(searchTerm)).toList();

                      if (filtered.isEmpty) {
                        return Center(
                          child: Text("No results found for '${_searchController.text}'", style: const TextStyle(color: Colors.white54, fontSize: 16)),
                        );
                      }

                      if (filtered.length == 1) {
                        return ListView.builder(
                          padding: const EdgeInsets.only(bottom: 120, top: 16),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final anime = filtered[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              leading: Container(
                                width: 130,
                                height: 75,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  gradient: anime.posterUrl == null ? LinearGradient(
                                    colors: AppColors.cardGradients[anime.gradientIndex % AppColors.cardGradients.length],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ) : null,
                                  image: anime.posterUrl != null ? DecorationImage(image: NetworkImage(anime.posterUrl!), fit: BoxFit.cover) : null,
                                ),
                              ),
                              title: Text(anime.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                              subtitle: Text('${anime.year} • ${anime.genre}', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                              trailing: const Icon(Icons.play_circle_outline, color: Colors.white, size: 32),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (context) => AnimeDetailsScreen(anime: anime)),
                                );
                              },
                            );
                          },
                        );
                      }

                      // Multiple matches: show Grid (like Netflix)
                      return GridView.builder(
                        padding: const EdgeInsets.only(left: 12, right: 12, bottom: 120, top: 16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.65,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final anime = filtered[index];
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
