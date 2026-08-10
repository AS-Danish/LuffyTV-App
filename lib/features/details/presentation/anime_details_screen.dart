import 'package:flutter/material.dart';
import 'package:luffytv/core/theme/app_colors.dart';
import 'package:luffytv/features/home/data/models/anime.dart';
import 'package:luffytv/features/home/data/models/season.dart';
import 'package:luffytv/features/home/data/models/episode.dart';
import 'package:luffytv/core/widgets/bouncing_button.dart';

class AnimeDetailsScreen extends StatefulWidget {
  final Anime anime;
  const AnimeDetailsScreen({super.key, required this.anime});

  @override
  State<AnimeDetailsScreen> createState() => _AnimeDetailsScreenState();
}

class _AnimeDetailsScreenState extends State<AnimeDetailsScreen> {
  late Season _selectedSeason;

  @override
  void initState() {
    super.initState();
    _selectedSeason = widget.anime.seasons.isNotEmpty ? widget.anime.seasons.first : const Season(id: '', seasonNumber: 0, title: '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          // Hero Image AppBar
          SliverAppBar(
            expandedHeight: 350,
            pinned: true,
            backgroundColor: AppColors.bg,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (widget.anime.posterUrl != null)
                    Image.network(widget.anime.posterUrl!, fit: BoxFit.cover)
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: AppColors.cardGradients[widget.anime.gradientIndex % AppColors.cardGradients.length],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  // Bottom gradient fade
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, AppColors.bg],
                        stops: const [0.4, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Details content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  // Title
                  Text(widget.anime.title, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 12),
                  
                  // Metadata row
                  Row(
                    children: [
                      Text('${widget.anime.matchPercentage}% Match', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(width: 12),
                      Text(widget.anime.year.toString(), style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)),
                        child: Text(widget.anime.maturityRating, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ),
                      const SizedBox(width: 12),
                      Text('${widget.anime.seasons.length} Seasons', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(4)),
                        child: const Text('HD', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Play button
                  BouncingButton(
                    onTap: () {},
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: AppColors.accentGradient,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [BoxShadow(color: AppColors.accentStart.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.play_arrow, size: 28, color: Colors.white),
                            const SizedBox(width: 8),
                            const Text('Play', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Download button
                  BouncingButton(
                    onTap: () {},
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.download, size: 24, color: Colors.white),
                            const SizedBox(width: 8),
                            const Text('Download', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Description
                  Text(widget.anime.description, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4)),
                  const SizedBox(height: 12),
                  
                  // Cast & Creator
                  Text('Starring: ${widget.anime.cast.join(", ")}', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('Creator: ${widget.anime.creator}', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                  
                  const SizedBox(height: 24),
                  
                  // Action icons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionIcon(Icons.add, 'My List'),
                      _buildActionIcon(Icons.thumb_up_alt_outlined, 'Rate'),
                      _buildActionIcon(Icons.share, 'Share'),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 16),
                  
                  // Season selector
                  if (widget.anime.seasons.isNotEmpty)
                    DropdownButtonHideUnderline(
                      child: DropdownButton<Season>(
                        value: _selectedSeason,
                        dropdownColor: AppColors.surface,
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                        items: widget.anime.seasons.map((s) {
                          return DropdownMenuItem(
                            value: s,
                            child: Text(s.title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedSeason = val);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          // Episodes List
          if (widget.anime.seasons.isNotEmpty)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final ep = _selectedSeason.episodes[index];
                  return _buildEpisodeRow(ep);
                },
                childCount: _selectedSeason.episodes.length,
              ),
            )
          else
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildActionIcon(IconData icon, String label) {
    return BouncingButton(
      onTap: () {},
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildEpisodeRow(Episode ep) {
    return BouncingButton(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail
                Container(
                  width: 130,
                  height: 75,
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Center(
                    child: Icon(Icons.play_circle_outline, color: Colors.white, size: 32),
                  ),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${ep.episodeNumber}. ${ep.title}',
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Text('${ep.durationMinutes}m', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                    ],
                  ),
                ),
                // Download icon
                IconButton(
                  icon: const Icon(Icons.download_for_offline_outlined, color: Colors.white54),
                  onPressed: () {},
                )
              ],
            ),
            const SizedBox(height: 8),
            Text(
              ep.description,
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
