import 'dart:convert';
import 'dart:ui';

import 'package:file_selector/file_selector.dart' as fs;
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

import 'diagnostic_log.dart';

final class DiagnosticExport {
  DiagnosticExport({
    DiagnosticLog? log,
    Future<PackageInfo> Function()? packageInfo,
    Future<ShareResult> Function(ShareParams)? share,
  }) : _log = log ?? DiagnosticLog.instance,
       _packageInfo = packageInfo ?? PackageInfo.fromPlatform,
       _share = share ?? SharePlus.instance.share;

  final DiagnosticLog _log;
  final Future<PackageInfo> Function() _packageInfo;
  final Future<ShareResult> Function(ShareParams) _share;

  Future<void> export({
    required String title,
    Rect? sharePositionOrigin,
  }) async {
    _log.record('[app] event=export-requested');
    String version = 'unknown';
    String build = 'unknown';
    try {
      final info = await _packageInfo();
      String safe(String value) =>
          RegExp(r'^[A-Za-z0-9_.+\-]{1,80}$').hasMatch(value)
          ? value
          : 'unknown';
      version = safe(info.version);
      build = safe(info.buildNumber);
    } catch (_) {
      // Metadata failure should not prevent exporting the useful event log.
    }
    final now = DateTime.now().toUtc();
    final name =
        'thulium-diagnostics-${now.toIso8601String().replaceAll(RegExp(r'[^0-9TZ]'), '')}.txt';
    final report =
        'Thulium diagnostics v1\n'
        'Generated (UTC): ${now.toIso8601String()}\n'
        'App version: $version+$build\n'
        'Platform: ${kIsWeb ? 'web' : defaultTargetPlatform.name}\n'
        'Mode: ${kReleaseMode
            ? 'release'
            : kProfileMode
            ? 'profile'
            : 'debug'}\n'
        'Content: structural events only; no request values or response bodies\n\n'
        '${await _log.snapshot()}\n';
    final file = fs.XFile.fromData(
      utf8.encode(report),
      name: name,
      mimeType: 'text/plain',
    );
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux) {
      final location = await fs.getSaveLocation(
        suggestedName: name,
        acceptedTypeGroups: const [
          fs.XTypeGroup(label: 'Text', extensions: ['txt']),
        ],
      );
      if (location != null) await file.saveTo(location.path);
    } else {
      await _share(
        ShareParams(
          title: title,
          files: [file],
          fileNameOverrides: [name],
          sharePositionOrigin: sharePositionOrigin,
        ),
      );
    }
  }
}
