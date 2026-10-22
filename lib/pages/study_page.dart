import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:thulium/l10n/generated/app_localizations.dart';
import 'package:thulium_campus/thulium_campus.dart';

import '../widgets/flat_tile_style.dart';

/// Keeps room for future study shortcuts above the Learn course list.
final class StudyPage extends StatelessWidget {
  const StudyPage({
    required this.semester,
    required this.catalog,
    required this.isLoading,
    required this.isStale,
    required this.error,
    required this.onRefresh,
    this.unsubmittedHomework = const {},
    this.homeworkLoading = false,
    this.homeworkFailed = false,
    this.homeworkStale = false,
    super.key,
  });

  final String semester;
  final LearnCourseCatalog? catalog;
  final bool isLoading;
  final bool isStale;
  final Object? error;
  final VoidCallback onRefresh;
  final Map<String, int> unsubmittedHomework;
  final bool homeworkLoading;
  final bool homeworkFailed;
  final bool homeworkStale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = context.theme;
    final colors = theme.colors;
    final locale = Localizations.localeOf(context).languageCode;
    final courseTitleStyle = context.theme.typography.md;
    final courseMetadataStyle = theme.typography.xs.copyWith(
      color: colors.mutedForeground,
    );
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
            if (homeworkLoading) ...[
              const FCircularProgress(size: FCircularProgressSizeVariant.xs),
              const SizedBox(width: 8),
            ],
            Tooltip(
              message: l10n.studyRefresh,
              child: FButton.icon(
                variant: FButtonVariant.ghost,
                onPress: isLoading || homeworkLoading ? null : onRefresh,
                child: const Icon(Icons.refresh),
              ),
            ),
          ],
        ),
        Text(semester, style: context.theme.typography.sm),
        if (homeworkStale)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(l10n.homeworkStale),
          ),
        if (homeworkFailed)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(l10n.studyHomeworkLoadError),
          ),
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
        if (catalog?.courses.isNotEmpty ?? false)
          Padding(
            padding: EdgeInsets.only(top: theme.style.pagePadding.top),
            child: FTileGroup(
              intrinsicWidth: false,
              physics: const NeverScrollableScrollPhysics(),
              divider: FItemDivider.full,
              children: [
                for (final course in catalog!.courses)
                  FTile.raw(
                    key: ValueKey('study-course-${course.id}'),
                    style: flatTileStyle(theme),
                    child: Padding(
                      padding: theme.style.pagePadding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  locale == 'en' &&
                                          course.englishName.isNotEmpty
                                      ? course.englishName
                                      : course.name,
                                  style: courseTitleStyle.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (!homeworkFailed &&
                                  (unsubmittedHomework[course.id] ?? 0) >
                                      0) ...[
                                const SizedBox(width: 8),
                                Semantics(
                                  label: l10n.studyUnsubmittedHomework(
                                    unsubmittedHomework[course.id]!,
                                  ),
                                  excludeSemantics: true,
                                  child: Tooltip(
                                    message: l10n.studyUnsubmittedHomework(
                                      unsubmittedHomework[course.id]!,
                                    ),
                                    excludeFromSemantics: true,
                                    child: FBadge(
                                      key: ValueKey(
                                        'homework-badge-${course.id}',
                                      ),
                                      variant: FBadgeVariant.destructive,
                                      child: Text(
                                        '${unsubmittedHomework[course.id]}',
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (course.teacherName.isNotEmpty ||
                              course.schedule.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              [
                                if (course.teacherName.isNotEmpty)
                                  course.teacherName,
                                if (course.schedule.isNotEmpty) course.schedule,
                              ].join(' · '),
                              style: courseMetadataStyle,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
