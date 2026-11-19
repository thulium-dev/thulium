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
      if (identical(gate.tail, released.future)) {
        // An idle store needs no completed future retained from an older zone.
        _gates[store] = null;
      }
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
    if (session == null) {
      trace?.call('Session recovery unavailable: reason=no-session.');
      throw const PortalSessionRejected();
    }
    if (expectedUserId != null && session.userId != expectedUserId) {
      trace?.call('Session recovery unavailable: reason=account-mismatch.');
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
      if (saved == null) {
        trace?.call('Credential recovery skipped: reason=missing-credentials.');
        rethrow;
      }
      if (saved.userId != session.userId) {
        trace?.call('Credential recovery skipped: reason=account-mismatch.');
        rethrow;
      }
      trace?.call(
        'Credential recovery: cause=${error.runtimeType} '
        'trustedCredentialPresent=${session.fingerGenPrint?.isNotEmpty == true}.',
      );
      trace?.call('Reconnecting with saved credentials; retrying once.');
      try {
        await client.login(
          userId: session.userId,
          password: saved.password,
          fingerprint: session.fingerprint,
        );
      } on Object {
        // Validation may have cleared rejected cookies before this attempt.
        // Retain only the account/device identity so the next refresh can still
        // recover with saved credentials instead of failing at restore().
        if (await store.read() == null) {
          await store.write(
            AuthSession(
              userId: session.userId,
              fingerprint: session.fingerprint,
              cookies: const {},
              fingerGenPrint: session.fingerGenPrint,
              trustedBrowser: session.trustedBrowser,
            ),
          );
        }
        rethrow;
      }
      // Keep this outside the first attempt's catch: a failed retry must not
      // launch a second login. login() retains the restored trusted-device token.
      return request(client, true);
    }
  });
}

final class _AuthSessionGate {
  Future<void> tail = Future<void>.value();
}
