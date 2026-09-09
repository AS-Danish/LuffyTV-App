import 'local_db_service.dart';

/// Resolve against published episode numbers, including gaps and finales.
({int episode, bool resume})? episodeResume(
  Iterable<int> available,
  WatchProgress? progress,
) {
  final numbers = available.where((n) => n > 0).toSet().toList()..sort();
  if (numbers.isEmpty) return null;
  final last = progress?.lastWatchedEpisode;
  if (last == null || !numbers.contains(last)) {
    return (episode: numbers.first, resume: false);
  }
  final saved = progress!.episodes['$last'];
  if (saved?.isCompleted == true) {
    return (
      episode: numbers.where((n) => n > last).firstOrNull ?? last,
      resume: false,
    );
  }
  return (episode: last, resume: (saved?.positionSeconds ?? 0) > 0);
}
