import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:thulium/auth/secure_learn_homework_cache_store.dart';
import 'package:thulium_campus/thulium_campus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'new store instances recover persisted homework and clear leaves course data intact',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'thulium.learn.courses.cache.v1': 'course-data',
      });
      final first = LearnHomeworkCache(SecureLearnHomeworkCacheStore());
      await first.writeFor(
        'student',
        '2026-2027-1',
        LearnHomeworkSnapshot(counts: {}, assignments: []),
        DateTime.now(),
      );
      final restored = LearnHomeworkCache(SecureLearnHomeworkCacheStore());
      expect(await restored.readFor('student', '2026-2027-1'), isNotNull);
      await restored.clear();
      expect(await first.readFor('student', '2026-2027-1'), isNull);
      expect(
        await const FlutterSecureStorage().read(
          key: 'thulium.learn.courses.cache.v1',
        ),
        'course-data',
      );
    },
  );
}
