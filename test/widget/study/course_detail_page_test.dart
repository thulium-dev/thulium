import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:thulium/l10n/generated/app_localizations.dart';
import 'package:thulium/pages/course_detail_page.dart';
import 'package:thulium/study/course_content_source.dart';
import 'package:thulium_auth/thulium_auth.dart';
import 'package:thulium_campus/thulium_campus.dart';

const course = LearnCourse(
  id: 'physics',
  name: '物理',
  englishName: 'Physics',
  teacherName: 'Teacher',
  schedule: 'Room 101',
);

class FakeContent extends CourseContentSource {
  FakeContent()
    : super(
        store: MemoryAuthSessionStore(),
        catalog: LearnCourseCatalog(
          userId: 'student',
          semester: '2026-2027-1',
          courses: [course],
        ),
      );
  bool fail = false;
  int documentRequests = 0;
  @override
  Future<LearnCourseMaterials> materials(LearnCourse course) async {
    if (fail) throw const PortalSessionRejected();
    return LearnCourseMaterials(
      course: course,
      requestedLimit: 1,
      materials: [
        LearnMaterial.fromResponse({
          'kjxxid': 'material',
          'wlkcid': 'physics',
          'bt': 'Lecture.docx',
          'wjid': 'file',
          'wjlx': 'docx',
        }),
      ],
    );
  }

  @override
  Future<List<int>> document(LearnMaterial material) async {
    documentRequests++;
    throw const FormatException('No PDF conversion');
  }

  @override
  Future<Map<LearnHomeworkStatus, List<LearnHomework>>> assignments(
    LearnCourse course,
  ) async => {
    for (final status in LearnHomeworkStatus.values)
      status: [
        LearnHomework(
          id: status.name,
          course: course,
          title: '${status.name} assignment',
          deadline: null,
        ),
      ],
  };
}

void main() {
  Future<void> show(
    WidgetTester tester,
    FakeContent source, {
    VoidCallback? expired,
  }) async {
    final theme = FThemes.neutral.dark.touch;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: [
          ...AppLocalizations.localizationsDelegates,
          ...FLocalizations.localizationsDelegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        theme: theme.toApproximateMaterialTheme(),
        builder: (_, child) => FTheme(data: theme, child: child!),
        home: CourseDetailPage(
          course: course,
          source: source,
          onSessionExpired: expired ?? () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('files open preview and conversion failures offer retry', (
    tester,
  ) async {
    final source = FakeContent();
    await show(tester, source);
    await tester.tap(find.text('Course files'));
    await tester.pumpAndSettle();
    expect(find.text('Lecture.docx'), findsOneWidget);
    expect(find.textContaining('Showing up to 1'), findsOneWidget);
    await tester.tap(find.text('Lecture.docx'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Preview is unavailable.'), findsOneWidget);
    expect(source.documentRequests, 1);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(source.documentRequests, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('course assignments include all three statuses', (tester) async {
    await show(tester, FakeContent());
    await tester.tap(find.text('Course assignments'));
    await tester.pumpAndSettle();
    for (final status in LearnHomeworkStatus.values) {
      expect(find.text('${status.name} assignment'), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('expired session offers sign in', (tester) async {
    var expired = false;
    await show(
      tester,
      FakeContent()..fail = true,
      expired: () => expired = true,
    );
    await tester.tap(find.text('Course files'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Your session has expired.'), findsOneWidget);
    await tester.tap(find.text('Sign in to Thulium'));
    await tester.pumpAndSettle();
    expect(expired, isTrue);
  });
}
