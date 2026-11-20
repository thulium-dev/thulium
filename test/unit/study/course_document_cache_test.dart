import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:thulium/study/course_document_cache.dart';

void main() {
  late Directory root;
  late CourseDocumentCache cache;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('thulium-documents');
    cache = CourseDocumentCache(root: root);
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<CourseDocument?> read(String account) =>
      cache.read(account: account, courseId: 'physics', fileId: 'lecture');

  test('stores a document and resumes the saved page', () async {
    await cache.write(
      account: 'student-a',
      courseId: 'physics',
      fileId: 'lecture',
      bytes: [1, 2, 3],
    );
    await cache.writePage(
      account: 'student-a',
      courseId: 'physics',
      fileId: 'lecture',
      page: 7,
    );

    final stored = await read('student-a');
    expect(stored, isNotNull);
    expect(stored!.bytes, [1, 2, 3]);
    expect(stored.page, 7);
  });

  test('keeps accounts separate and survives a restart', () async {
    await cache.write(
      account: 'student-a',
      courseId: 'physics',
      fileId: 'lecture',
      bytes: [1],
    );
    await cache.writePage(
      account: 'student-a',
      courseId: 'physics',
      fileId: 'lecture',
      page: 3,
    );

    expect(await read('student-b'), isNull);

    // A fresh instance over the same directory represents a later launch.
    final relaunched = CourseDocumentCache(root: root);
    final stored = await relaunched.read(
      account: 'student-a',
      courseId: 'physics',
      fileId: 'lecture',
    );
    expect(stored?.page, 3);
  });

  test(
    'keeps reading progress when the document itself is not cached',
    () async {
      await cache.writePage(
        account: 'student-a',
        courseId: 'physics',
        fileId: 'lecture',
        page: 4,
      );

      expect(await read('student-a'), isNull);
      expect(
        await cache.readPage(
          account: 'student-a',
          courseId: 'physics',
          fileId: 'lecture',
        ),
        4,
      );
    },
  );

  test(
    'rejects unsafe identifiers instead of leaving the cache root',
    () async {
      expect(
        await cache.read(
          account: '../escape',
          courseId: 'physics',
          fileId: 'x',
        ),
        isNull,
      );
      await cache.write(
        account: 'student-a',
        courseId: 'physics',
        fileId: '../escape',
        bytes: [1],
      );
      final outside = File('${root.parent.path}/escape.pdf');
      expect(await outside.exists(), isFalse);
    },
  );

  test(
    'evicts the least recently used documents over the size limit',
    () async {
      var clock = DateTime.utc(2026, 1, 1);
      final limited = CourseDocumentCache(
        root: root,
        maxBytes: 10,
        clock: () => clock,
      );
      Future<void> store(String file) => limited.write(
        account: 'student-a',
        courseId: 'physics',
        fileId: file,
        bytes: [1, 2, 3, 4],
      );
      await store('older');
      clock = DateTime.utc(2026, 1, 2);
      await store('newer');
      clock = DateTime.utc(2026, 1, 3);
      // Reading refreshes the older entry so it becomes the most recent.
      await limited.read(
        account: 'student-a',
        courseId: 'physics',
        fileId: 'older',
      );
      clock = DateTime.utc(2026, 1, 4);
      await store('newest');

      expect(
        await limited.read(
          account: 'student-a',
          courseId: 'physics',
          fileId: 'older',
        ),
        isNotNull,
      );
      expect(
        await limited.read(
          account: 'student-a',
          courseId: 'physics',
          fileId: 'newest',
        ),
        isNotNull,
      );
      expect(
        await limited.read(
          account: 'student-a',
          courseId: 'physics',
          fileId: 'newer',
        ),
        isNull,
      );
    },
  );

  test('clears one account only when asked to', () async {
    await cache.write(
      account: 'student-a',
      courseId: 'physics',
      fileId: 'lecture',
      bytes: [1],
    );
    await cache.write(
      account: 'student-b',
      courseId: 'physics',
      fileId: 'lecture',
      bytes: [2],
    );

    await cache.clear(account: 'student-a');

    expect(await read('student-a'), isNull);
    expect(await read('student-b'), isNotNull);
  });
}
