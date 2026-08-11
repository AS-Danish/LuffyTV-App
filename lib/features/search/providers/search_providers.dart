import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:luffytv/features/home/providers/anime_providers.dart';
import 'package:luffytv/features/home/data/models/anime.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchAnimeProvider = FutureProvider<List<Anime>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) {
    return [];
  }
  return ref.watch(animeRepositoryProvider).searchAnime(query);
});
