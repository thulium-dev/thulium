import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:thulium_campus/thulium_campus.dart';
import 'package:thulium_auth/thulium_auth.dart';
import 'package:thulium_cli/cli_auth_session_store.dart';
import 'package:thulium_cli/cli_course_schedule_cache_store.dart';
import 'package:thulium_cli/cli_learn_course_cache_store.dart';
import 'package:thulium_cli/cli_session_reconnect.dart';
import 'package:thulium_cli/learn_course_formatter.dart';
import 'package:thulium_cli/learn_homework_formatter.dart';
import 'package:thulium_cli/learn_materials_formatter.dart';
import 'package:thulium_cli/material_download_file.dart';

// ignore_for_file: constant_identifier_names
const _DEFAULT_FINGERPRINT_PREFIX = 'thulium-cli';

/// Executes CLI operations. Construction and help never access secure storage.
class CliRuntime {
  Future<void> login(Map<String, dynamic> options) async {
    final context = _context('login', options['verbose'] == true);
    await _login(context.client, force: options['force'] as bool);
  }

  Future<void> logout(Map<String, dynamic> options) async {
    final context = _context('logout', options['verbose'] == true);
    // Each CLI invocation starts with an empty in-memory cookie jar. Restore
    // the persisted session so the logout request can invalidate it remotely.
    await context.client.restore();
    try {
      await context.client.logout();
    } finally {
      await context.calendarCache.clear();
      await context.learnCache.clear();
    }
    stdout.writeln('Logged out.');
  }

  Future<void> status(Map<String, dynamic> options) async {
    final context = _context('status', options['verbose'] == true);
    final session = await context.client.restore();
    if (session == null) {
      stdout.writeln('Not logged in.');
    } else {
      stdout.writeln('Logged in as ${session.userId}.');
    }
  }

  Future<void> schedule(Map<String, dynamic> options) async {
    final context = _context('schedule', options['verbose'] == true);
    final session = await context.client.restore();
    if (session == null) {
      throw StateError('Not logged in. Run `thulium login` first.');
    }
    stdout.writeln('Loading the current academic calendar...');
    final schedule = await _loadScheduleWithReconnect(
      context.client,
      context.reconnect,
      session,
      cache: context.calendarCache,
      forceRefresh: options['refresh'] as bool,
    );
    _printSchedule(schedule);
  }

  Future<void> courses(Map<String, dynamic> options) async {
    final context = _context('learn-courses', options['verbose'] == true);
    final session = await context.client.restore();
    if (session == null) {
      throw StateError('Not logged in. Run `thulium login` first.');
    }
    final semester =
        (options['semester'] as String?) ??
        AcademicSemester.forDate(DateTime.now());
    final catalogService = LearnCourseCatalogService(
      context.client,
      cache: context.learnCache,
    );
    final catalog = await context.reconnect.run(
      commandName: 'learn-courses',
      savedSession: session,
      request: (isRetry) => catalogService.loadSemester(
        semester,
        forceRefresh: isRetry || options['refresh'] as bool,
      ),
      shouldReconnect: (error) =>
          error is PortalCsrfUnavailable || error is PortalSessionRejected,
    );
    if (catalogService.lastSource == LearnCourseSource.staleCache) {
      stderr.writeln('Update failed; showing the saved course list.');
    }
    stdout.writeln(
      formatLearnCourses(
        catalog.rawResponse ??
            {
              'currentUser': catalog.userId,
              'resultList': [
                for (final course in catalog.courses)
                  {
                    'wlkcid': course.id,
                    'kcm': course.name,
                    'ywkcm': course.englishName,
                    'jsm': course.teacherName,
                    'sjddb': course.schedule,
                  },
              ],
            },
        semester: semester,
      ),
    );
  }

