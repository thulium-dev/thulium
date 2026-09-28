import 'package:keybay/keybay.dart';
import 'package:thulium_campus/thulium_campus.dart';

// ignore_for_file: constant_identifier_names

const _CLI_STORE_ID = 'dev.thulium.cli';
const _LEARN_COURSE_CACHE_KEY = 'learn-course-cache-v1';

/// Persists student course titles in the CLI's encrypted local secret store.
final class CliLearnCourseCacheStore implements LearnCourseCacheStore {
  CliLearnCourseCacheStore({SecretStorage? storage})
    : _storage = storage ?? SecretStorage(appId: _CLI_STORE_ID);

  final SecretStorage _storage;

  @override
  Future<String?> read() => _storage.readString(_LEARN_COURSE_CACHE_KEY);

  @override
  Future<void> write(String value) =>
      _storage.writeString(_LEARN_COURSE_CACHE_KEY, value);

  @override
  Future<void> clear() => _storage.delete(_LEARN_COURSE_CACHE_KEY);
}
