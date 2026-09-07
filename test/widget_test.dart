import 'package:bazaar/app.dart';
import 'package:bazaar/core/providers/database_provider.dart';
import 'package:bazaar/core/providers/settings_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'database_test.dart' show createTestDatabase;

/// Smoke test: the app boots into the onboarding screen with an empty
/// local database and no user.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  testWidgets('app boots to the username screen', (tester) async {
    final db = createTestDatabase();
    addTearDown(db.close);
    final sp = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: ProviderContainer(overrides: [
          sharedPreferencesProvider.overrideWithValue(sp),
          databaseProvider.overrideWithValue(db),
        ]),
        child: const BazaarApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.byIcon(Icons.shopping_basket_rounded), findsOneWidget);
  });

  testWidgets('completing onboarding lands on Home', (tester) async {
    final db = createTestDatabase();
    addTearDown(db.close);
    final sp = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: ProviderContainer(overrides: [
          sharedPreferencesProvider.overrideWithValue(sp),
          databaseProvider.overrideWithValue(db),
        ]),
        child: const BazaarApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'Wissam');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    // Home screen shows the greeting that includes the username.
    final texts = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList();
    // ignore: avoid_print
    print('TEXTS: ' + texts.join(' | '));
    expect(find.textContaining('Wissam'), findsOneWidget);
  });
}
