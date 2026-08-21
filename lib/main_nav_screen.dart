import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luffytv/features/home/presentation/home_screen.dart';
import 'package:luffytv/features/search/presentation/search_screen.dart';
import 'package:luffytv/features/favorites/presentation/favorites_screen.dart';
import 'package:luffytv/features/profile/presentation/profile_screen.dart';
import 'package:luffytv/core/widgets/floating_nav.dart';
import 'package:luffytv/features/home/providers/anime_providers.dart';

class MainNavScreen extends ConsumerWidget {
  const MainNavScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navIndex = ref.watch(selectedNavIndexProvider);

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          IndexedStack(
            index: navIndex,
            children: const [
              HomeScreen(),
              SearchScreen(),
              FavoritesScreen(),
              ProfileScreen(),
            ],
          ),
          const Positioned(left: 0, right: 0, bottom: 0, child: FloatingNav()),
        ],
      ),
    );
  }
}
