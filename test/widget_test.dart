import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:thulium/l10n/generated/app_localizations.dart';
import 'package:thulium_auth/thulium_auth.dart';

import 'package:thulium/app.dart';
import 'package:thulium/pages/settings_page.dart';

void main() {
  testWidgets('shows the Thulium welcome page', (tester) async {
    await tester.pumpWidget(ThuliumApp(sessionStore: MemoryAuthSessionStore()));
    await tester.pumpAndSettle();

    expect(find.text('Welcome, THUer'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
  });

  testWidgets('restores the authenticated home without a startup probe', (
    tester,
  ) async {
    final store = MemoryAuthSessionStore();
    await store.write(_savedSession());

    await tester.pumpWidget(ThuliumApp(sessionStore: store));
    await tester.pumpAndSettle();

    expect(find.text('Student events'), findsOneWidget);
    expect(find.text('Welcome, THUer'), findsNothing);
  });

  testWidgets('opens settings from the authenticated home', (tester) async {
    final store = MemoryAuthSessionStore();
    await store.write(_savedSession());

    await tester.pumpWidget(ThuliumApp(sessionStore: store));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);
  });

  testWidgets('returns to the welcome route after logout succeeds', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: [
          ...AppLocalizations.localizationsDelegates,
          ...FLocalizations.localizationsDelegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => FTheme(
          data: FThemes.neutral.light.touch,
          child: child ?? const SizedBox.shrink(),
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: const Text('Welcome, THUer'),
            floatingActionButton: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SettingsPage(onLogout: () async => true),
                ),
              ),
              child: const Text('Open settings'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome, THUer'), findsOneWidget);
    expect(find.text('Log out'), findsNothing);
  });
}

AuthSession _savedSession() =>
    const AuthSession(userId: '2022012050', fingerprint: 'test', cookies: {});
