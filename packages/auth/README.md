# thulium_auth

Shared Dart authentication primitives for Thulium clients.

The package implements the Tsinghua WebVPN and identity login flow:

1. Obtain the identity page and its SM2 public key.
2. Submit the student ID and SM2-encrypted password over HTTPS.
3. Support an injected two-factor authentication handler.
4. Follow the identity and information-portal redirects.
5. Persist the resulting Cookie-based session through `AuthSessionStore`.

`AuthSession` deliberately contains no password. Flutter applications should provide a Keychain/Keystore-backed store, while CLI clients can provide an operating-system credential-store implementation.

## Coordinated session recovery

App screens that share persistent cookies should use `AuthSessionRunner` with
the same `AuthSessionStore` object. The default Flutter `SecureAuthSessionStore`
provides that shared identity. The runner restores the latest session inside a
queue, preventing independent screens from overwriting refreshed cookies with
older snapshots.

For a typed authentication failure, the runner reads matching saved credentials,
reuses the session fingerprint and trusted-device token, logs in, and retries
the complete service operation once. Services can classify their own wrapped
authentication errors with `shouldReconnect`. Network and parsing errors do not
trigger a credential login. A server-required second factor is propagated for
the caller's verification flow; it does not clear saved credentials.

Coordinate explicit sign-in and sign-out with `AuthSessionRunner.exclusive` as
well. Apply any UI timeout outside `run`, so a timed-out caller does not release
the queue while its underlying request can still persist cookies.
