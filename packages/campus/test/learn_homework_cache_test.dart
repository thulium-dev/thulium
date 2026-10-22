import 'dart:convert';

import 'package:test/test.dart';
import 'package:thulium_campus/thulium_campus.dart';

void main() {
  test(
    'restores a complete snapshot through a new cache instance with UTC deadlines',
    () async {
      final store = _Store();
      final fetchedAt = DateTime.utc(2026, 10, 14);
      await LearnHomeworkCache(
        store,
      ).writeFor('student', '2026-2027-1', _snapshot, fetchedAt);
      final restored = await LearnHomeworkCache(
        store,
      ).readFor('student', '2026-2027-1');
      expect(restored!.fetchedAt, fetchedAt);
      expect(restored.snapshot.counts, {'physics': 1, 'zero-homework': 0});
      expect(restored.snapshot.assignments.single.title, '大学物理作业');
      expect(
        restored.snapshot.assignments.single.course.englishName,
        'Physics',
      );
      expect(
        restored.snapshot.assignments.single.deadline,
        DateTime.utc(2026, 10, 21, 15, 59),
      );
      expect(restored.snapshot.assignments.single.deadline!.isUtc, isTrue);
    },
  );

  test(
    'cache never supplies another account or semester and clear removes it',
    () async {
      final store = _Store();
      final cache = LearnHomeworkCache(store);
      await cache.writeFor('student', '2026-2027-1', _snapshot, DateTime.now());
      expect(await cache.readFor('other-student', '2026-2027-1'), isNull);
      expect(await cache.readFor('student', '2026-2027-2'), isNull);
      await cache.clear();
      expect(await cache.readFor('student', '2026-2027-1'), isNull);
    },
  );

  test('corrupt, incompatible or inconsistent payloads are ignored', () async {
    final store = _Store();
    final cache = LearnHomeworkCache(store);
    await cache.writeFor('student', '2026-2027-1', _snapshot, DateTime.now());
    final valid = store.value!;
    for (final change in <void Function(Map<String, dynamic>)>[
      (data) => data['version'] = 99,
      (data) => data['fetchedAt'] = 'bad-time',
      (data) => data['counts'] = {'physics': 2},
      (data) => data['counts'] = {'physics': -1},
      (data) => (data['assignments'] as List).first['deadline'] =
          '2026-10-21T15:59:00',
      (data) => data['assignments'] = [null],
    ]) {
      final data = jsonDecode(valid) as Map<String, dynamic>;
      change(data);
      store.value = jsonEncode(data);
      expect(await cache.readFor('student', '2026-2027-1'), isNull);
    }
    store.value = '{broken';
    expect(await cache.readFor('student', '2026-2027-1'), isNull);
  });

  test(
    'an empty successful snapshot is preserved as a known zero result',
    () async {
      final cache = LearnHomeworkCache(_Store());
      await cache.writeFor(
        'student',
        '2026-2027-1',
        LearnHomeworkSnapshot(counts: {}, assignments: []),
        DateTime.now(),
      );
      final restored = await cache.readFor('student', '2026-2027-1');
      expect(restored, isNotNull);
      expect(restored!.snapshot.assignments, isEmpty);
    },
  );
}

final _snapshot = LearnHomeworkSnapshot(
  counts: {'physics': 1, 'zero-homework': 0},
  assignments: [
    LearnHomework(
      id: 'assignment-1',
      course: const LearnCourse(
        id: 'physics',
        name: '物理',
        englishName: 'Physics',
        teacherName: '',
        schedule: '',
      ),
      title: '大学物理作业',
      deadline: DateTime.utc(2026, 10, 21, 15, 59),
    ),
  ],
);

final class _Store implements LearnHomeworkCacheStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async => this.value = value;
  @override
  Future<void> clear() async => value = null;
}
