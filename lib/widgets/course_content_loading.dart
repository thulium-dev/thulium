import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../l10n/generated/app_localizations.dart';

/// Loading keeps the same page surface and approximate content geometry.
class CourseContentLoading extends StatelessWidget {
  const CourseContentLoading({this.document = false, super.key});
  final bool document;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    if (document) {
      return Semantics(
        label: AppLocalizations.of(context)!.coursePreviewLoading,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FLucideIcons.fileText, color: theme.colors.mutedForeground),
              SizedBox(height: theme.style.pagePadding.top),
              const FCircularProgress(size: FCircularProgressSizeVariant.sm),
            ],
          ),
        ),
      );
    }
    return Semantics(
      label: AppLocalizations.of(context)!.courseContentLoading,
      child: ExcludeSemantics(
        child: ListView.separated(
          itemCount: 5,
          separatorBuilder: (_, _) => Container(
            height: theme.style.borderWidth,
            color: theme.colors.border,
          ),
          itemBuilder: (_, index) => Padding(
            padding: theme.style.pagePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(
                  widthFactor: index.isEven ? 0.65 : 0.45,
                  child: Container(height: 14, color: theme.colors.muted),
                ),
                const SizedBox(height: 10),
                FractionallySizedBox(
                  widthFactor: 0.3,
                  child: Container(height: 10, color: theme.colors.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
