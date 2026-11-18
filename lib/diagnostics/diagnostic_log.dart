// ignore_for_file: constant_identifier_names

import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class DiagnosticLogStore {
  Future<List<String>> read();
  Future<void> write(List<String> lines);
}

final class LocalDiagnosticLogStore implements DiagnosticLogStore {
  static const _KEY = 'thulium.diagnostics.v1';
  SharedPreferencesAsync? _preferences;
  SharedPreferencesAsync get _storage =>
      _preferences ??= SharedPreferencesAsync();
  @override
  Future<List<String>> read() async => await _storage.getStringList(_KEY) ?? [];
  @override
  Future<void> write(List<String> lines) => _storage.setStringList(_KEY, lines);
}

/// Stores only recognized structural events, never arbitrary console messages.
/// Filtering happens before events reach memory, persistence or export.
final class DiagnosticLog {
  DiagnosticLog({
    DiagnosticLogStore? store,
    DateTime Function()? now,
    this.maxEntries = 2000,
  }) : _store = store ?? LocalDiagnosticLogStore(),
       _now = now ?? DateTime.now;

  static final instance = DiagnosticLog();
  final DiagnosticLogStore _store;
  final DateTime Function() _now;
  final int maxEntries;
  final _lines = <String>[];
  Future<void>? _initialization;
  Future<void> _writes = Future.value();
  Timer? _persistTimer;
  bool _ready = false;
  bool _installed = false;
  AppLifecycleListener? _lifecycle;

  void install() {
    if (_installed) return;
    _installed = true;
    final previousPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) record(message);
      previousPrint(message, wrapWidth: wrapWidth);
    };
    final previousFlutterError = FlutterError.onError;
    FlutterError.onError = (details) {
      recordError('flutter-error', details.exception, details.stack);
      previousFlutterError?.call(details);
    };
    final previousPlatformError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      recordError('platform-error', error, stack);
      return previousPlatformError?.call(error, stack) ?? false;
    };
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        record('[app] event=lifecycle-${state.name}');
        if (state == AppLifecycleState.paused ||
            state == AppLifecycleState.detached) {
          unawaited(flush());
        }
      },
    );
    record('[app] event=started');
    unawaited(initialize());
  }

  Future<void> initialize() => _initialization ??= _load();

  Future<void> _load() async {
    try {
      final saved = await _store.read();
      final current = List<String>.of(_lines);
      _lines.clear();
      for (final line in saved) {
        final split = line.indexOf(' ');
        if (split < 0 || DateTime.tryParse(line.substring(0, split)) == null) {
          continue;
        }
        final safe = sanitizeDiagnosticMessage(line.substring(split + 1));
        if (safe != null) _lines.add('${line.substring(0, split)} $safe');
      }
      _lines.addAll(current);
    } catch (_) {
      _lines.add(
        '${_now().toUtc().toIso8601String()} [app] event=log-storage-read-failed',
      );
    }
    _ready = true;
    _trim();
    _schedule();
  }

  void record(String message) {
    final safe = sanitizeDiagnosticMessage(message);
    if (safe == null) return;
    _lines.add('${_now().toUtc().toIso8601String()} $safe');
    _trim();
    if (_ready) _schedule();
  }

  void recordError(String kind, Object error, StackTrace? stack) {
    record('[app] event=$kind type=${error.runtimeType}');
    if (stack == null) return;
    for (final match in RegExp(
      r'package:[a-zA-Z0-9_/.\-]+\.dart:\d+:\d+',
    ).allMatches(stack.toString()).take(8)) {
      record('[app] frame=${match.group(0)}');
    }
  }

  void _trim() {
    final cutoff = _now().toUtc().subtract(const Duration(days: 7));
    _lines.removeWhere(
      (line) =>
          DateTime.parse(line.substring(0, line.indexOf(' '))).isBefore(cutoff),
    );
    if (_lines.length > maxEntries) {
      _lines.removeRange(0, _lines.length - maxEntries);
    }
  }

  void _schedule() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(seconds: 1), () => unawaited(flush()));
  }

  Future<void> flush() async {
    await initialize();
    _persistTimer?.cancel();
    _persistTimer = null;
    final snapshot = List<String>.of(_lines);
    _writes = _writes.then((_) async {
      try {
        await _store.write(snapshot);
      } catch (_) {
        // Logging failure must not break login, export or schedule more writes.
      }
    });
    await _writes;
  }

  Future<String> snapshot() async {
    await flush();
    _trim();
    return _lines.join('\n');
  }

  @visibleForTesting
  void dispose() {
    _persistTimer?.cancel();
    _lifecycle?.dispose();
  }
}

