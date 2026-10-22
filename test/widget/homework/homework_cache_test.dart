import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:thulium/l10n/generated/app_localizations.dart';
import 'package:thulium/pages/home_page.dart';
import 'package:thulium/widgets/homework_overview_card.dart';
import 'package:thulium_auth/thulium_auth.dart';
import 'package:thulium_campus/thulium_campus.dart';

void main() {
  testWidgets(
    'offline app restart displays saved assignments but another account cannot',
    (tester) async {
      final cacheStore = _Store();
      final semester = AcademicSemester.forDate(DateTime.now());
      await LearnHomeworkCache(cacheStore).writeFor(
        'student',
        semester,
        LearnHomeworkSnapshot(
          counts: {'physics': 1},
          assignments: [
            LearnHomework(
              id: 'assignment-1',
              title: 'Saved assignment',
              course: const LearnCourse(
                id: 'physics',
                name: '物理',
                englishName: 'Physics',
                teacherName: '',
                schedule: '',
              ),
              deadline: DateTime.now().toUtc().add(const Duration(days: 2)),
            ),
          ],
        ),
        DateTime.now(),
      );

      Future<void> mount(String userId) async {
        final sessionStore = MemoryAuthSessionStore();
        await sessionStore.write(
          AuthSession(userId: userId, fingerprint: 'test', cookies: {}),
        );
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: [
              ...AppLocalizations.localizationsDelegates,
              ...FLocalizations.localizationsDelegates,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (_, child) =>
                FTheme(data: FThemes.neutral.light.touch, child: child!),
            home: HomePage(
              key: UniqueKey(),
              sessionStore: sessionStore,
              homeworkCacheStore: cacheStore,
              onLocaleSelected: (_) {},
              onThemeToggle: () {},
              onLogout: () async => true,
              onSessionExpired: () {},
            ),
          ),
        );
        // Flutter widget tests block live HTTP requests; catalog refresh fails.
        await tester.pumpAndSettle();
        // Static skeletons deliberately do not keep frames scheduled. Wait for
        // the mocked HTTP failure explicitly rather than relying on a spinner.
        for (var attempt = 0; attempt < 50; attempt++) {
          if (!tester
              .widget<HomeworkOverviewCard>(find.byType(HomeworkOverviewCard))
              .isLoading) {
            break;
          }
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(
          tester
              .widget<HomeworkOverviewCard>(find.byType(HomeworkOverviewCard))
              .isLoading,
          isFalse,
        );
      }

      await mount('student');
      expect(find.text('Saved assignment'), findsOneWidget);
      expect(
        find.text('Could not update assignments; showing saved data.'),
        findsOneWidget,
      );
      expect(
        find.text('Could not load assignments. Try refreshing.'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await mount('student');
      expect(find.text('Saved assignment'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await mount('other-student');
      expect(find.text('Saved assignment'), findsNothing);
      expect(
        find.text('Could not load assignments. Try refreshing.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

final class _Store implements LearnHomeworkCacheStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async => this.value = value;
  @override
  Future<void> clear() async => value = null;
}