  Future<void> homework(Map<String, dynamic> options) async {
    final context = _context('learn-homework', options['verbose'] == true);
    final session = await context.client.restore();
    if (session == null) {
      throw StateError('Not logged in. Run `thulium login` first.');
    }
    final semester =
        (options['semester'] as String?) ??
        AcademicSemester.forDate(DateTime.now());
    final catalogService = LearnCourseCatalogService(
      context.client,
      cache: context.learnCache,
    );
    final homework = await context.reconnect.run(
      commandName: 'learn-homework',
      savedSession: session,
      request: (isRetry) async {
        final catalog = await catalogService.loadSemester(
          semester,
          forceRefresh: isRetry || options['refresh'] as bool,
        );
        if (catalogService.lastSource == LearnCourseSource.staleCache) {
          stderr.writeln('Update failed; using the saved course list.');
        }
        return LearnHomeworkService(context.client).fetchCourses(catalog);
      },
      shouldReconnect: (error) =>
          error is PortalCsrfUnavailable || error is PortalSessionRejected,
    );
    stdout.writeln(
      formatLearnHomework(
        homework,
        studentId: session.userId,
        semester: semester,
      ),
    );
  }

  Future<void> materials(Map<String, dynamic> options) async {
    final size = int.tryParse(options['size'] as String);
    if (size == null || size <= 0) {
      throw const FormatException('--size must be a positive integer.');
    }
    final courseId = options['course-id'] as String?;
    if (courseId != null && courseId.trim().isEmpty) {
      throw const FormatException('--course-id must not be empty.');
    }
    final context = _context('learn-materials', options['verbose'] == true);
    final session = await context.client.restore();
    if (session == null) {
      throw StateError('Not logged in. Run `thulium login` first.');
    }
    final semester =
        (options['semester'] as String?) ??
        AcademicSemester.forDate(DateTime.now());
    final catalogService = LearnCourseCatalogService(
      context.client,
      cache: context.learnCache,
    );
    final materials = await context.reconnect.run(
      commandName: 'learn-materials',
      savedSession: session,
      request: (isRetry) async {
        final catalog = await catalogService.loadSemester(
          semester,
          forceRefresh: isRetry || options['refresh'] as bool,
        );
        if (catalogService.lastSource == LearnCourseSource.staleCache) {
          stderr.writeln('Update failed; using the saved course list.');
        }
        return LearnMaterialService(context.client).fetchCourses(
          catalog,
          courseId: options['course-id'] as String?,
          size: size,
        );
      },
      shouldReconnect: (error) =>
          error is PortalCsrfUnavailable || error is PortalSessionRejected,
    );
    stdout.writeln(
      formatLearnMaterials(
        materials,
        studentId: session.userId,
        semester: semester,
      ),
    );
  }

  Future<void> downloadMaterial(
    Map<String, dynamic> options, {
    bool cover = false,
  }) async {
    for (final key in ['file-id', 'course-id']) {
      final value = options[key] as String?;
      if (value == null || !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value)) {
        throw FormatException(
          '--$key is required and must be a valid Learn ID.',
        );
      }
    }
    final output =
        options['output'] as String? ??
        '${options['file-id']}${cover ? '-cover' : ''}.pdf';
    if (output.trim().isEmpty) {
      throw const FormatException('--output must not be empty.');
    }
    if (!(options['force'] as bool) &&
        await FileSystemEntity.type(output, followLinks: false) !=
            FileSystemEntityType.notFound) {
      throw FileSystemException(
        'Output already exists. Use --force to replace it.',
        output,
      );
    }
    final context = _context(
      cover ? 'learn-materials-cover' : 'learn-materials',
      options['verbose'] == true,
    );

    final session = await context.client.restore();
    if (session == null) {
      throw StateError('Not logged in. Run `thulium login` first.');
    }

    final bytes = await context.reconnect.run(
      commandName: cover ? 'learn-materials-cover' : 'learn-materials download',
      savedSession: session,
      request: (_) {
        final service = LearnMaterialService(context.client);
        final download = cover ? service.downloadPdfCover : service.downloadPdf;
        return download(
          fileId: options['file-id'] as String,
          courseId: options['course-id'] as String,
        );
      },
      shouldReconnect: (error) =>
          error is PortalCsrfUnavailable || error is PortalSessionRejected,
    );
    final saved = await saveMaterialDownload(
      bytes,
      outputPath: output,
      overwrite: options['force'] as bool,
    );
    stdout.writeln('Saved ${bytes.length} bytes to ${saved.path}');
    return;
  }

  Future<void> inspectSession(Map<String, dynamic> options) =>
      _runSessionCommand(_context('session', false).client, 'inspect');
  Future<void> revealCookies(Map<String, dynamic> options) =>
      _runSessionCommand(_context('session', false).client, 'reveal-cookies');
}

