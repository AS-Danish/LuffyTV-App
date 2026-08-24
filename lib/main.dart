import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:luffytv/core/theme/app_theme.dart';
import 'package:luffytv/main_nav_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:luffytv/core/services/local_db_service.dart';
import 'package:luffytv/core/widgets/cached_artwork_image.dart';
import 'package:luffytv/core/widgets/app_version_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  await LocalDbService.init();

  PaintingBinding.instance.imageCache.maximumSize = 800;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 96 * 1024 * 1024;
  final savedAnime = [
    ...LocalDbService.getMyList(),
    ...LocalDbService.getAllProgress().map((progress) => progress.anime),
  ];

  try {
    await dotenv.load(fileName: ".env");
    final supabaseUrl = dotenv.env['SUPABASE_URL']?.trim() ?? '';
    final supabaseKey = dotenv.env['SUPABASE_ANNON_KEY']?.trim() ?? '';
    if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
      await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Failed to initialize optional Supabase services: $e');
    }
  }

  runApp(const ProviderScope(child: MyApp()));
  unawaited(ArtworkCache.prefetch(savedAnime.map((anime) => anime.posterUrl)));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Luffy TV',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        physics: const BouncingScrollPhysics(),
      ),
      home: const AppVersionGate(child: MainNavScreen()),
    );
  }
}
