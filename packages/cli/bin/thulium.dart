import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:thulium_campus/thulium_campus.dart';
import 'package:thulium_auth/thulium_auth.dart';
import 'package:thulium_cli/cli_auth_session_store.dart';

// Uppercase snake case is the project convention for named constants.
// ignore_for_file: constant_identifier_names

const _DEFAULT_FINGERPRINT_PREFIX = 'thulium-cli';

Future<void> main(List<String> arguments) async {
  final parser = _buildParser();
  try {
    final command = parser.parse(arguments);
    await _runCommand(command);
  } on FormatException catch (error) {
    stderr.writeln('Error: ${error.message}');
    stderr.writeln(parser.usage);
    exitCode = 2;
  } on CliAuthStorageException catch (error) {
    stderr.writeln('Secure storage error: ${error.message}');
    stderr.writeln(
      'Make sure an operating system keyring is available and unlocked.',
    );
    exitCode = 1;
  } catch (error) {
    stderr.writeln('Error: $error');
    exitCode = 1;
  }
}

ArgParser _buildParser() {
  final parser = ArgParser();
  parser.addCommand(
    'login',
    ArgParser()
      ..addFlag(
        'force',
        abbr: 'f',
        help: 'Ignore the stored session and log in again.',
      )
      ..addFlag('verbose', help: 'Print safe authentication diagnostics.'),
  );
  parser.addCommand('logout');
  parser.addCommand('status');
  parser.addCommand(
    'session',
    ArgParser()
      ..addCommand('inspect')
      ..addCommand('reveal-cookies'),
  );
  parser.addCommand(
    'schedule',
    ArgParser()..addFlag('verbose', help: 'Print safe request diagnostics.'),
  );
  return parser;
}

Future<void> _runCommand(ArgResults command) async {
  final name = command.command?.name;
  if (name == null) {
    stdout.writeln('Usage: thulium <login|logout|status|session|schedule>');
    return;
  }

  final store = CliAuthSessionStore();
  final client = TsinghuaAuthClient(
    sessionStore: store,
    twoFactorMethodHandler: _handleTwoFactorMethod,
    twoFactorCodeHandler: _readTwoFactorCode,
    trace: _verboseRequested(name, command.command!)
        ? (message) => stderr.writeln('[auth] $message')
        : null,
  );

  switch (name) {
    case 'login':
      await _login(client, force: command.command!['force'] as bool);
    case 'logout':
      // Each CLI invocation starts with an empty in-memory cookie jar. Restore
      // the persisted session so the logout request can invalidate it remotely.
      await client.restore();
      await client.logout();
      stdout.writeln('Logged out.');
    case 'status':
      final session = await client.restore();
      if (session == null) {
        stdout.writeln('Not logged in.');
      } else {
        stdout.writeln('Logged in as ${session.userId}.');
      }
    case 'session':
      await _runSessionCommand(client, command.command!);
    case 'schedule':
      final session = await client.restore();
      if (session == null) {
        throw StateError('Not logged in. Run `thulium login` first.');
      }
      stdout.writeln('Fetching the current academic timetable...');
      final schedule = await CourseScheduleService(client).loadCurrentTerm();
      _printSchedule(schedule);
  }
}

Future<void> _runSessionCommand(
  TsinghuaAuthClient client,
  ArgResults command,
) async {
  final action = command.command?.name;
  if (action == null) {
    stdout.writeln('Usage: thulium session <inspect|reveal-cookies>');
    return;
  }
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

bool _verboseRequested(String commandName, ArgResults command) =>
    (commandName == 'login' || commandName == 'schedule') &&
    command['verbose'] as bool;

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

  stdout.writeln('Signing in...');
  final session = await client.login(
    userId: userId,
    password: password,
    fingerprint: _buildFingerprint(),
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

Future<TwoFactorMethod> _handleTwoFactorMethod(TwoFactorOptions options) async {
  stdout.writeln('Two-factor authentication is required.');
  stdout.writeln('Available methods:');
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
    stdout.writeln('  ${index + 1}. ${methods[index].label}');
  }
  if (methods.isEmpty) {
    throw StateError('The account has no available two-factor methods.');
  }

  final choice = int.tryParse(_readLine('Choose a method: '));
  if (choice == null || choice < 1 || choice > methods.length) {
    throw const FormatException('The selected method is unavailable.');
  }
  return methods[choice - 1].method;
}

Future<void> _readTwoFactorCode(TwoFactorCodeVerifier verifyCode) async {
  // This callback runs only after SEND_CODE succeeds, so the notification is
  // expected to be available before the user is asked for the code.
  stdout.writeln('A verification code was sent.');
  while (true) {
    final code = _readLine('Verification code: ');
    if (await verifyCode(code)) return;
    stdout.writeln('The verification code was not accepted. Please try again.');
  }
}

String _buildFingerprint() {
  // A stable, non-secret identifier makes the identity provider's device
  // fingerprint consistent across CLI invocations without storing a password.
  return '$_DEFAULT_FINGERPRINT_PREFIX:${Platform.operatingSystem}:'
      '${Platform.localHostname}';
}

String _readLine(String prompt) {
  stdout.write(prompt);
  return stdin.readLineSync()?.trim() ?? '';
}

String _readSecret(String prompt) {
  stdout.write(prompt);
  if (!stdin.hasTerminal) {
    return stdin.readLineSync() ?? '';
  }

  final echoMode = stdin.echoMode;
  try {
    stdin.echoMode = false;
    return stdin.readLineSync() ?? '';
  } finally {
    stdin.echoMode = echoMode;
    stdout.writeln();
  }
}
