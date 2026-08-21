import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luffytv/core/theme/app_theme.dart';
import 'package:luffytv/core/widgets/floating_nav.dart';
import 'package:luffytv/features/home/providers/anime_providers.dart';

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
    expect(find.text('Discover'), findsOneWidget);
    expect(find.text('My List'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    await tester.tap(find.text('Discover'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.text('Discover')),
    );
    expect(container.read(selectedNavIndexProvider), 1);
  });
}
