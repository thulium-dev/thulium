import 'package:keybay/keybay.dart';
import 'package:thulium_auth/thulium_auth.dart';

// Uppercase snake case is the project convention for named constants.
// ignore_for_file: constant_identifier_names

const _THULIUM_SECRET_STORE_ID = 'dev.thulium.cli';
const _THULIUM_SESSION_KEY = 'auth-session';

/// Adapts the Dart secret-storage backend to the shared authentication API.
///
/// The CLI does not know how a platform stores secrets. `keybay` applies its
/// documented platform policy, encrypts the session payload, and fails closed
/// when no safe backend is available. The stored value is still only an
/// [AuthSession]; the user's password is never persisted.
final class CliAuthSessionStore implements AuthSessionStore {
  CliAuthSessionStore({SecretStorage? storage})
    : _storage = storage ?? _createStorage();

  final SecretStorage _storage;

  @override
  Future<AuthSession?> read() async {
    final encoded = await _guard(
      () => _storage.readString(_THULIUM_SESSION_KEY),
    );
    return encoded == null ? null : AuthSession.decode(encoded);
  }

  @override
  Future<void> write(AuthSession session) => _guard(
    () => _storage.writeString(_THULIUM_SESSION_KEY, session.encode()),
  );

  @override
  Future<void> clear() => _guard(() => _storage.delete(_THULIUM_SESSION_KEY));

  static SecretStorage _createStorage() {
    try {
      return SecretStorage(appId: _THULIUM_SECRET_STORE_ID);
    } on SecretStoreException catch (error) {
      throw CliAuthStorageException(error.toString());
    }
  }

  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on SecretStoreException catch (error) {
      throw CliAuthStorageException(error.toString());
    }
  }
}

/// Indicates that the host cannot provide the secure storage policy required
/// for persistent CLI authentication.
final class CliAuthStorageException implements Exception {
  const CliAuthStorageException(this.message);

  final String message;

  @override
  String toString() => message;
}
