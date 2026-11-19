import 'package:thulium_auth/thulium_auth.dart';

/// Runs an authenticated CLI request and reconnects only for session errors.
///
/// The caller classifies its own errors, so malformed service data cannot
/// silently trigger a new login. A successful reconnect retries the original
/// request exactly once; a second failure is returned to the caller unchanged.
final class CliSessionReconnect {
  const CliSessionReconnect({
    required this.credentialStore,
    required this.signIn,
    required this.interactive,
    required this.askToSignIn,
    required this.readPassword,
    required this.writeMessage,
    required this.writeError,
  });

  final AuthCredentialStore credentialStore;
  final Future<void> Function({
    required String userId,
    required String password,
    required String fingerprint,
  })
  signIn;
  final bool interactive;
  final bool Function(String commandName) askToSignIn;
  final String Function() readPassword;
  final void Function(String message) writeMessage;
  final void Function(String message) writeError;

  Future<T> run<T>({
    required String commandName,
    required AuthSession savedSession,
    required Future<T> Function(bool isRetry) request,
    required bool Function(Object error) shouldReconnect,
  }) async {
    try {
      return await request(false);
    } on Object catch (error) {
      if (!shouldReconnect(error)) rethrow;
      return _reconnectAndRetry(
        commandName: commandName,
        savedSession: savedSession,
        originalError: error,
        request: request,
      );
    }
  }

  Future<T> _reconnectAndRetry<T>({
    required String commandName,
    required AuthSession savedSession,
    required Object originalError,
    required Future<T> Function(bool isRetry) request,
  }) async {
    final credentials = await credentialStore.readCredentials();
    if (credentials != null && credentials.userId == savedSession.userId) {
      writeMessage('Reconnecting with saved credentials...');
      var signedIn = false;
      try {
        await signIn(
          userId: credentials.userId,
          password: credentials.password,
          fingerprint: savedSession.fingerprint,
        );
        signedIn = true;
      } on Object catch (error) {
        writeError('Automatic reconnection failed: $error');
      }
      if (signedIn) {
        // A retry failure must propagate without another login or request.
        writeMessage('Reconnected. Retrying $commandName once...');
        return request(true);
      }
    }

    if (!interactive) {
      throw StateError(
        'The saved session could not be reconnected automatically. '
        'Run `thulium login --force` in an interactive terminal, then retry '
        '`thulium $commandName`. Original error: $originalError',
      );
    }

    writeMessage('The saved session could not be reconnected silently.');
    if (!askToSignIn(commandName)) throw originalError;
    final password = readPassword();
    if (password.isEmpty) {
      throw StateError('A password is required to reconnect.');
    }

    // Reuse only this account's fingerprint. The authentication client stores
    // the replacement credential after a successful interactive sign-in.
    await signIn(
      userId: savedSession.userId,
      password: password,
      fingerprint: savedSession.fingerprint,
    );
    writeMessage('Reconnected. Retrying $commandName once...');
    return request(true);
  }
}
