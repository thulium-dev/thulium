# thulium_auth

Shared Dart authentication primitives for Thulium clients.

The package implements the Tsinghua WebVPN and identity login flow:

1. Obtain the identity page and its SM2 public key.
2. Submit the student ID and SM2-encrypted password over HTTPS.
3. Support an injected two-factor authentication handler.
4. Follow the identity and information-portal redirects.
5. Persist the resulting Cookie-based session through `AuthSessionStore`.

`AuthSession` deliberately contains no password. Flutter applications should provide a Keychain/Keystore-backed store, while CLI clients can provide an operating-system credential-store implementation.
