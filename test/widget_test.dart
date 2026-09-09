import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luffytv/core/theme/app_theme.dart';
import 'package:luffytv/core/widgets/floating_nav.dart';
import 'package:luffytv/features/profile/presentation/downloads_screen.dart';
import 'package:luffytv/features/home/providers/anime_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('primary navigation exposes every app destination', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: Stack(
              children: [
                SizedBox.expand(),
                Positioned(left: 0, right: 0, bottom: 0, child: FloatingNav()),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('My List'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.text('Search')),
    );
    expect(container.read(selectedNavIndexProvider), 1);
  });

  testWidgets('offline library reassures the user and hides navigation back', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const DownloadsScreen(offlineMode: true),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Your offline library'), findsOneWidget);
    expect(find.textContaining("You're offline"), findsOneWidget);
    expect(find.textContaining("Here's your downloaded anime"), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsNothing);
  });
}
