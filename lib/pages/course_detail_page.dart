import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:intl/intl.dart';
import 'package:thulium_auth/thulium_auth.dart';
import 'package:thulium_campus/thulium_campus.dart';

import '../l10n/generated/app_localizations.dart';
import '../study/course_content_source.dart';
import '../widgets/flat_tile_style.dart';
import '../widgets/course_document_preview.dart';

class CourseDetailPage extends StatelessWidget {
  const CourseDetailPage({
    required this.course,
    required this.source,
    required this.onSessionExpired,
    super.key,
  });

  final LearnCourse course;
  final CourseContentSource source;
  final VoidCallback onSessionExpired;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = context.theme;
    final name =
        Localizations.localeOf(context).languageCode == 'en' &&
            course.englishName.isNotEmpty
        ? course.englishName
        : course.name;
    return FScaffold(
      header: _header(context, name),
      child: ListView(
        children: [
          if (course.teacherName.isNotEmpty)
            Text(course.teacherName, style: theme.typography.sm),
          if (course.schedule.isNotEmpty)
            Text(course.schedule, style: theme.typography.sm),
          SizedBox(height: theme.style.pagePadding.top),
          FTileGroup(
            style: flatTileGroupStyle,
            intrinsicWidth: false,
            divider: FItemDivider.full,
            children: [
              FTile(
                title: Text(l10n.courseFiles),
                prefix: const Icon(FLucideIcons.files),
                onPress: () => _push(
                  context,
                  _CourseResourcePage<LearnCourseMaterials>(
                    title: l10n.courseFiles,
                    load: () => source.materials(course),
                    onSessionExpired: onSessionExpired,
                    builder: (context, data, refresh) => ListView(
                      children: [
                        if (data.mayBeTruncated)
                          FAlert(
                            title: Text(
                              l10n.courseFilesLimited(data.requestedLimit),
                            ),
                          ),
                        if (data.materials.isEmpty) Text(l10n.courseFilesEmpty),
                        FTileGroup(
                          style: flatTileGroupStyle,
                          intrinsicWidth: false,
                          divider: FItemDivider.full,
                          children: [
                            for (final file in data.materials)
                              FTile(
                                key: ValueKey('course-file-${file.id}'),
                                title: Text(file.title),
                                subtitle: Text(
                                  [file.fileType, file.displaySize]
                                      .where((value) => value.isNotEmpty)
                                      .join(' · '),
                                ),
                                prefix: const Icon(FLucideIcons.fileText),
                                onPress: () => _push(
                                  context,
                                  _CourseResourcePage<List<int>>(
                                    title: file.title,
                                    load: () => source.document(file),
                                    onSessionExpired: onSessionExpired,
                                    document: true,
                                    builder: (context, bytes, refresh) =>
                                        CourseDocumentPreview(bytes: bytes),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              FTile(
                title: Text(l10n.courseAssignments),
                subtitle: Text(l10n.courseAssignmentsScope),
                prefix: const Icon(FLucideIcons.listTodo),
                onPress: () => _push(
                  context,
                  _CourseResourcePage<
                    Map<LearnHomeworkStatus, List<LearnHomework>>
                  >(
                    title: l10n.courseAssignments,
                    load: () => source.assignments(course),
                    onSessionExpired: onSessionExpired,
                    builder: (context, groups, refresh) => ListView(
                      children: [
                        for (final entry in groups.entries) ...[
                          FTileGroup(
                            style: flatTileGroupStyle,
                            intrinsicWidth: false,
                            divider: FItemDivider.full,
                            label: Text(switch (entry.key) {
                              LearnHomeworkStatus.unsubmitted =>
                                l10n.courseUnsubmitted,
                              LearnHomeworkStatus.submitted =>
                                l10n.courseSubmitted,
                              LearnHomeworkStatus.graded => l10n.courseGraded,
                            }),
                            children: [
                              for (final assignment in entry.value)
                                FTile(
                                  title: Text(assignment.title),
                                  subtitle: Text(
                                    assignment.deadline == null
                                        ? l10n.homeworkUnknownDeadline
                                        : l10n.homeworkDeadline(
                                            DateFormat.yMMMd(
                                              l10n.localeName,
                                            ).add_Hm().format(
                                              assignment.deadline!.toLocal(),
                                            ),
                                          ),
                                  ),
                                ),
                            ],
                          ),
                          if (entry.value.isEmpty)
                            Text(l10n.courseAssignmentsEmpty),
                          SizedBox(height: context.theme.style.pagePadding.top),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

void _push(BuildContext context, Widget page) => Navigator.of(
  context,
).push<void>(PageRouteBuilder(pageBuilder: (_, _, _) => page));

FHeader _header(BuildContext context, String title, {Widget? suffix}) =>
    FHeader.nested(
      title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
      prefixes: [
        FButton.icon(
          variant: FButtonVariant.ghost,
          semanticsLabel: AppLocalizations.of(context)!.homeworkBack,
          onPress: () => Navigator.of(context).pop(),
          child: const Icon(FLucideIcons.arrowLeft),
        ),
      ],
      suffixes: [?suffix],
    );

class _CourseResourcePage<T> extends StatefulWidget {
  const _CourseResourcePage({
    required this.title,
    required this.load,
    required this.builder,
    required this.onSessionExpired,
    this.document = false,
  });
  final String title;
  final Future<T> Function() load;
  final Widget Function(BuildContext, T, Future<void> Function()) builder;
  final VoidCallback onSessionExpired;
  final bool document;

  @override
  State<_CourseResourcePage<T>> createState() => _CourseResourcePageState<T>();
}

class _CourseResourcePageState<T> extends State<_CourseResourcePage<T>> {
  late Future<T> _future = widget.load();
  int _generation = 0;

  Future<void> _refresh() async {
    final future = widget.load();
    setState(() {
      _future = future;
      _generation++;
    });
    // FutureBuilder owns error presentation, including failures during refresh.
    try {
      await future;
    } on Object {
      /* Displayed by FutureBuilder. */
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FScaffold(
      childPad: !widget.document,
      header: _header(
        context,
        widget.title,
        suffix: FButton.icon(
          variant: FButtonVariant.ghost,
          semanticsLabel: l10n.studyRefresh,
          onPress: _refresh,
          child: const Icon(FLucideIcons.refreshCw),
        ),
      ),
      child: FutureBuilder<T>(
        key: ValueKey(_generation),
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: FCircularProgress());
          }
          if (snapshot.hasError) {
            final expired =
                snapshot.error is PortalSessionRejected ||
                snapshot.error is PortalCsrfUnavailable;
            return Center(
              child: Padding(
                padding: context.theme.style.pagePadding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FAlert(
                      title: Text(
                        expired
                            ? l10n.courseSessionExpired
                            : widget.document
                            ? l10n.coursePreviewError
                            : l10n.courseContentError,
                      ),
                    ),
                    SizedBox(height: context.theme.style.pagePadding.top),
                    FButton(
                      onPress: expired ? widget.onSessionExpired : _refresh,
                      child: Text(
                        expired ? l10n.loginTitle : l10n.calendarRetry,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return widget.builder(context, snapshot.data as T, _refresh);
        },
      ),
    );
  }
}