typedef _Context = ({
  TsinghuaAuthClient client,
  CliSessionReconnect reconnect,
  CourseScheduleCache calendarCache,
  LearnCourseCache learnCache,
});

_Context _context(String name, bool verbose) {
  final store = CliAuthSessionStore();
  final calendarCache = CourseScheduleCache(CliCourseScheduleCacheStore());
  final learnCache = LearnCourseCache(CliLearnCourseCacheStore());
  final promptOutput =
      name == 'learn-homework' ||
          name == 'learn-materials' ||
          name == 'learn-materials-cover'
      ? stderr
      : stdout;
  final client = TsinghuaAuthClient(
    sessionStore: store,
    credentialStore: store,
    twoFactorMethodHandler: (options) =>
        _handleTwoFactorMethod(options, output: promptOutput),
    twoFactorCodeHandler: (verify) =>
        _readTwoFactorCode(verify, output: promptOutput),
    twoFactorTrustHandler: () => _askToTrustDevice(output: promptOutput),
    trace: verbose ? (message) => stderr.writeln('[auth] $message') : null,
  );
  final reconnect = CliSessionReconnect(
    credentialStore: store,
    signIn: ({required userId, required password, required fingerprint}) async {
      await client.login(
        userId: userId,
        password: password,
        fingerprint: fingerprint,
      );
    },
    interactive: stdin.hasTerminal,
    askToSignIn: (commandName) {
      final answer = _readLine(
        'Sign in again to retry $commandName? [Y/n]: ',
        output: promptOutput,
      ).toLowerCase();
      return answer.isEmpty || answer == 'y' || answer == 'yes';
    },
    readPassword: () => _readSecret('Password: ', output: promptOutput),
    writeMessage: promptOutput.writeln,
    writeError: stderr.writeln,
  );
  return (
    client: client,
    reconnect: reconnect,
    calendarCache: calendarCache,
    learnCache: learnCache,
  );
}

Future<CourseSchedule> _loadScheduleWithReconnect(
  TsinghuaAuthClient client,
  CliSessionReconnect reconnect,
  AuthSession savedSession, {
  required CourseScheduleCache cache,
  required bool forceRefresh,
}) async {
  CourseScheduleSource? source;
  final schedule = await reconnect.run(
    commandName: 'schedule',
    savedSession: savedSession,
    request: (isRetry) async {
      final service = CourseScheduleService(
        client,
        cache: cache,
        trace: (message) {
          if (client.trace != null) stderr.writeln('[calendar] $message');
        },
      );
      final result = await service.loadCurrentTerm(
        forceRefresh: forceRefresh || isRetry,
      );
      source = service.lastSource;
      return result;
    },
    shouldReconnect: (error) =>
        error is CourseScheduleSessionExpired ||
        (error is CourseScheduleException &&
            error.cause is PortalCsrfUnavailable),
  );
  if (source == CourseScheduleSource.freshCache) {
    stdout.writeln('Using the saved academic calendar.');
  } else if (source == CourseScheduleSource.staleCache) {
    stdout.writeln(
      'The update failed; showing an older saved academic calendar.',
    );
  }
  return schedule;
}

Future<void> _runSessionCommand(
  TsinghuaAuthClient client,
  String action,
) async {
  if (action == 'reveal-cookies' &&
      (!stdin.hasTerminal || !stdout.hasTerminal)) {
    throw StateError(
      'Cookie values can only be revealed in an interactive terminal.',
    );
  }

  final session = await client.restore();
  if (session == null) {
    stdout.writeln('No stored session. Run `thulium login` first.');
    return;
  }

  switch (action) {
    case 'inspect':
      _printSessionMetadata(session);
    case 'reveal-cookies':
      await _revealSessionCookies(session);
  }
}

