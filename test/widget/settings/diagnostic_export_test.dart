import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:thulium/l10n/generated/app_localizations.dart';
import 'package:thulium/pages/settings_page.dart';
import 'package:thulium/pages/welcome_page.dart';

void main() {
  testWidgets('export is single flight and supplies an iPad share anchor', (
    tester,
  ) async {
    final completed = Completer<void>();
    var exports = 0;
    Rect? anchor;
    await tester.pumpWidget(
      _app(
        SettingsPage(
          exportDiagnostics: (origin) async {
            exports++;
            anchor = origin;
            await completed.future;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export diagnostic logs'));
    await tester.pump();
    await tester.tap(find.byType(FButton).last);
    await tester.pump();
    expect(exports, 1);
    expect(anchor, isNotNull);
    expect(anchor!.width, greaterThan(0));
    completed.complete();
    await tester.pumpAndSettle();
    expect(find.text('Export diagnostic logs'), findsOneWidget);
    expect(find.text('Log out'), findsNothing);
  });

  testWidgets('failed sharing offers retry and does not log out the account', (
    tester,
  ) async {
    var exports = 0;
    var logouts = 0;
    await tester.pumpWidget(
      _app(
        SettingsPage(
          onLogout: () async {
            logouts++;
            return false;
          },
          exportDiagnostics: (_) async {
            if (++exports == 1) throw StateError('synthetic export failure');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export diagnostic logs'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not export logs, please try again'),
      findsOneWidget,
    );
    await tester.tap(find.text('Export diagnostic logs'));
    await tester.pumpAndSettle();
    expect(exports, 2);
    expect(logouts, 0);
    expect(find.text('Could not export logs, please try again'), findsNothing);
  });

  testWidgets('welcome exposes log export even when sign-in is unavailable', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        WelcomePage(
          onLocaleSelected: (_) {},
          onThemeToggle: () {},
          onLoginSuccess: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Export diagnostic logs'), findsOneWidget);
    expect(find.text('Log out'), findsNothing);
  });
}

Widget _app(Widget home) => MaterialApp(
  localizationsDelegates: [
    ...AppLocalizations.localizationsDelegates,
    ...FLocalizations.localizationsDelegates,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) =>
      FTheme(data: FThemes.neutral.light.touch, child: child!),
  home: home,
);
