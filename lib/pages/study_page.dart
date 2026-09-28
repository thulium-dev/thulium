import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:thulium/l10n/generated/app_localizations.dart';
import 'package:thulium_campus/thulium_campus.dart';

/// Keeps room for future study shortcuts above the Learn course list.
final class StudyPage extends StatelessWidget {
  const StudyPage({
    required this.semester,
    required this.catalog,
    required this.isLoading,
    required this.isStale,
    required this.error,
    required this.onRefresh,
    super.key,
  });

  final String semester;
  final LearnCourseCatalog? catalog;
  final bool isLoading;
  final bool isStale;
  final Object? error;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.theme.colors;
    final locale = Localizations.localeOf(context).languageCode;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text(l10n.studyToolsTitle, style: context.theme.typography.lg),
        const SizedBox(height: 10),
        Container(
          key: const ValueKey('study-shortcut-reserved'),
          height: 92,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            l10n.studyToolsPlaceholder,
            style: context.theme.typography.sm.copyWith(
              color: colors.mutedForeground,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.studyCoursesTitle,
                style: context.theme.typography.lg,
              ),
            ),
            Tooltip(
              message: l10n.studyRefresh,
              child: FButton.icon(
                variant: FButtonVariant.ghost,
                onPress: isLoading ? null : onRefresh,
                child: const Icon(Icons.refresh),
              ),
            ),
          ],
        ),
        Text(semester, style: context.theme.typography.sm),
        if (isStale)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(l10n.studyStaleCourses),
          ),
        if (isLoading && catalog == null)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: FCircularProgress()),
          )
        else if (error != null && catalog == null)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Text(l10n.studyLoadError),
          )
        else if (catalog?.courses.isEmpty ?? false)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Text(l10n.studyNoCourses),
          ),
        for (final course in catalog?.courses ?? <LearnCourse>[])
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.secondary.withValues(alpha: 0.18),
                border: Border.all(color: colors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      locale == 'en' && course.englishName.isNotEmpty
                          ? course.englishName
                          : course.name,
                      style: context.theme.typography.md,
                    ),
                    if (course.teacherName.isNotEmpty ||
                        course.schedule.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        [
                          if (course.teacherName.isNotEmpty) course.teacherName,
                          if (course.schedule.isNotEmpty) course.schedule,
                        ].join(' · '),
                        style: context.theme.typography.sm.copyWith(
                          color: colors.mutedForeground,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