const _TYPES = {
  'StateError',
  'FormatException',
  'TimeoutException',
  'SocketException',
  'HttpException',
  'PlatformException',
  'MissingPluginException',
  'PortalCsrfUnavailable',
  'PortalSessionRejected',
  'CourseScheduleException',
  'CourseScheduleSessionExpired',
  'TwoFactorInteractionRequired',
  'UnsupportedError',
  'FlutterError',
  'TypeError',
};

const _EVENTS = {
  'started',
  'flutter-error',
  'platform-error',
  'log-storage-read-failed',
  'session-restore-failed',
  'preferences-restore-failed',
  'preferences-write-failed',
  'lifecycle-resumed',
  'lifecycle-inactive',
  'lifecycle-paused',
  'lifecycle-hidden',
  'lifecycle-detached',
  'portal-cookies-imported',
  'portal-silent-reconnect',
  'portal-silent-reconnect-failed',
  'portal-cached-token-verified',
  'portal-refreshed-token-verified',
  'trusted-confirmation',
  'credential-retry',
  'trust-accepted',
  'trust-token-received',
  'trust-rejected',
  'trust-no-token',
  'trust-failed',
  'verification-sent',
  'verification-accepted',
  'verification-rejected',
  'learn-main-probe',
  'learn-rebuild',
  'course-load-failed',
  'homework-load-failed',
  'calendar-load-failed',
  'export-failed',
  'calendar-expired',
  'calendar-verification-required',
  'export-requested',
  'network-timeout',
};

const _MESSAGES = {
  'Trying portal reconnection with the saved SSO cookies.':
      'portal-silent-reconnect',
  'Silent portal reconnection did not complete.':
      'portal-silent-reconnect-failed',
  'A stored portal CSRF token passed the account probe.':
      'portal-cached-token-verified',
  'The portal CSRF token remained usable after reconnect.':
      'portal-refreshed-token-verified',
  'Using the trusted-browser identity entry.': 'trusted-confirmation',
  'Reconnecting with saved credentials; retrying once.': 'credential-retry',
  'Trusted-device registration accepted.': 'trust-accepted',
  'Trusted-device credential received.': 'trust-token-received',
  'Trusted-device registration was not accepted.': 'trust-rejected',
  'Trusted-device registration needs no legacy credential.': 'trust-no-token',
  'Trusted-device registration failed; continuing login.': 'trust-failed',
  '2FA verification code request succeeded.': 'verification-sent',
  '2FA code verification succeeded.': 'verification-accepted',
  '2FA code verification was rejected; awaiting corrected input.':
      'verification-rejected',
  'Learn session rejected; verifying the main session.': 'learn-main-probe',
  'Main session verified; rebuilding Learn without a password.':
      'learn-rebuild',
  'session expired': 'calendar-expired',
  'interactive two-factor verification required':
      'calendar-verification-required',
};

const _ENDPOINTS = {
  '/wengine-vpn/cookie': 'portal-cookie',
  '/do/off/ui/auth/login/form/': 'identity-form',
  '/do/off/ui/auth/login/checkSingle': 'identity-confirmation',
  '/security_check': 'identity-confirmation',
  '/do/off/ui/auth/login/check': 'identity-credentials',
  '/b/doubleAuth/personal/saveFinger': 'device-registration',
  '/b/doubleAuth/login': 'second-factor',
  '/grjbxx': 'portal-account',
  'onlineAppRedirect': 'portal-roaming',
  'downloadPdfStream': 'learn-preview',
  'beforePlay': 'learn-viewer',
  'kjxxbByWlkcidAndSizeForStudent': 'learn-materials',
  'loadCourseBySemesterId': 'learn-courses',
  'zyList': 'learn-homework',
  'getCurrentAndNextSemester': 'academic-term',
  'jxmh_out.do': 'academic-calendar',
  'portal3rd.do': 'academic-calendar-secondary',
  '/login': 'webvpn-entry',
  '/logout': 'logout',
};

