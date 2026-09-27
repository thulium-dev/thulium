// The project-wide constant convention uses uppercase snake case for named
// constants, including private implementation constants.
// ignore_for_file: constant_identifier_names

import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:thulium_auth/thulium_auth.dart';

/// Persists sessions and reusable credentials under distinct secure keys.
final class SecureAuthSessionStore
    implements AuthSessionStore, AuthCredentialStore {
  SecureAuthSessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? _createStorage();

  // A single stable key keeps the storage format independent from the
  // platform-specific secure-storage implementation.
  static const _SESSION_KEY = 'thulium.auth.session';
  static const _FINGERPRINT_KEY = 'thulium.auth.fingerprint';
  static const _CREDENTIAL_KEY = 'thulium.auth.credentials';

  final FlutterSecureStorage _storage;

  /// Loads or creates a stable, per-installation identity-provider fingerprint.
  ///
  /// Keeping this separate from the login session lets the installation retain
  /// its trusted-device identity after cookies expire or the user logs out.
  Future<String> getOrCreateFingerprint() async {
    final existing = await _storage.read(key: _FINGERPRINT_KEY);
    if (existing != null && existing.isNotEmpty) return existing;

    final random = Random.secure();
    final fingerprint = List<int>.generate(
      32,
      (_) => random.nextInt(256),
    ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    await _storage.write(key: _FINGERPRINT_KEY, value: fingerprint);
    return fingerprint;
  }

  static FlutterSecureStorage _createStorage() =>
      defaultTargetPlatform == TargetPlatform.macOS
      // The data-protection keychain requires Keychain Sharing entitlements and
      // provisioning. The legacy macOS keychain is sufficient for this app's
      // private session and keeps unsigned/local builds distributable.
      ? const FlutterSecureStorage(
          mOptions: MacOsOptions(usesDataProtectionKeychain: false),
        )
      : const FlutterSecureStorage();

  @override
  Future<AuthSession?> read() async {
    // Session restoration does not read the separately stored password.
    final encoded = await _storage.read(key: _SESSION_KEY);
    return encoded == null ? null : AuthSession.decode(encoded);
  }

  @override
  Future<void> write(AuthSession session) =>
      _storage.write(key: _SESSION_KEY, value: session.encode());

  @override
  Future<void> clear() => _storage.delete(key: _SESSION_KEY);

  @override
  Future<AuthCredentials?> readCredentials() async {
    final encoded = await _storage.read(key: _CREDENTIAL_KEY);
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
  Future<void> writeCredentials(AuthCredentials credentials) => _storage.write(
    key: _CREDENTIAL_KEY,
    value: jsonEncode({
      'userId': credentials.userId,
      'password': credentials.password,
    }),
  );

  @override
  Future<void> clearCredentials() => _storage.delete(key: _CREDENTIAL_KEY);
}
