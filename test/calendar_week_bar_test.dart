import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:thulium/l10n/generated/app_localizations.dart';
import 'package:thulium/pages/calendar_page.dart';
import 'package:thulium_auth/thulium_auth.dart';

void main() {
  testWidgets('keeps the calendar actions in balanced side regions', (
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
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              height: 500,
              child: AcademicCalendarPage(
                sessionStore: MemoryAuthSessionStore(),
                onSessionExpired: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final refresh = tester.getCenter(find.byIcon(Icons.refresh)).dx;
    final previous = tester.getCenter(find.byIcon(Icons.chevron_left)).dx;
    final next = tester.getCenter(find.byIcon(Icons.chevron_right)).dx;
    final add = tester.getCenter(find.byIcon(Icons.add)).dx;
    final export = tester.getCenter(find.byIcon(Icons.ios_share_outlined)).dx;
    final barCenter = tester.getCenter(find.byType(AcademicCalendarPage)).dx;

    expect(refresh, lessThan(previous));
    expect(previous, lessThan(barCenter));
    expect(barCenter, lessThan(next));
    expect(next, lessThan(export));
    expect(next, lessThan(add));
    expect(add, lessThan(export));
    expect(
      tester.getCenter(find.byKey(const ValueKey('calendar-week-label'))).dx,
      closeTo(barCenter, 1),
    );
    expect(tester.takeException(), isNull);

    final exportButton = tester.widget<FButton>(
      find.ancestor(
        of: find.byIcon(Icons.ios_share_outlined),
        matching: find.byType(FButton),
      ),
    );
    expect(exportButton.onPress, isNull);
  });
}
