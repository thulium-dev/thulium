// The project-wide constant convention uses uppercase snake case for named
// constants, including private implementation constants.
// ignore_for_file: constant_identifier_names

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:thulium_auth/thulium_auth.dart';

/// Persists only an authenticated session, never the user's password.
final class SecureAuthSessionStore implements AuthSessionStore {
  SecureAuthSessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  // A single stable key keeps the storage format independent from the
  // platform-specific secure-storage implementation.
  static const _SESSION_KEY = 'thulium.auth.session';

  final FlutterSecureStorage _storage;

  @override
  Future<AuthSession?> read() async {
    // Only the serialized cookie session is read. The password is never part
    // of the stored value, so restoring a session does not expose credentials.
    final encoded = await _storage.read(key: _SESSION_KEY);
    return encoded == null ? null : AuthSession.decode(encoded);
  }

  @override
  Future<void> write(AuthSession session) =>
      _storage.write(key: _SESSION_KEY, value: session.encode());

  @override
  Future<void> clear() => _storage.delete(key: _SESSION_KEY);
}
