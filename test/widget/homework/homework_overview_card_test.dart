import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:thulium/homework/homework_presentation.dart';
import 'package:thulium/l10n/generated/app_localizations.dart';
import 'package:thulium/widgets/app_bottom_navigation.dart';
import 'package:thulium/widgets/homework_overview_card.dart';
import 'package:thulium/widgets/scrolling_badge.dart';

import '../../support/homework_preview.dart';

void main() {
  Future<void> show(
    WidgetTester tester, {
    double scale = 1,
    bool reduceMotion = true,
    bool dark = false,
    bool loading = false,
    bool failed = false,
    bool empty = false,
    Duration offset = const Duration(hours: 8),
    VoidCallback? refresh,
    HomeworkActions actions = const HomeworkActions(),
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = const Size(390, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final theme = dark
        ? FThemes.neutral.dark.touch
        : FThemes.neutral.light.touch;
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: [
          ...AppLocalizations.localizationsDelegates,
          ...FLocalizations.localizationsDelegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        theme: theme.toApproximateMaterialTheme(),
        builder: (context, child) => FTheme(
          data: theme,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: reduceMotion,
            ),
            child: child!,
          ),
        ),
        home: FScaffold(
          childPad: false,
          footer: AppBottomNavigation(index: 0, onChange: (_) {}),
          child: HomeworkOverviewCard(
            assignments: empty ? [] : previewAssignments,
            isLoading: loading,
            failed: failed,
            onRefresh: refresh ?? () {},
            now: previewNow,
            updatedAt: previewNow.subtract(const Duration(minutes: 7)),
            deviceTimeZoneOffset: offset,
            countsTowardGrade: (item) => item.id == 'ungraded' ? false : null,
            actions: actions,
          ),
        ),
      ),
    );
    if (reduceMotion) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  testWidgets(
    'uses grouped tiles, icon refresh and overdue last without timezone prose',
    (tester) async {
      await show(tester);
      expect(find.byType(FCard), findsNothing);
      expect(find.byType(FTileGroup), findsNWidgets(3));
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Within 1h'), findsOneWidget);
      expect(find.text('Not graded'), findsOneWidget);
      expect(find.text('Updated 7 minutes ago'), findsOneWidget);
      expect(
        find.text('All deadlines use Beijing time (UTC+8).'),
        findsNothing,
      );
      expect(find.textContaining('Beijing time'), findsNothing);
      expect(
        tester.getTopLeft(find.text(previewAssignments[0].title)).dy,
        greaterThan(
          tester.getTopLeft(find.text(previewAssignments[1].title)).dy,
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (final dark in [false, true]) {
    for (final locale in [const Locale('en'), const Locale('zh', 'CN')]) {
      testWidgets(
        '200% text fits ${dark ? 'dark' : 'light'} ${locale.languageCode}',
        (tester) async {
          await show(tester, scale: 2, dark: dark, locale: locale);
          await tester.drag(
            find.byKey(const ValueKey('homework-scroll')),
            const Offset(0, -650),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final navItems = find.byType(FBottomNavigationBarItem);
          expect(navItems, findsNWidgets(4));
          for (final element in navItems.evaluate()) {
            expect(
              tester.getSize(find.byWidget(element.widget)).height,
              greaterThanOrEqualTo(44),
            );
          }
        },
      );
    }
  }
  testWidgets(
    'tap opens details, long press exposes disabled unconnected actions',
    (tester) async {
      await show(tester);
      await tester.tap(find.text(previewAssignments.first.title));
      await tester.pumpAndSettle();
      expect(find.text('Assignment details'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();
      await tester.longPress(find.text(previewAssignments.first.title));
      await tester.pumpAndSettle();
      for (final label in [
        'Open website',
        'Remind me later',
        'Mark as submitted',
      ]) {
        final button = tester.widget<FButton>(
          find.ancestor(of: find.text(label), matching: find.byType(FButton)),
        );
        expect(button.onPress, isNull);
      }
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('supports real action callbacks and refresh', (tester) async {
    var refreshes = 0;
    var opened = false;
    await show(
      tester,
      refresh: () => refreshes++,
      actions: HomeworkActions(openWeb: (_) async => opened = true),
    );
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('homework-scroll')),
      const Offset(0, 350),
    );
    await tester.pumpAndSettle();
    expect(refreshes, 2);
    await tester.longPress(find.text(previewAssignments.first.title));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open website'));
    await tester.pumpAndSettle();
    expect(opened, isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets('long badge labels stay on one line and scroll when clipped', (
    tester,
  ) async {
    await show(tester, scale: 2, reduceMotion: false);
    await tester.scrollUntilVisible(
      find.text('Within 3 days'),
      250,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('homework-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    final label = find.text('Within 3 days');
    final text = tester.widget<Text>(label);
    expect(text.maxLines, 1);
    expect(text.softWrap, isFalse);
    final badge = find.ancestor(
      of: label,
      matching: find.byType(ScrollingBadge),
    );
    final translation = find
        .descendant(of: badge, matching: find.byType(Transform))
        .first;
    final before = tester
        .widget<Transform>(translation)
        .transform
        .getTranslation()
        .x;
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));
    final after = tester
        .widget<Transform>(translation)
        .transform
        .getTranslation()
        .x;
    expect(after, lessThan(before));
    final animation =
        tester
                .widget<AnimatedBuilder>(
                  find
                      .descendant(
                        of: badge,
                        matching: find.byType(AnimatedBuilder),
                      )
                      .first,
                )
                .animation
            as AnimationController;
    final cycle = animation.duration!.inMicroseconds;
    await tester.pump(Duration(microseconds: (cycle * .35).round()));
    final furtherLeft = tester
        .widget<Transform>(translation)
        .transform
        .getTranslation()
        .x;
    expect(furtherLeft, lessThan(after));
    await tester.pump(
      Duration(microseconds: (cycle * (1 - animation.value + .05)).round()),
    );
    final nextLoop = tester
        .widget<Transform>(translation)
        .transform
        .getTranslation()
        .x;
    expect(nextLoop, greaterThan(furtherLeft));
    expect(animation.isAnimating, isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets('loading, retry and empty states are accessible', (tester) async {
    await show(tester, loading: true);
    expect(find.bySemanticsLabel('Loading assignments'), findsOneWidget);
    await show(tester, failed: true);
    expect(find.byType(FAlert), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    await show(tester, empty: true);
    expect(find.text('All done'), findsOneWidget);
  });
  testWidgets('adds per-row Beijing notice only outside Beijing timezone', (
    tester,
  ) async {
    await show(tester, offset: Duration.zero);
    expect(find.textContaining('· Beijing time'), findsNWidgets(3));
  });
}
