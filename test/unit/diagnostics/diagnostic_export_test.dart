import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:thulium/diagnostics/diagnostic_export.dart';
import 'package:thulium/diagnostics/diagnostic_log.dart';

void main() {
  test(
    'mobile export shares a named text file with version and sanitized events',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final log = DiagnosticLog(store: _Store());
      addTearDown(log.dispose);
      log.record(
        '[auth] Credential recovery: cause=PortalCsrfUnavailable trustedCredentialPresent=true.',
      );
      ShareParams? shared;
      final export = DiagnosticExport(
        log: log,
        packageInfo: () async => PackageInfo(
          appName: 'Thulium',
          packageName: 'dev.thulium.app',
          version: '1.0.0',
          buildNumber: '2002',
        ),
        share: (params) async {
          shared = params;
          return const ShareResult('', ShareResultStatus.success);
        },
      );
      const origin = Rect.fromLTWH(1, 2, 100, 40);
      await export.export(
        title: 'Export diagnostic logs',
        sharePositionOrigin: origin,
      );
      expect(shared!.sharePositionOrigin, origin);
      expect(
        shared!.fileNameOverrides!.single,
        startsWith('thulium-diagnostics-'),
      );
      expect(shared!.fileNameOverrides!.single, endsWith('.txt'));
      final contents = await shared!.files!.single.readAsString();
      expect(contents, contains('App version: 1.0.0+2002'));
      expect(contents, contains('Platform: android'));
      expect(contents, contains('cause=PortalCsrfUnavailable'));
    },
  );

  test('unavailable package metadata does not block log export', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final log = DiagnosticLog(store: _Store());
    addTearDown(log.dispose);
    String? report;
    await DiagnosticExport(
      log: log,
      packageInfo: () async => throw StateError('unavailable metadata'),
      share: (params) async {
        report = await params.files!.single.readAsString();
        return const ShareResult('', ShareResultStatus.dismissed);
      },
    ).export(title: 'Logs');
    expect(report, contains('App version: unknown+unknown'));
  });
}

class _Store implements DiagnosticLogStore {
  @override
  Future<List<String>> read() async => [];
  @override
  Future<void> write(List<String> lines) async {}
}