void _printSessionMetadata(AuthSession session) {
  final now = DateTime.now().toUtc();
  final cookies = session.scopedCookies;
  stdout.writeln('Account: ${session.userId}');
  stdout.writeln('Scoped cookies: ${cookies.length}');
  if (cookies.isEmpty) {
    stdout.writeln('No scoped cookies are stored.');
    return;
  }

  for (final cookie in cookies) {
    final expiry = cookie.expiresAt?.toUtc();
    final expiryLabel = expiry == null
        ? 'session cookie'
        : expiry.isBefore(now)
        ? 'expired ${expiry.toIso8601String()}'
        : 'expires ${expiry.toIso8601String()}';
    stdout.writeln(
      '- ${cookie.name}: domain=${cookie.domain}, path=${cookie.path}, '
      'hostOnly=${cookie.hostOnly}, secure=${cookie.secure}, $expiryLabel',
    );
  }
  stdout.writeln('Cookie values are hidden.');
}

Future<void> _revealSessionCookies(AuthSession session) async {
  if (!stdin.hasTerminal || !stdout.hasTerminal) {
    throw StateError(
      'Cookie values can only be revealed in an interactive terminal.',
    );
  }

  stderr.writeln(
    'Warning: These cookies are active login credentials. Anyone who sees '
    'them may be able to use your account until the session expires or is '
    'revoked. Do not capture, share, or redirect this output.',
  );
  if (_readLine('Type REVEAL COOKIES to continue: ') != 'REVEAL COOKIES') {
    stdout.writeln('Cancelled.');
    return;
  }

  if (session.scopedCookies.isEmpty) {
    stdout.writeln('No scoped cookies are stored.');
    return;
  }

  stdout.writeln('Stored cookie values (sensitive):');
  for (final cookie in session.scopedCookies) {
    // JSON string encoding keeps control characters from affecting the
    // terminal while leaving each secret value visible for manual inspection.
    stdout.writeln(
      '${cookie.name}=${jsonEncode(cookie.value)}\t'
      'domain=${cookie.domain}; path=${cookie.path}; '
      'hostOnly=${cookie.hostOnly}; secure=${cookie.secure}',
    );
  }
}

void _printSchedule(CourseSchedule schedule) {
  final courses = schedule.occurrences.toList()
    ..sort((left, right) => left.startsAt.compareTo(right.startsAt));
  stdout.writeln('${schedule.term.name} (${schedule.term.weekCount} weeks)');
  stdout.writeln('Fetched ${courses.length} course occurrences.');
  if (courses.isEmpty) {
    stdout.writeln('No course occurrences were returned.');
    return;
  }

  for (final course in courses) {
    final start = course.startsAt;
    final end = course.endsAt;
    final date =
        '${start.year.toString().padLeft(4, '0')}-'
        '${start.month.toString().padLeft(2, '0')}-'
        '${start.day.toString().padLeft(2, '0')}';
    final startTime =
        '${start.hour.toString().padLeft(2, '0')}:'
        '${start.minute.toString().padLeft(2, '0')}';
    final endTime =
        '${end.hour.toString().padLeft(2, '0')}:'
        '${end.minute.toString().padLeft(2, '0')}';
    final location = course.location.isEmpty ? '' : ' @ ${course.location}';
    stdout.writeln(
      '$date ${_WEEKDAY_NAMES[start.weekday - 1]} '
      '$startTime-$endTime  ${course.name}$location',
    );
  }
}

