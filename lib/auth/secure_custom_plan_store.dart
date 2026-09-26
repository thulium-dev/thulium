// ignore_for_file: constant_identifier_names

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:thulium_campus/thulium_campus.dart';

const _CUSTOM_PLAN_KEY_PREFIX = 'thulium.custom-plans.v1.';

/// Keeps personal plan rules separate from server-fetched calendar snapshots.
///
/// The account identifier forms part of the key so signing in as another
/// student never displays or overwrites the previous student's plans.
final class SecureCustomPlanStore {
  SecureCustomPlanStore({FlutterSecureStorage? storage})
    : _storage = storage ?? _createStorage();

  final FlutterSecureStorage _storage;

  static FlutterSecureStorage _createStorage() =>
      defaultTargetPlatform == TargetPlatform.macOS
      ? const FlutterSecureStorage(
          mOptions: MacOsOptions(usesDataProtectionKeychain: false),
        )
      : const FlutterSecureStorage();

  String _key(String userId) =>
      '$_CUSTOM_PLAN_KEY_PREFIX${Uri.encodeComponent(userId)}';

  Future<CustomPlanCollection> readFor(String userId) async {
    final value = await _storage.read(key: _key(userId));
    return value == null
        ? CustomPlanCollection.empty()
        : CustomPlanCollection.decode(value);
  }

  Future<void> writeFor(String userId, CustomPlanCollection collection) =>
      _storage.write(key: _key(userId), value: collection.encode());
}
