import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:thulium/l10n/generated/app_localizations.dart';
import 'package:thulium/widgets/homework_overview_card.dart';
import 'package:thulium/widgets/app_bottom_navigation.dart';

import '../../support/homework_preview.dart';

void main() {
  testWidgets(
    'capture homework review screenshots',
    (tester) async {
      final font = Platform.environment['HOMEWORK_SCREENSHOT_FONT']!;
      final bytes = ByteData.sublistView(File(font).readAsBytesSync());
      await tester.runAsync(
        () => (FontLoader(
          'HomeworkPreview',
        )..addFont(Future.value(bytes))).load(),
      );
      final icons = await rootBundle.load(
        'packages/forui_assets/assets/lucide.ttf',
      );
      await tester.runAsync(
        () => (FontLoader(
          'packages/forui_assets/ForuiLucideIcons',
        )..addFont(Future.value(icons))).load(),
      );
      final materialIcons = await rootBundle.load(
        'fonts/MaterialIcons-Regular.otf',
      );
      await tester.runAsync(
        () => (FontLoader(
          'MaterialIcons',
        )..addFont(Future.value(materialIcons))).load(),
      );
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final output = Directory('artifacts/homework-redesign');
      output.createSync(recursive: true);
      for (final dark in [false, true]) {
        final colors =
            (dark ? FThemes.neutral.dark.touch : FThemes.neutral.light.touch)
                .colors;
        final theme = FThemeData(
          colors: colors,
          touch: true,
          typography: FTypography(fontFamily: 'HomeworkPreview'),
        );
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('zh', 'CN'),
            localizationsDelegates: [
              ...AppLocalizations.localizationsDelegates,
              ...FLocalizations.localizationsDelegates,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            theme: theme.toApproximateMaterialTheme(),
            builder: (_, child) => FTheme(data: theme, child: child!),
            home: RepaintBoundary(
              key: key,
              child: FScaffold(
                childPad: false,
                footer: AppBottomNavigation(index: 0, onChange: (_) {}),
                child: HomeworkOverviewCard(
                  assignments: previewAssignments,
                  isLoading: false,
                  failed: false,
                  onRefresh: () {},
                  now: previewNow,
                  updatedAt: previewNow.subtract(const Duration(minutes: 7)),
                  countsTowardGrade: (item) =>
                      item.id == 'ungraded' ? false : null,
                  deviceTimeZoneOffset: const Duration(hours: 8),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          File(
            '${output.path}/${Platform.environment['HOMEWORK_CAPTURE_STAGE']}-${dark ? 'dark' : 'light'}.png',
          ).writeAsBytesSync(data!.buffer.asUint8List());
          image.dispose();
        });
      }
    },
    skip: Platform.environment['HOMEWORK_CAPTURE_STAGE'] == null,
  );
}
