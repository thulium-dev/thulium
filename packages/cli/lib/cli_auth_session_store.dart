import 'dart:convert';

import 'package:keybay/keybay.dart';
import 'package:thulium_auth/thulium_auth.dart';

// Uppercase snake case is the project convention for named constants.
// ignore_for_file: constant_identifier_names

const _THULIUM_SECRET_STORE_ID = 'dev.thulium.cli';
const _THULIUM_SESSION_KEY = 'auth-session';
const _THULIUM_CREDENTIAL_KEY = 'auth-credentials';

/// Adapts the Dart secret-storage backend to the shared authentication API.
///
/// The CLI does not know how a platform stores secrets. `keybay` applies its
/// documented platform policy, encrypts stored payloads, and fails closed
/// when no safe backend is available. Credentials use a separate secret key.
final class CliAuthSessionStore
    implements AuthSessionStore, AuthCredentialStore {
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

  @override
  Future<AuthCredentials?> readCredentials() async {
    final encoded = await _guard(
      () => _storage.readString(_THULIUM_CREDENTIAL_KEY),
    );
    if (encoded == null) return null;
    final value = jsonDecode(encoded);
    if (value is! Map ||
        value['userId'] is! String ||
        value['password'] is! String) {
      throw const FormatException('Invalid stored credentials.');
    }
    return AuthCredentials(
      userId: value['userId'] as String,
      password: value['password'] as String,
    );
  }

  @override
  Future<void> writeCredentials(AuthCredentials credentials) => _guard(
    () => _storage.writeString(
      _THULIUM_CREDENTIAL_KEY,
      jsonEncode({
        'userId': credentials.userId,
        'password': credentials.password,
      }),
    ),
  );

  @override
  Future<void> clearCredentials() =>
      _guard(() => _storage.delete(_THULIUM_CREDENTIAL_KEY));

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