/// An allowlist of event shapes, rather than redaction of arbitrary prose.
/// Unknown messages, response previews, URLs and request values are discarded.
String? sanitizeDiagnosticMessage(String input) {
  final prefix = RegExp(
    r'^\[(auth|signin|study|calendar|app)\](?:\[[^\]\r\n]{0,80}\])?\s*',
  ).firstMatch(input);
  if (prefix == null) {
    if (input.startsWith('Thulium session restoration failed:')) {
      return '[app] event=session-restore-failed';
    }
    if (input.startsWith('Thulium preference restoration failed:')) {
      return '[app] event=preferences-restore-failed';
    }
    if (input.startsWith('Thulium preference persistence failed:')) {
      return '[app] event=preferences-write-failed';
    }
    return null;
  }
  final scope = prefix.group(1)!;
  final body = input.substring(prefix.end);
  String? value(String name) =>
      RegExp('(?:^|[ ;])$name=([A-Za-z0-9_-]+)').firstMatch(body)?.group(1);
  final type = _TYPES.contains(value('type')) ? value('type') : 'other';
  final event = value('event');
  if (_EVENTS.contains(event)) {
    return '[$scope] event=$event${body.contains('type=') ? ' type=$type' : ''}';
  }
  if (scope == 'app') {
    final frame = RegExp(
      r'^frame=(package:[a-zA-Z0-9_/.\-]+\.dart:\d+:\d+)$',
    ).firstMatch(body);
    return frame == null ? null : '[app] frame=${frame.group(1)}';
  }
  if (scope == 'signin') {
    final stage = value('stage');
    if (!const {
      'start',
      'success',
      'failed',
      'duplicate_submit_ignored',
      'trust_choice_reused',
      'trust_dialog_shown',
      'trust_dialog_resolved',
    }.contains(stage)) {
      return null;
    }
    final attempt = int.tryParse(value('attempt') ?? '');
    return '[signin] attempt=${attempt ?? 0} stage=$stage${stage == 'failed' ? ' type=$type' : ''}';
  }
  final request = RegExp(r'^HTTP (GET|POST) ').firstMatch(body);
  if (request != null) {
    var endpoint = 'other';
    final existing = value('endpoint');
    if (_ENDPOINTS.values.contains(existing)) {
      endpoint = existing!;
    } else {
      for (final entry in _ENDPOINTS.entries) {
        if (body.contains(entry.key)) {
          endpoint = entry.value;
          break;
        }
      }
    }
    return '[$scope] HTTP ${request.group(1)} endpoint=$endpoint';
  }
  if (body.startsWith('HTTP response ')) {
    final status = int.tryParse(value('status') ?? '') ?? 0;
    final elapsed = int.tryParse(value('elapsedMs') ?? '') ?? 0;
    return '[$scope] HTTP response status=$status elapsedMs=$elapsed';
  }
  if (body.startsWith('HTTP timeout ')) return '[$scope] event=network-timeout';
  if (body.startsWith('Unexpected response ')) {
    final stage = value('stage');
    final safeStage =
        const {
          'portal-csrf-cookie',
          'portal-user-data',
          'portal-roaming',
          'learning-landing',
          'learning-courses',
          'learning-materials',
          'learning-homework',
          'semester-list',
          'primary-calendar',
          'secondary-calendar',
        }.contains(stage)
        ? stage
        : 'other';
    final bodyType =
        const {'empty', 'html', 'json', 'other'}.contains(value('bodyType'))
        ? value('bodyType')
        : 'other';
    return '[$scope] Unexpected response stage=$safeStage status=${int.tryParse(value('status') ?? '') ?? 0} bodyType=$bodyType bodyLength=${int.tryParse(value('bodyLength') ?? '') ?? 0}';
  }
  if (body.startsWith('Credential recovery:')) {
    final cause = _TYPES.contains(value('cause')) ? value('cause') : 'other';
    return '[$scope] Credential recovery: cause=$cause trustedCredentialPresent=${value('trustedCredentialPresent') == 'true'}';
  }
  if (body.startsWith('Session restored:')) {
    return '[$scope] Session restored: trustedCredentialPresent=${value('trustedCredentialPresent') == 'true'} deviceTrustConsent=${value('deviceTrustConsent') == 'true'}';
  }
  if (body.startsWith('Session recovery unavailable:') ||
      body.startsWith('Credential recovery skipped:')) {
    final reason =
        const {
          'no-session',
          'account-mismatch',
          'missing-credentials',
        }.contains(value('reason'))
        ? value('reason')
        : 'other';
    final action = body.startsWith('Session recovery')
        ? 'Session recovery unavailable'
        : 'Credential recovery skipped';
    return '[$scope] $action: reason=$reason';
  }
  if (body.startsWith('Second-factor challenge:')) {
    final stage = value('stage') == 'webvpn' ? 'webvpn' : 'information-portal';
    return '[$scope] Second-factor challenge: stage=$stage trustedCredentialPresent=${value('trustedCredentialPresent') == 'true'}';
  }
  final fixed = _MESSAGES[body];
  if (fixed != null) return '[$scope] event=$fixed';
  if (body.startsWith('Information-portal cookie bundle imported:')) {
    return '[$scope] event=portal-cookies-imported';
  }
  final failed = RegExp(
    r'^(course loading failed|homework loading failed|loading failed|export failed) type=',
  ).firstMatch(body);
  if (failed != null) {
    final name = switch (failed.group(1)) {
      'course loading failed' => 'course-load-failed',
      'homework loading failed' => 'homework-load-failed',
      'loading failed' => 'calendar-load-failed',
      _ => 'export-failed',
    };
    return '[$scope] event=$name type=$type';
  }
  return null;
}
