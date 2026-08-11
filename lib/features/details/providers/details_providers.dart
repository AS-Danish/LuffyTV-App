import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luffytv/features/home/providers/anime_providers.dart';
import 'package:luffytv/features/details/data/models/anime_detail.dart';
import 'package:luffytv/features/home/data/models/episode.dart';

final animeDetailProvider = FutureProvider.family<AnimeDetail, String>((ref, slug) {
  return ref.watch(animeRepositoryProvider).fetchAnimeDetails(slug);
});

final animeEpisodesProvider = FutureProvider.family<List<Episode>, String>((ref, slug) {
  return ref.watch(animeRepositoryProvider).fetchAnimeEpisodes(slug);
});
