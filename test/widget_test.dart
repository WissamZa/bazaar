import 'package:bazaar/app.dart';
import 'package:bazaar/core/providers/database_provider.dart';
import 'package:bazaar/core/providers/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'database_test.dart' show createTestDatabase;

/// Smoke test: the app boots into the onboarding screen with an empty local
/// database and no user, and completing it reaches Home.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  Future<void> boot(WidgetTester tester) async {
    final db = createTestDatabase();
    final sp = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(sp),
      databaseProvider.overrideWithValue(db),
    ]);
    // Dispose the container (tears down drift stream subscriptions) before
    // closing the database, otherwise the test isolate never quiesces.
    addTearDown(() async {
      container.dispose();
      await db.close();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const BazaarApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('app boots to the username screen', (tester) async {
    await boot(tester);

    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.byIcon(Icons.shopping_basket_rounded), findsOneWidget);
  });

  testWidgets('completing onboarding lands on Home', (tester) async {
    await boot(tester);

    await tester.enterText(find.byType(TextFormField), 'Wissam');
    await tester.tap(find.byType(FilledButton));
    // Bounded pumps rather than pumpAndSettle: Home hosts live DB streams
    // that need a few frames to resolve.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.textContaining('Wissam'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
