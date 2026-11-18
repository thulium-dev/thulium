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

A login page from the portal cookie endpoint first triggers silent SSO renewal;
it does not immediately prove the identity session has expired. If bounded
cookie retries, account probes, and silent SSO still end in
`PortalCsrfUnavailable`, the runner attempts one saved-credential login without
declaring the account signed out. Network failures do not trigger this fallback.
Course and calendar caches propagate recoverable auth failures to the runner
instead of hiding them behind stale data. When validation does invalidate
cookies, the client retains a cookie-free snapshot of
device trust for its credential recovery, restricted to the same account and
fingerprint. Explicit logout also clears this snapshot.

If validation cleared rejected cookies and credential recovery fails, the runner
persists only the original account/device identity, without cookies. This keeps a
later refresh eligible for recovery while preserving separately saved passwords.

Learn follows the service-first recovery policy used by OneTHU: a confirmed
Learn login page or HTTP 401 first verifies the main account. If that account is
still authenticated, rebuild only Learn through roaming and retry the read once.
Confirmed main-session rejection is escalated to credential recovery; the
runner's bounded portal-CSRF fallback remains available as described above.
Bare file HTTP 403/404/5xx responses and unsupported PDF conversions remain
service errors. JSON content and injected scripts mentioning login controls do
not prove logout. PDF reads carry the current Learn CSRF token, and temporary
service failures offer retry rather than sending users back to sign-in.

Device trust records registration consent separately from the optional legacy
`fingerGenPrint` token. Sign-in asks once and registers the fingerprint only after
successful code verification. Credential forms match `main`: account, encrypted
password, fingerprint, trusted-device token and captcha. They do not implicitly
enable the separate `singleLogin`/`deviceName` browser-SSO option. A remembered
trust choice alone is not proof that the server will waive verification.
Server-provided `checkSingle` forms are followed before falling back to
credentials, including during silent portal renewal. Restoring a session also
hydrates its trusted-device token; confirmation forms explicitly receive that
token, the stable fingerprint and `i_rememberme=on` for `checkSingle`, even when
the server omits the inputs or supplies empty placeholders. This allows the WebVPN and
information-portal stages to share a verified identity without unnecessarily
requesting another code. A genuine server challenge is still verified.

Coordinate explicit sign-in and sign-out with `AuthSessionRunner.exclusive` as
well. Apply any UI timeout outside `run`, so a timed-out caller does not release
the queue while its underlying request can still persist cookies.

Serialization orders separate operations; it does not deduplicate interactive
sign-in submissions. The login page guards button and keyboard callbacks before
enqueueing work, snapshots the submitted credentials, and caches one trust
choice for that attempt. Verification and dialog completion also reject repeat
callbacks. Diagnostic attempt IDs and phase names contain no credential values.
Recovery diagnostics record the triggering error type, the challenge stage
(`webvpn` or `information-portal`) and token presence, never token values.
