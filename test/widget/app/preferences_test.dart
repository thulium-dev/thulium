import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:thulium/app.dart';
import 'package:thulium/pages/home_page.dart';
import 'package:thulium/pages/welcome_page.dart';
import 'package:thulium/preferences/app_preferences_store.dart';
import 'package:thulium/widgets/language_button.dart';
import 'package:thulium_auth/thulium_auth.dart';

void main() {
  setUp(() {
    final original = SharedPreferencesAsyncPlatform.instance;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    addTearDown(() => SharedPreferencesAsyncPlatform.instance = original);
  });
  for (final locale in [
    const Locale('en'),
    const Locale('zh', 'CN'),
    const Locale('zh', 'TW'),
  ]) {
    testWidgets('restores theme and $locale after rebuilding the app', (
      tester,
    ) async {
      final preferences = LocalAppPreferencesStore();
      final session = MemoryAuthSessionStore();
      await tester.pumpWidget(
        ThuliumApp(
          sessionStore: session,
          preferencesStore: LocalAppPreferencesStore(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Theme'));
      tester
          .widget<LanguageButton>(find.byType(LanguageButton))
          .onSelected(locale);
      await tester.pumpAndSettle();
      expect(_app(tester).themeMode, ThemeMode.dark);
      expect(_app(tester).locale, locale);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        ThuliumApp(sessionStore: session, preferencesStore: preferences),
      );
      await tester.pumpAndSettle();
      expect(_app(tester).themeMode, ThemeMode.dark);
      expect(_app(tester).locale, locale);
      expect(find.byType(WelcomePage), findsOneWidget);
    });
  }

  testWidgets('an explicit light theme overrides a dark system after restart', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final preferences = LocalAppPreferencesStore();
    final session = MemoryAuthSessionStore();
    await tester.pumpWidget(
      ThuliumApp(sessionStore: session, preferencesStore: preferences),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Theme'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      ThuliumApp(sessionStore: session, preferencesStore: preferences),
    );
    await tester.pumpAndSettle();
    expect(_app(tester).themeMode, ThemeMode.light);
  });

  testWidgets('logout retains installation theme and language', (tester) async {
    final preferences = LocalAppPreferencesStore();
    await preferences.write(
      const AppPreferences(
        themeMode: ThemeMode.dark,
        locale: Locale('zh', 'TW'),
      ),
    );
    final session = MemoryAuthSessionStore();
    await session.write(
      const AuthSession(userId: '1234567890', fingerprint: 'test', cookies: {}),
    );
    await tester.pumpWidget(
      ThuliumApp(sessionStore: session, preferencesStore: preferences),
    );
    await tester.pumpAndSettle();
    expect(
      await tester.widget<HomePage>(find.byType(HomePage)).onLogout(),
      isTrue,
    );
    await tester.pumpAndSettle();
    expect(find.byType(WelcomePage), findsOneWidget);
    final retained = await LocalAppPreferencesStore().read();
    expect(retained.themeMode, ThemeMode.dark);
    expect(retained.locale, const Locale('zh', 'TW'));
  });

  testWidgets('waits for saved preferences before showing welcome content', (
    tester,
  ) async {
    final loaded = Completer<AppPreferences>();
    final preferences = _PreferencesStore()..pendingRead = loaded;
    await tester.pumpWidget(
      ThuliumApp(
        sessionStore: MemoryAuthSessionStore(),
        preferencesStore: preferences,
      ),
    );
    await tester.pump();
    expect(find.byType(WelcomePage), findsNothing);
    loaded.complete(
      const AppPreferences(
        themeMode: ThemeMode.dark,
        locale: Locale('zh', 'TW'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(WelcomePage), findsOneWidget);
    expect(_app(tester).themeMode, ThemeMode.dark);
    expect(_app(tester).locale, const Locale('zh', 'TW'));
  });

  testWidgets(
    'read failure falls back to defaults and a failed write does not block later choices',
    (tester) async {
      final preferences = _PreferencesStore()
        ..failRead = true
        ..failNextWrite = true;
      await tester.pumpWidget(
        ThuliumApp(
          sessionStore: MemoryAuthSessionStore(),
          preferencesStore: preferences,
        ),
      );
      await tester.pumpAndSettle();
      expect(_app(tester).themeMode, ThemeMode.system);
      expect(_app(tester).locale, const Locale('en'));
      await tester.tap(find.bySemanticsLabel('Theme'));
      await tester.pumpAndSettle();
      tester
          .widget<LanguageButton>(find.byType(LanguageButton))
          .onSelected(const Locale('zh', 'CN'));
      await tester.pumpAndSettle();
      final saved = AppPreferences.decode(preferences.encoded!);
      expect(saved.themeMode, ThemeMode.dark);
      expect(saved.locale, const Locale('zh', 'CN'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a slow write cannot overwrite a newer theme and language choice',
    (tester) async {
      final firstWrite = Completer<void>();
      final preferences = _PreferencesStore()..pendingWrite = firstWrite;
      await tester.pumpWidget(
        ThuliumApp(
          sessionStore: MemoryAuthSessionStore(),
          preferencesStore: preferences,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Theme'));
      await tester.pump();
      tester
          .widget<LanguageButton>(find.byType(LanguageButton))
          .onSelected(const Locale('zh', 'TW'));
      await tester.pump();
      expect(preferences.writes, 1);
      firstWrite.complete();
      await tester.pumpAndSettle();
      final saved = AppPreferences.decode(preferences.encoded!);
      expect(saved.themeMode, ThemeMode.dark);
      expect(saved.locale, const Locale('zh', 'TW'));
      expect(preferences.writes, 2);
    },
  );

  test(
    'corrupt and obsolete preferences preserve supported values and defaults',
    () {
      expect(AppPreferences.decode('broken').themeMode, ThemeMode.system);
      expect(AppPreferences.decode('[]').locale, const Locale('en'));
      final obsolete = AppPreferences.decode(
        '{"theme":"obsolete","locale":"zh-TW"}',
      );
      expect(obsolete.themeMode, ThemeMode.system);
      expect(obsolete.locale, const Locale('zh', 'TW'));
      final unknownLanguage = AppPreferences.decode(
        '{"theme":"dark","locale":"unknown"}',
      );
      expect(unknownLanguage.themeMode, ThemeMode.dark);
      expect(unknownLanguage.locale, const Locale('en'));
    },
  );
}

MaterialApp _app(WidgetTester tester) =>
    tester.widget<MaterialApp>(find.byType(MaterialApp));

class _PreferencesStore implements AppPreferencesStore {
  String? encoded;
  Completer<AppPreferences>? pendingRead;
  Completer<void>? pendingWrite;
  bool failRead = false;
  bool failNextWrite = false;
  int writes = 0;

  @override
  Future<AppPreferences> read() async {
    if (failRead) throw StateError('synthetic read failure');
    if (pendingRead != null) return pendingRead!.future;
    return encoded == null
        ? const AppPreferences()
        : AppPreferences.decode(encoded!);
  }

  @override
  Future<void> write(AppPreferences preferences) async {
    writes++;
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('synthetic write failure');
    }
    if (writes == 1) await pendingWrite?.future;
    encoded = preferences.encode();
  }
}
