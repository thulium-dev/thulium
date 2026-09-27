import 'package:test/test.dart';
import 'package:thulium_auth/thulium_auth.dart';
import 'package:thulium_cli/cli_session_reconnect.dart';

// Uppercase snake case is the project convention for named constants.
// ignore_for_file: constant_identifier_names

void main() {
  test('reconnects with saved credentials and retries once', () async {
    final attempts = <bool>[];
    var signIns = 0;
    final runner = _runner(
      credentials: const AuthCredentials(
        userId: '2024012050',
        password: 'saved-password',
      ),
      signIn:
          ({required userId, required password, required fingerprint}) async {
            expect(userId, '2024012050');
            expect(password, 'saved-password');
            expect(fingerprint, 'saved-fingerprint');
            signIns++;
          },
    );

    final result = await runner.run(
      commandName: 'learn-courses',
      savedSession: _SESSION,
      request: (isRetry) async {
        attempts.add(isRetry);
        if (!isRetry) throw const PortalCsrfUnavailable('missing token');
        return 'course list';
      },
      shouldReconnect: (error) => error is PortalCsrfUnavailable,
    );

    expect(result, 'course list');
    expect(attempts, [false, true]);
    expect(signIns, 1);
  });

  test('prompts after saved credentials fail', () async {
    final passwords = <String>[];
    final runner = _runner(
      credentials: const AuthCredentials(
        userId: '2024012050',
        password: 'expired-password',
      ),
      interactive: true,
      signIn:
          ({required userId, required password, required fingerprint}) async {
            passwords.add(password);
            if (password == 'expired-password') throw StateError('expired');
          },
    );

    final result = await runner.run(
      commandName: 'schedule',
      savedSession: _SESSION,
      request: (isRetry) async {
        if (!isRetry) throw const PortalSessionRejected();
        return 42;
      },
      shouldReconnect: (error) => error is PortalSessionRejected,
    );

    expect(result, 42);
    expect(passwords, ['expired-password', 'new-password']);
  });

  test('does not reconnect for an unrelated data error', () async {
    var signIns = 0;
    final runner = _runner(
      signIn:
          ({required userId, required password, required fingerprint}) async {
            signIns++;
          },
    );

    await expectLater(
      runner.run<void>(
        commandName: 'learn-courses',
        savedSession: _SESSION,
        request: (_) async => throw const FormatException('bad course data'),
        shouldReconnect: (error) => error is PortalCsrfUnavailable,
      ),
      throwsFormatException,
    );
    expect(signIns, 0);
  });

  test('does not sign in again after the one request retry fails', () async {
    var signIns = 0;
    var requests = 0;
    final runner = _runner(
      credentials: const AuthCredentials(
        userId: '2024012050',
        password: 'saved-password',
      ),
      interactive: true,
      signIn:
          ({required userId, required password, required fingerprint}) async {
            signIns++;
          },
    );

    await expectLater(
      runner.run<void>(
        commandName: 'learn-courses',
        savedSession: _SESSION,
        request: (_) async {
          requests++;
          throw const PortalCsrfUnavailable('still unavailable');
        },
        shouldReconnect: (error) => error is PortalCsrfUnavailable,
      ),
      throwsA(isA<PortalCsrfUnavailable>()),
    );
    expect(requests, 2);
    expect(signIns, 1);
  });

  test('noninteractive recovery gives a login command', () async {
    final runner = _runner(
      credentials: const AuthCredentials(
        userId: 'another-account',
        password: 'wrong-account-password',
      ),
    );

    await expectLater(
      runner.run<void>(
        commandName: 'learn-courses',
        savedSession: _SESSION,
        request: (_) async => throw const PortalCsrfUnavailable('missing'),
        shouldReconnect: (error) => error is PortalCsrfUnavailable,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('thulium login --force'),
        ),
      ),
    );
  });
}

const _SESSION = AuthSession(
  userId: '2024012050',
  fingerprint: 'saved-fingerprint',
  cookies: {},
);

CliSessionReconnect _runner({
  AuthCredentials? credentials,
  bool interactive = false,
  Future<void> Function({
    required String userId,
    required String password,
    required String fingerprint,
  })?
  signIn,
}) => CliSessionReconnect(
  credentialStore: _CredentialStore(credentials),
  signIn:
      signIn ??
      ({required userId, required password, required fingerprint}) async {},
  interactive: interactive,
  askToSignIn: (_) => true,
  readPassword: () => 'new-password',
  writeMessage: (_) {},
  writeError: (_) {},
);

final class _CredentialStore implements AuthCredentialStore {
  const _CredentialStore(this.credentials);

  final AuthCredentials? credentials;

  @override
  Future<AuthCredentials?> readCredentials() async => credentials;

  @override
  Future<void> writeCredentials(AuthCredentials credentials) async {}

  @override
  Future<void> clearCredentials() async {}
}
