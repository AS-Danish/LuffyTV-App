import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luffytv/core/theme/app_colors.dart';
import 'package:luffytv/core/theme/app_theme.dart';
import 'package:luffytv/core/widgets/poster_card.dart';
import 'package:luffytv/core/services/local_db_service.dart';
import 'package:luffytv/features/home/data/models/anime.dart';
import 'package:hive_flutter/hive_flutter.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 16, 12, 12),
                child: Text('My List', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: ValueListenableBuilder(
                  valueListenable: Hive.box('my_list').listenable(),
                  builder: (context, box, _) {
                    final favorites = LocalDbService.getMyList();
                    if (favorites.isEmpty) {
                      return Center(child: Text('No favorites yet', style: AppTextStyles.body));
                    }
                    return GridView.builder(
                      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 120),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.65,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: favorites.length,
                      itemBuilder: (context, index) {
                        final anime = favorites[index];
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
                  }
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

