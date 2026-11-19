import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:intl/intl.dart';
import 'package:thulium_auth/thulium_auth.dart';
import 'package:thulium_campus/thulium_campus.dart';

import '../l10n/generated/app_localizations.dart';
import '../study/course_content_source.dart';
import '../widgets/flat_tile_style.dart';
import '../widgets/course_document_preview.dart';
import '../widgets/app_page_scaffold.dart';
import '../navigation/app_page_route.dart';
import '../widgets/course_content_loading.dart';

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
    return AppPageScaffold(
      title: name,
      child: ListView(
        children: [
          if (course.teacherName.isNotEmpty)
            Text(
              course.teacherName,
              style: theme.typography.sm.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
          if (course.schedule.isNotEmpty)
            Text(
              course.schedule,
              style: theme.typography.sm.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
          SizedBox(height: theme.style.pagePadding.top),
          FTileGroup(
            style: flatTileGroupStyle,
            intrinsicWidth: false,
            divider: FItemDivider.full,
            children: [
              FTile(
                style: flatTileStyle(theme),
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
                                style: flatTileStyle(context.theme),
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
                style: flatTileStyle(theme),
                title: Text(l10n.courseAssignments),
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
                                  style: flatTileStyle(context.theme),
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
).push<void>(AppPageRoute(context: context, builder: (_) => page));

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
  T? _data;
  Object? _error;
  bool _loading = true;
  int _contentGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    await _load();
  }

  Future<void> _load() async {
    try {
      final data = await widget.load();
      if (!mounted) return;
      setState(() {
        _data = data;
        _error = null;
        _loading = false;
        _contentGeneration++;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final expired =
        _error is PortalSessionRejected ||
        _error is TwoFactorInteractionRequired;
    final errorText = expired
        ? l10n.courseSessionExpired
        : widget.document
        ? l10n.coursePreviewError
        : l10n.courseContentError;
    final data = _data;
    final Widget content;
    if (data != null) {
      content = Column(
        children: [
          if (_error != null)
            Padding(
              padding: context.theme.style.pagePadding,
              child: FAlert(
                title: Text(errorText),
                subtitle: expired
                    ? FButton(
                        onPress: widget.onSessionExpired,
                        child: Text(l10n.signInAction),
                      )
                    : null,
              ),
            ),
          Expanded(
            child: KeyedSubtree(
              key: ValueKey(widget.document ? _contentGeneration : 0),
              child: widget.builder(context, data, _refresh),
            ),
          ),
        ],
      );
    } else if (_loading) {
      content = CourseContentLoading(document: widget.document);
    } else {
      content = Center(
        child: Padding(
          padding: context.theme.style.pagePadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                errorText,
                style: context.theme.typography.sm,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: context.theme.style.pagePadding.top),
              FButton(
                onPress: expired ? widget.onSessionExpired : _refresh,
                child: Text(expired ? l10n.signInAction : l10n.calendarRetry),
              ),
            ],
          ),
        ),
      );
    }
    return AppPageScaffold(
      title: widget.title,
      fullBleed: widget.document,
      actions: [
        FButton.icon(
          variant: FButtonVariant.ghost,
          semanticsLabel: l10n.studyRefresh,
          onPress: _loading ? null : _refresh,
          child: _loading
              ? const FCircularProgress(size: FCircularProgressSizeVariant.xs)
              : const Icon(FLucideIcons.refreshCw),
        ),
      ],
      child: AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 160),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        layoutBuilder: (current, previous) =>
            Stack(fit: StackFit.expand, children: [...previous, ?current]),
        child: KeyedSubtree(
          key: ValueKey(
            data != null
                ? 'content'
                : _loading
                ? 'loading'
                : 'error',
          ),
          child: content,
        ),
      ),
    );
  }
}
