import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:thulium/l10n/generated/app_localizations.dart';
import 'package:thulium/pages/course_detail_page.dart';
import 'package:thulium/pages/study_page.dart';
import 'package:thulium/navigation/app_page_route.dart';
import 'package:thulium/widgets/app_page_scaffold.dart';
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
  Object? materialError;
  int documentRequests = 0;
  int fileLimit = 1;
  Completer<LearnCourseMaterials>? pendingMaterials;
  @override
  Future<LearnCourseMaterials> materials(LearnCourse course) async {
    if (materialError != null) throw materialError!;
    if (fail) throw const PortalSessionRejected();
    if (pendingMaterials != null) return pendingMaterials!.future;
    return LearnCourseMaterials(
      course: course,
      requestedLimit: fileLimit,
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
    bool dark = true,
    bool reducedMotion = false,
    bool study = false,
  }) async {
    var theme = dark ? FThemes.neutral.dark.touch : FThemes.neutral.light.touch;
    if (Platform.environment.containsKey('THULIUM_UI_CAPTURE_DIR')) {
      theme = FThemeData(
        colors: theme.colors,
        touch: true,
        typography: FTypography(fontFamily: 'UiReview'),
      );
    }
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: [
          ...AppLocalizations.localizationsDelegates,
          ...FLocalizations.localizationsDelegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        theme: theme.toApproximateMaterialTheme(),
        builder: (context, child) => RepaintBoundary(
          key: const ValueKey('ui-review'),
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: reducedMotion),
            child: FTheme(data: theme, child: child!),
          ),
        ),
        home: study
            ? Builder(
                builder: (context) => FScaffold(
                  child: StudyPage(
                    semester: source.catalog.semester,
                    catalog: source.catalog,
                    isLoading: false,
                    isStale: false,
                    error: null,
                    onRefresh: () {},
                    onCourseSelected: (course) => Navigator.of(context).push(
                      AppPageRoute<void>(
                        context: context,
                        builder: (_) => CourseDetailPage(
                          course: course,
                          source: source,
                          onSessionExpired: expired ?? () {},
                        ),
                      ),
                    ),
                  ),
                ),
              )
            : CourseDetailPage(
                course: course,
                source: source,
                onSessionExpired: expired ?? () {},
              ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<ui.Image> snapshot(WidgetTester tester) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('ui-review')),
    );
    return tester
        .runAsync(() => boundary.toImage(pixelRatio: 1))
        .then((image) => image!);
  }

  Future<int> backgroundPixel(WidgetTester tester, Offset point) async {
    final image = await snapshot(tester);
    final bytes = await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
    );
    final offset = (point.dy.floor() * image.width + point.dx.floor()) * 4;
    final pixel = bytes!.getUint32(offset);
    image.dispose();
    return pixel;
  }

  testWidgets('course actions stay flat while pressed in both themes', (
    tester,
  ) async {
    for (final dark in [false, true]) {
      await show(tester, FakeContent(), dark: dark);
      expect(find.text('Unsubmitted, submitted and graded'), findsNothing);
      for (final title in ['Course files', 'Course assignments']) {
        final tile = find.ancestor(
          of: find.text(title),
          matching: find.byType(FTile),
        );
        final rect = tester.getRect(tile);
        final point = Offset(rect.right - 12, rect.center.dy);
        final before = await backgroundPixel(tester, point);
        final gesture = await tester.startGesture(tester.getCenter(tile));
        await tester.pump(const Duration(milliseconds: 120));
        expect(await backgroundPixel(tester, point), before);
        await gesture.cancel();
        await tester.pumpAndSettle();
      }
    }
  });

  testWidgets(
    'My courses keeps its background on press and opens a shared route',
    (tester) async {
      await show(tester, FakeContent(), study: true);
      final tile = find.byKey(const ValueKey('study-course-physics'));
      final rect = tester.getRect(tile);
      final point = Offset(rect.right - 12, rect.center.dy);
      final before = await backgroundPixel(tester, point);
      final gesture = await tester.startGesture(tester.getCenter(tile));
      await tester.pump(const Duration(milliseconds: 120));
      expect(await backgroundPixel(tester, point), before);
      await gesture.cancel();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Physics'));
      await tester.pumpAndSettle();
      expect(find.text('Course files'), findsOneWidget);
      final route = ModalRoute.of(tester.element(find.text('Course files')))!;
      expect(route, isA<AppPageRoute<void>>());
      expect(route.transitionDuration, const Duration(milliseconds: 200));
    },
  );

  testWidgets(
    'refresh keeps file rows visible while the next request is pending',
    (tester) async {
      final source = FakeContent();
      await show(tester, source);
      await tester.tap(find.text('Course files'));
      await tester.pumpAndSettle();
      source.pendingMaterials = Completer<LearnCourseMaterials>();
      await tester.tap(find.bySemanticsLabel('Refresh courses'));
      await tester.pump();
      expect(find.text('Lecture.docx'), findsOneWidget);
      source.pendingMaterials!.completeError(const FormatException('offline'));
      await tester.pumpAndSettle();
      expect(find.text('Lecture.docx'), findsOneWidget);
      expect(
        find.textContaining('Could not load course content'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'nested course routes honor reduced motion and use shared chrome',
    (tester) async {
      await show(tester, FakeContent(), reducedMotion: true);
      await tester.tap(find.text('Course files'));
      await tester.pumpAndSettle();
      final context = tester.element(find.text('Lecture.docx'));
      final route = ModalRoute.of(context)! as AppPageRoute<void>;
      expect(route.transitionDuration, Duration.zero);
      expect(route.reverseTransitionDuration, Duration.zero);
      expect(find.byType(AppPageScaffold), findsOneWidget);
    },
  );

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

  testWidgets(
    'unavailable portal offers retry without discarding the signed-in screen',
    (tester) async {
      final source = FakeContent()
        ..materialError = const PortalCsrfUnavailable(
          'temporarily unavailable',
        );
      var expired = false;
      await show(tester, source, expired: () => expired = true);
      await tester.tap(find.text('Course files'));
      await tester.pumpAndSettle();
      expect(find.text('Sign in'), findsNothing);
      expect(find.text('Retry'), findsOneWidget);
      source.materialError = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Lecture.docx'), findsOneWidget);
      expect(expired, isFalse);
    },
  );

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
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(expired, isTrue);
  });
  if (Platform.environment.containsKey('THULIUM_UI_CAPTURE_DIR')) {
    testWidgets('capture course flow for visual review', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final font = File(
        Platform.environment['THULIUM_UI_REVIEW_FONT']!,
      ).readAsBytesSync();
      await tester.runAsync(
        () => (FontLoader(
          'UiReview',
        )..addFont(Future.value(ByteData.sublistView(font)))).load(),
      );
      final icons = await rootBundle.load(
        'packages/forui_assets/assets/lucide.ttf',
      );
      await tester.runAsync(
        () => (FontLoader(
          'packages/forui_assets/ForuiLucideIcons',
        )..addFont(Future.value(icons))).load(),
      );
      final output = Directory(Platform.environment['THULIUM_UI_CAPTURE_DIR']!);
      output.createSync(recursive: true);
      Future<void> capture(String name) async {
        final image = await snapshot(tester);
        final data = await tester.runAsync(
          () => image.toByteData(format: ui.ImageByteFormat.png),
        );
        File(
          '${output.path}/$name.png',
        ).writeAsBytesSync(data!.buffer.asUint8List());
        image.dispose();
      }

      for (final dark in [false, true]) {
        final source = FakeContent();
        source.fileLimit = 200;
        final mode = dark ? 'dark' : 'light';
        await show(tester, source, dark: dark, study: true);
        await capture('$mode-study');
        await tester.tap(find.text('Physics'));
        await tester.pumpAndSettle();
        await capture('$mode-course');
        await tester.tap(find.text('Course files'));
        await tester.pumpAndSettle();
        await capture('$mode-files');
        await tester.tap(find.bySemanticsLabel('Back'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Course assignments'));
        await tester.pumpAndSettle();
        await capture('$mode-assignments');
        await tester.tap(find.bySemanticsLabel('Back'));
        await tester.pumpAndSettle();
        source.pendingMaterials = Completer<LearnCourseMaterials>();
        await tester.tap(find.text('Course files'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        await capture('$mode-loading');
        source.pendingMaterials!.completeError(
          const FormatException('offline'),
        );
        await tester.pumpAndSettle();
        await capture('$mode-error');
        await tester.tap(find.bySemanticsLabel('Back'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Back'));
        await tester.pumpAndSettle();
      }
    });
  }
}
