import 'package:keybay/keybay.dart';
import 'package:thulium_campus/thulium_campus.dart';

// ignore_for_file: constant_identifier_names

const _CLI_STORE_ID = 'dev.thulium.cli';
const _CALENDAR_CACHE_KEY = 'calendar-cache-v1';

/// Reuses the CLI's encrypted secret backend for cached student data.
final class CliCourseScheduleCacheStore implements CourseScheduleCacheStore {
  CliCourseScheduleCacheStore({SecretStorage? storage})
    : _storage = storage ?? SecretStorage(appId: _CLI_STORE_ID);

  final SecretStorage _storage;

  @override
  Future<String?> read() => _storage.readString(_CALENDAR_CACHE_KEY);

  @override
  Future<void> write(String value) =>
      _storage.writeString(_CALENDAR_CACHE_KEY, value);

  @override
  Future<void> clear() => _storage.delete(_CALENDAR_CACHE_KEY);
}
