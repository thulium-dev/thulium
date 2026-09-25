// ignore_for_file: constant_identifier_names

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:thulium_campus/thulium_campus.dart';

const _CALENDAR_CACHE_KEY = 'thulium.calendar.cache.v1';

/// Stores compressed calendar data separately from authentication secrets.
final class SecureCourseScheduleCacheStore implements CourseScheduleCacheStore {
  SecureCourseScheduleCacheStore({FlutterSecureStorage? storage})
    : _storage = storage ?? _createStorage();

  final FlutterSecureStorage _storage;

  static FlutterSecureStorage _createStorage() =>
      defaultTargetPlatform == TargetPlatform.macOS
      ? const FlutterSecureStorage(
          mOptions: MacOsOptions(usesDataProtectionKeychain: false),
        )
      : const FlutterSecureStorage();

  @override
  Future<String?> read() => _storage.read(key: _CALENDAR_CACHE_KEY);

  @override
  Future<void> write(String value) =>
      _storage.write(key: _CALENDAR_CACHE_KEY, value: value);

  @override
  Future<void> clear() => _storage.delete(key: _CALENDAR_CACHE_KEY);
}
