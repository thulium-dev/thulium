import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:pdfx/pdfx.dart';

import '../l10n/generated/app_localizations.dart';
import 'course_content_loading.dart';

/// Owns the native document controller for the lifetime of one preview route.
class CourseDocumentPreview extends StatefulWidget {
  const CourseDocumentPreview({required this.bytes, super.key});
  final List<int> bytes;

  @override
  State<CourseDocumentPreview> createState() => _CourseDocumentPreviewState();
}

class _CourseDocumentPreviewState extends State<CourseDocumentPreview> {
  PdfController? _controller;
  Future<PdfDocument>? _document;
  int _page = 1;
  int? _pages;

  bool get _supported =>
      kIsWeb || defaultTargetPlatform != TargetPlatform.linux;

  @override
  void initState() {
    super.initState();
    if (_supported) {
      _document = PdfDocument.openData(Uint8List.fromList(widget.bytes));
      _controller = PdfController(document: _document!);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    final document = _document;
    if (document != null) unawaited(_closeDocument(document));
    super.dispose();
  }

  Future<void> _closeDocument(Future<PdfDocument> future) async {
    try {
      final document = await future;
      if (!document.isClosed) await document.close();
    } on Object {
      // Loading errors are presented in the viewer; cleanup must not rethrow.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (!_supported) {
      return Center(
        child: Padding(
          padding: context.theme.style.pagePadding,
          child: Text(l10n.coursePreviewUnsupported),
        ),
      );
    }
    return Column(
      children: [
        Expanded(
          child: PdfView(
            controller: _controller!,
            scrollDirection: Axis.vertical,
            backgroundDecoration: BoxDecoration(
              color: context.theme.colors.background,
            ),
            onDocumentLoaded: (document) {
              if (mounted) setState(() => _pages = document.pagesCount);
            },
            onPageChanged: (page) {
              if (mounted) setState(() => _page = page);
            },
            builders: PdfViewBuilders<DefaultBuilderOptions>(
              options: DefaultBuilderOptions(
                loaderSwitchDuration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 160),
              ),
              documentLoaderBuilder: (_) =>
                  const CourseContentLoading(document: true),
              pageLoaderBuilder: (_) =>
                  const CourseContentLoading(document: true),
              errorBuilder: (context, error) =>
                  Center(child: Text(l10n.coursePreviewError)),
            ),
          ),
        ),
        SizedBox(
          height: context.theme.style.sizes.tile,
          child: Center(
            child: _pages == null
                ? const SizedBox.shrink()
                : Text('$_page / $_pages', style: context.theme.typography.xs),
          ),
        ),
      ],
    );
  }
}
