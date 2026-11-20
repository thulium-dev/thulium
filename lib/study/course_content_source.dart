import 'package:flutter/foundation.dart';
import 'package:thulium_auth/thulium_auth.dart';
import 'package:thulium_campus/thulium_campus.dart';

import 'course_document_cache.dart';

/// Course requests share the app's authentication queue. Document responses
/// are not logged, and only typed session failures trigger credential recovery.
class CourseContentSource {
  const CourseContentSource({
    required this.store,
    required this.catalog,
    this.documentCache,
  });

  final AuthSessionStore store;
  final LearnCourseCatalog catalog;

  /// Owns the downloaded bytes and reading position. Null disables caching,
  /// which keeps tests and other callers independent from the file system.
  final CourseDocumentCache? documentCache;

  Future<T> _request<T>(Future<T> Function(TsinghuaAuthClient) operation) =>
      AuthSessionRunner(
        store,
        trace: (message) => debugPrint('[auth][course-content] $message'),
      ).run(
        expectedUserId: catalog.userId,
        request: (client, _) => operation(client),
      );

  LearnCourseCatalog _single(LearnCourse course) => LearnCourseCatalog(
    userId: catalog.userId,
    semester: catalog.semester,
    courses: [course],
  );

  Future<LearnCourseMaterials> materials(LearnCourse course) => _request(
    (client) async => (await LearnMaterialService(
      client,
    ).fetchCourses(_single(course), courseId: course.id)).single,
  ).timeout(const Duration(minutes: 2));

  Future<Map<LearnHomeworkStatus, List<LearnHomework>>> assignments(
    LearnCourse course,
  ) => _request(
    (client) =>
        LearnHomeworkService(client).fetchCourseAssignments(_single(course)),
  ).timeout(const Duration(minutes: 2));

  /// Loads the stored document body. A cache hit avoids the PDF request, and a
  /// miss still records the reading position even when only pages are cached.
  ///
  /// [forceRefresh] ignores the cached body but keeps account isolation.
  Future<CourseDocument> document(
    LearnMaterial material, {
    bool forceRefresh = false,
  }) async {
    final cache = documentCache;
    if (!forceRefresh && cache != null) {
      final stored = await cache.read(
        account: catalog.userId,
        courseId: material.courseId,
        fileId: material.fileId,
      );
      if (stored != null) return stored;
    }
    final bytes = await _request(
      (client) => LearnMaterialService(
        client,
      ).downloadPdf(fileId: material.fileId, courseId: material.courseId),
    ).timeout(const Duration(minutes: 2));
    if (cache != null) {
      await cache.write(
        account: catalog.userId,
        courseId: material.courseId,
        fileId: material.fileId,
        bytes: bytes,
      );
    }
    return CourseDocument(bytes);
  }

  /// Remembers how far this account read a document so a later open resumes.
  Future<void> saveReadingProgress(
    LearnMaterial material, {
    required int page,
  }) async {
    await documentCache?.writePage(
      account: catalog.userId,
      courseId: material.courseId,
      fileId: material.fileId,
      page: page,
    );
  }
}