const _WEEKDAY_NAMES = <String>[
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

Future<void> _login(TsinghuaAuthClient client, {required bool force}) async {
  while (true) {
    try {
      await _loginAttempt(client, force: force);
      return;
    } catch (error) {
      // A failed password, expired verification code, or temporary network
      // error should not terminate an interactive login session. Each retry
      // starts the complete flow again so stale cookies and one-time codes are
      // not accidentally reused.
      stderr.writeln('Login attempt failed: $error');
      if (!_askToRetry()) return;
      force = true;
    }
  }
}

Future<void> _loginAttempt(
  TsinghuaAuthClient client, {
  required bool force,
}) async {
  if (!force) {
    final existing = await client.restore();
    if (existing != null) {
      stdout.writeln('Already logged in as ${existing.userId}.');
      stdout.writeln('Use `thulium login --force` to replace the session.');
      return;
    }
  }

  final userId = _readLine('Tsinghua student ID: ');
  if (userId.isEmpty) throw const FormatException('Student ID is required.');

  // The password is read without terminal echo and is never passed as a
  // command-line argument, where it could be exposed through process listings.
  final password = _readSecret('Password: ');
  if (password.isEmpty) throw const FormatException('Password is required.');

  // Preserve the trusted-device identity on forced reauthentication. The
  // account check prevents reusing another user's fingerprint on this host.
  final previousSession = await client.restore();
  final fingerprint = previousSession?.userId == userId
      ? previousSession!.fingerprint
      : _buildFingerprint();

  stdout.writeln('Signing in...');
  final session = await client.login(
    userId: userId,
    password: password,
    fingerprint: fingerprint,
  );
  stdout.writeln('Login succeeded for ${session.userId}.');
  stdout.writeln('The session was saved in the operating system keyring.');
}

bool _askToRetry() {
  if (!stdin.hasTerminal) return false;
  final answer = _readLine('Retry login? [Y/n]: ').toLowerCase();
  // Retrying is the default because transient network failures and expired
  // one-time codes are common during interactive authentication.
  return answer.isEmpty || answer == 'y' || answer == 'yes';
}

Future<TwoFactorMethod> _handleTwoFactorMethod(
  TwoFactorOptions options, {
  IOSink? output,
}) async {
  final sink = output ?? stdout;
  sink.writeln('Two-factor authentication is required.');
  sink.writeln('Available methods:');
  final methods = <({TwoFactorMethod method, String label})>[];
  if (options.hasWeChat) {
    methods.add((method: TwoFactorMethod.wechat, label: 'WeChat'));
  }
  if (options.phone != null) {
    methods.add((
      method: TwoFactorMethod.mobile,
      label: 'SMS (${options.phone})',
    ));
  }
  if (options.hasTotp) {
    methods.add((method: TwoFactorMethod.totp, label: 'TOTP'));
  }
  for (var index = 0; index < methods.length; index++) {
    sink.writeln('  ${index + 1}. ${methods[index].label}');
  }
  if (methods.isEmpty) {
    throw StateError('The account has no available two-factor methods.');
  }

  final choice = int.tryParse(_readLine('Choose a method: ', output: sink));
  if (choice == null || choice < 1 || choice > methods.length) {
    throw const FormatException('The selected method is unavailable.');
  }
  return methods[choice - 1].method;
}

Future<void> _readTwoFactorCode(
  TwoFactorCodeVerifier verifyCode, {
  IOSink? output,
}) async {
  final sink = output ?? stdout;
  // This callback runs only after SEND_CODE succeeds, so the notification is
  // expected to be available before the user is asked for the code.
  sink.writeln('A verification code was sent.');
  while (true) {
    final code = _readLine('Verification code: ', output: sink);
    if (await verifyCode(code)) return;
    sink.writeln('The verification code was not accepted. Please try again.');
  }
}

Future<bool> _askToTrustDevice({IOSink? output}) async {
  final sink = output ?? stdout;
  sink.writeln(
    'Trust this device to reduce future verification prompts? Only choose yes '
    'on a device you control.',
  );
  final answer = _readLine(
    'Trust this device? [y/N]: ',
    output: sink,
  ).toLowerCase();
  return answer == 'y' || answer == 'yes';
}

String _buildFingerprint() {
  // A stable, non-secret identifier makes the identity provider's device
  // fingerprint consistent across CLI invocations without storing a password.
  return '$_DEFAULT_FINGERPRINT_PREFIX:${Platform.operatingSystem}:'
      '${Platform.localHostname}';
}

String _readLine(String prompt, {IOSink? output}) {
  (output ?? stdout).write(prompt);
  return stdin.readLineSync()?.trim() ?? '';
}

String _readSecret(String prompt, {IOSink? output}) {
  final sink = output ?? stdout;
  sink.write(prompt);
  if (!stdin.hasTerminal) {
    return stdin.readLineSync() ?? '';
  }

  final echoMode = stdin.echoMode;
  try {
    stdin.echoMode = false;
    return stdin.readLineSync() ?? '';
  } finally {
    stdin.echoMode = echoMode;
    sink.writeln();
  }
}
