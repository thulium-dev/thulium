import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:thulium/diagnostics/diagnostic_log.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'installed hooks collect live events and preserve existing error handlers',
    () async {
      final previousPrint = debugPrint;
      final previousFlutterError = FlutterError.onError;
      final previousPlatformError = PlatformDispatcher.instance.onError;
      final log = DiagnosticLog(store: _Store());
      addTearDown(() {
        log.dispose();
        debugPrint = previousPrint;
        FlutterError.onError = previousFlutterError;
        PlatformDispatcher.instance.onError = previousPlatformError;
      });
      var printed = 0;
      var flutterErrors = 0;
      debugPrint = (String? message, {int? wrapWidth}) => printed++;
      FlutterError.onError = (_) => flutterErrors++;
      PlatformDispatcher.instance.onError = (_, _) => true;
      log.install();
      debugPrint('[auth] HTTP response status=401 elapsedMs=8');
      FlutterError.onError!(
        FlutterErrorDetails(exception: StateError('private-message')),
      );
      expect(
        PlatformDispatcher.instance.onError!(
          const FormatException('private-message'),
          StackTrace.empty,
        ),
        isTrue,
      );
      final report = await log.snapshot();
      expect(printed, 1);
      expect(flutterErrors, 1);
      expect(report, contains('status=401'));
      expect(report, contains('event=flutter-error type=StateError'));
      expect(report, contains('event=platform-error type=FormatException'));
      expect(report, isNot(contains('private-message')));
    },
  );

  test(
    'the platform log store survives recreation without replacing appearance preferences',
    () async {
      final previous = SharedPreferencesAsyncPlatform.instance;
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({
            'thulium.preferences.v1': 'appearance-preferences',
          });
      addTearDown(() => SharedPreferencesAsyncPlatform.instance = previous);
      final first = DiagnosticLog(store: LocalDiagnosticLogStore());
      addTearDown(first.dispose);
      first.record('[app] event=started');
      await first.flush();
      final restarted = DiagnosticLog(store: LocalDiagnosticLogStore());
      addTearDown(restarted.dispose);
      expect(await restarted.snapshot(), contains('event=started'));
      expect(
        await SharedPreferencesAsync().getString('thulium.preferences.v1'),
        'appearance-preferences',
      );
    },
  );

  test(
    'recording retains structural diagnosis without credential, URL or content values',
    () async {
      final store = _Store();
      final log = DiagnosticLog(
        store: store,
        now: () => DateTime.utc(2026, 11, 18),
      );
      addTearDown(log.dispose);
      const secrets = [
        'password-value',
        '1234567890',
        '654321',
        'secret-token',
        'private-file',
        'private-course-title',
      ];
      log.record(
        '[auth] HTTP GET webvpn.tsinghua.edu.cn/https/encoded/downloadPdfStream/all/private-file/1234567890?token=secret-token formKeys=i_pass cookieNames=SESSION',
      );
      log.record(
        '[auth] HTTP response status=403 elapsedMs=42 location=https://example.com?ticket=secret-token cookieNames=SESSION',
      );
      log.record(
        '[auth] Unexpected response stage=portal-user-data status=401 host=webvpn.tsinghua.edu.cn bodyType=html bodyLength=99 preview="private-course-title password-value 654321 secret-token"',
      );
      log.record(
        '[auth] Credential recovery: cause=PortalSessionRejected trustedCredentialPresent=true.',
      );
      log.record(
        '[auth] Second-factor challenge: stage=webvpn trustedCredentialPresent=true.',
      );
      log.record('arbitrary password=password-value cookie=secret-token');
      log.record('[auth] cookie=secret-token');
      log.recordError(
        'flutter-error',
        StateError('password-value'),
        StackTrace.fromString(
          '#0 fn (package:thulium/pages/login_page.dart:12:3)\n#1 /home/private-file.dart:1:2',
        ),
      );
      final report = await log.snapshot();
      for (final secret in secrets) {
        expect(report, isNot(contains(secret)));
        expect(store.lines.join('\n'), isNot(contains(secret)));
      }
      expect(report, contains('HTTP GET endpoint=learn-preview'));
      expect(report, contains('status=403 elapsedMs=42'));
      expect(report, contains('cause=PortalSessionRejected'));
      expect(report, contains('stage=webvpn trustedCredentialPresent=true'));
      expect(report, contains('package:thulium/pages/login_page.dart:12:3'));
    },
  );

  test(
    'persisted events survive restart and are filtered again on import',
    () async {
      final store = _Store();
      final first = DiagnosticLog(
        store: store,
        now: () => DateTime.utc(2026, 11, 18),
      );
      addTearDown(first.dispose);
      first.record(
        '[auth][signin=2] Using the trusted-browser identity entry.',
      );
      first.record(
        '[auth] Session restored: trustedCredentialPresent=true deviceTrustConsent=true.',
      );
      first.record(
        '[auth] Credential recovery skipped: reason=missing-credentials.',
      );
      first.record(
        '[auth] HTTP timeout phase=body host=private-host elapsedMs=30000',
      );
      first.record(
        '[signin] attempt=2 stage=failed type=TwoFactorInteractionRequired',
      );
      final original = await first.snapshot();
      store.lines.add('2026-11-18T00:00:00.000Z unrecognized secret-value');
      final second = DiagnosticLog(
        store: store,
        now: () => DateTime.utc(2026, 11, 18),
      );
      addTearDown(second.dispose);
      expect(await second.snapshot(), original);
      expect(store.lines.join('\n'), isNot(contains('secret-value')));
    },
  );

  test('old logs expire and event count stays bounded', () async {
    final store = _Store()
      ..lines = [
        '2026-10-01T00:00:00.000Z [app] event=started',
        '2026-11-17T00:00:00.000Z [app] event=started',
      ];
    final log = DiagnosticLog(
      store: store,
      now: () => DateTime.utc(2026, 11, 18),
      maxEntries: 3,
    );
    addTearDown(log.dispose);
    await log.initialize();
    for (var index = 1; index <= 4; index++) {
      log.record('[signin] attempt=$index stage=start');
    }
    await log.flush();
    expect(store.lines, hasLength(3));
    expect(store.lines.first, contains('attempt=2'));
    expect(store.lines.last, contains('attempt=4'));
  });

  test(
    'storage failures do not discard in-memory diagnostics or prevent exporting',
    () async {
      final store = _Store()..fail = true;
      final log = DiagnosticLog(store: store);
      addTearDown(log.dispose);
      log.record(
        '[auth] Second-factor challenge: stage=information-portal trustedCredentialPresent=false.',
      );
      expect(
        await log.snapshot(),
        contains('stage=information-portal trustedCredentialPresent=false'),
      );
      store.fail = false;
      await log.flush();
      expect(store.lines.join('\n'), contains('information-portal'));
    },
  );

  test('overlapping flushes preserve the newest log snapshot', () async {
    final store = _Store()..blockedWrite = Completer<void>();
    final log = DiagnosticLog(store: store);
    addTearDown(log.dispose);
    log.record('[signin] attempt=1 stage=start');
    final first = log.flush();
    await store.writeStarted.future;
    log.record('[signin] attempt=1 stage=success');
    final second = log.flush();
    expect(store.writes, 1);
    store.blockedWrite!.complete();
    await Future.wait([first, second]);
    expect(store.lines.last, contains('stage=success'));
    expect(store.writes, 2);
  });
}

class _Store implements DiagnosticLogStore {
  List<String> lines = [];
  bool fail = false;
  int writes = 0;
  Completer<void>? blockedWrite;
  final writeStarted = Completer<void>();
  @override
  Future<List<String>> read() async {
    if (fail) throw StateError('synthetic read failure');
    return List.of(lines);
  }

  @override
  Future<void> write(List<String> value) async {
    writes++;
    if (!writeStarted.isCompleted) writeStarted.complete();
    if (writes == 1) await blockedWrite?.future;
    if (fail) throw StateError('synthetic write failure');
    lines = List.of(value);
  }
}
