part of '../thulium_auth.dart';

/// Coordinates clients which persist into the same session store.
///
/// Restore happens inside the queue, so a waiting request observes cookies and
/// trusted-device state refreshed by its predecessor rather than overwriting
/// them with an earlier snapshot. Callers must share their session-store object.
final class AuthSessionRunner {
  const AuthSessionRunner(this.store, {this.trace, this.createClient});

  final AuthSessionStore store;
  final AuthTraceHandler? trace;

  /// Allows a caller to configure the transport. The client must use [store].
  final TsinghuaAuthClient Function()? createClient;
  static final _gates = Expando<_AuthSessionGate>();

  /// Also coordinates explicit sign-in/sign-out with background requests.
  static Future<T> exclusive<T>(
    AuthSessionStore store,
    Future<T> Function() operation,
  ) async {
    final gate = _gates[store] ??= _AuthSessionGate();
    final previous = gate.tail;
    final released = Completer<void>();
    gate.tail = released.future;
    await previous;
    try {
      return await operation();
    } finally {
      released.complete();
    }
  }

  /// Retries the complete service operation once after a credential login.
  /// Network, parsing, and unrelated service failures never trigger a login.
  Future<T> run<T>({
    required Future<T> Function(TsinghuaAuthClient client, bool isRetry)
    request,
    bool Function(Object error)? shouldReconnect,
    String? expectedUserId,
  }) => exclusive(store, () async {
    final credentials = store is AuthCredentialStore
        ? store as AuthCredentialStore
        : null;
    final client =
        createClient?.call() ??
        TsinghuaAuthClient(
          sessionStore: store,
          credentialStore: credentials,
          trace: trace,
        );
    final session = await client.restore();
    if (session == null ||
        (expectedUserId != null && session.userId != expectedUserId)) {
      throw const PortalSessionRejected();
    }
    try {
      return await request(client, false);
    } on Object catch (error) {
      final reconnect =
          shouldReconnect?.call(error) ??
          (error is PortalSessionRejected || error is PortalCsrfUnavailable);
      if (!reconnect) rethrow;
      final saved = await credentials?.readCredentials();
      if (saved == null || saved.userId != session.userId) rethrow;
      trace?.call('Reconnecting with saved credentials; retrying once.');
      await client.login(
        userId: session.userId,
        password: saved.password,
        fingerprint: session.fingerprint,
      );
      // Keep this outside the first attempt's catch: a failed retry must not
      // launch a second login. login() retains the restored trusted-device token.
      return request(client, true);
    }
  });
}

final class _AuthSessionGate {
  Future<void> tail = Future<void>.value();
}
