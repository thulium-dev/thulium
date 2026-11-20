import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:forui/forui.dart';
import 'package:thulium/l10n/generated/app_localizations.dart';
import 'package:thulium_auth/thulium_auth.dart';

import 'package:thulium/app.dart';
import 'package:thulium/pages/settings_page.dart';
import 'package:thulium/pages/study_page.dart';
import 'package:thulium/widgets/language_button.dart';

void main() {
  testWidgets(
    'background verification keeps the home until sign in is requested',
    (tester) async {
      final store = _VerificationRequiredStore(_savedSession());
      await tester.pumpWidget(ThuliumApp(sessionStore: store));
      await tester.pumpAndSettle();

      expect(find.text('Upcoming assignments'), findsOneWidget);
      expect(find.text('Welcome, THUer'), findsNothing);
      expect(
        find.textContaining('Verification is required to refresh campus data.'),
        findsOneWidget,
      );
      expect(store.clears, 0);
      expect(store.saved, isNotNull);

      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome, THUer'), findsOneWidget);
      expect(store.clears, 0);
    },
  );

  testWidgets('shows the Thulium welcome page', (tester) async {
    await tester.pumpWidget(ThuliumApp(sessionStore: MemoryAuthSessionStore()));
    await tester.pumpAndSettle();

    expect(find.text('Welcome, THUer'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
  });

  testWidgets('restores the home while courses load in the background', (
    tester,
  ) async {
    final store = MemoryAuthSessionStore();
    await store.write(_savedSession());

    await tester.pumpWidget(ThuliumApp(sessionStore: store));
    await tester.pumpAndSettle();

    expect(find.text('Upcoming assignments'), findsOneWidget);
    expect(find.text('Welcome, THUer'), findsNothing);
  });

  testWidgets('opens the Study course list from the bottom navigation', (
    tester,
  ) async {
    final store = MemoryAuthSessionStore();
    await store.write(_savedSession());

    await tester.pumpWidget(ThuliumApp(sessionStore: store));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await tester.pumpAndSettle();

    expect(find.byType(StudyPage), findsOneWidget);
    expect(find.byKey(const ValueKey('study-shortcut-reserved')), findsNothing);
  });

  testWidgets('opens the assistant from the center tab', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final store = MemoryAuthSessionStore();
    await store.write(_savedSession());

    await tester.pumpWidget(ThuliumApp(sessionStore: store));
    await tester.pumpAndSettle();
    final tabs = find.byType(FBottomNavigationBarItem);
    expect(tabs, findsNWidgets(5));
    expect(
      find.descendant(of: tabs.at(2), matching: find.text('Assistant')),
      findsOneWidget,
    );
    await tester.tap(find.text('Assistant'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Configure model'));
    await tester.pumpAndSettle();
    expect(find.text('API key'), findsOneWidget);
    await tester.tap(find.text('Custom endpoint'));
    await tester.pumpAndSettle();

    expect(find.text('Base URL'), findsOneWidget);
    final fields = find.byType(EditableText);
    await tester.enterText(fields.at(0), 'https://gateway.example/v1');
    await tester.enterText(fields.at(2), 'test-model');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save configuration'));
    await tester.pumpAndSettle();
    expect(find.byType(FDialog), findsNothing);

    final saved = await const FlutterSecureStorage().read(
      key: 'thulium.assistant.v1.${_savedSession().userId}.credentials',
    );
    expect(saved, contains('"baseUrl":"https://gateway.example/v1"'));
    expect(saved, contains('"key":""'));
    // Pinned Forui text fields hit Flutter's merged-semantics assertion when
    // controls change during widget tests. This test exercises the save flow.
  }, semanticsEnabled: false);

  testWidgets('opens settings from the authenticated home', (tester) async {
    final store = MemoryAuthSessionStore();
    await store.write(_savedSession());

    await tester.pumpWidget(ThuliumApp(sessionStore: store));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);
  });

  testWidgets('uses a compact authenticated header without shrinking menus', (
    tester,
  ) async {
    final store = MemoryAuthSessionStore();
    await store.write(_savedSession());

    await tester.pumpWidget(ThuliumApp(sessionStore: store));
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byType(LanguageButton)),
      Size.square(FThemes.neutral.light.touch.style.sizes.tile),
    );
    expect(
      tester.getSize(find.bySemanticsLabel('Theme')),
      Size.square(FThemes.neutral.light.touch.style.sizes.tile),
    );
    expect(
      tester.getSize(find.bySemanticsLabel('Settings')),
      Size.square(FThemes.neutral.light.touch.style.sizes.tile),
    );

    await tester.tap(find.byType(LanguageButton));
    await tester.pumpAndSettle();
    expect(find.text('English'), findsOneWidget);
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

/// The first restore succeeds. A subsequent background operation requires
/// interactive verification, reproducing the home-to-welcome regression.
class _VerificationRequiredStore implements AuthSessionStore {
  _VerificationRequiredStore(this.saved);
  AuthSession? saved;
  int _reads = 0;
  int clears = 0;

  @override
  Future<AuthSession?> read() async {
    if (++_reads > 1) throw const TwoFactorInteractionRequired();
    return saved;
  }

  @override
  Future<void> write(AuthSession session) async => saved = session;

  @override
  Future<void> clear() async {
    clears++;
    saved = null;
  }
}
