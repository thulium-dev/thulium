import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
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
  return parser;
}

Future<void> _runCommand(ArgResults command) async {
  final name = command.command?.name;
  if (name == null) {
    stdout.writeln('Usage: thulium <login|logout|status>');
    return;
  }

  final store = CliAuthSessionStore();
  final client = TsinghuaAuthClient(
    sessionStore: store,
    twoFactorMethodHandler: _handleTwoFactorMethod,
    twoFactorCodeHandler: _readTwoFactorCode,
    trace: name == 'login' && command.command!['verbose'] as bool
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
  }
}

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
