import 'package:thulium_auth/thulium_auth.dart';
import 'package:thulium_campus/thulium_campus.dart';

/// Each request owns its authentication client so separate screens cannot race
/// session restoration. Authenticated document responses are never logged here.
class CourseContentSource {
  const CourseContentSource({required this.store, required this.catalog});

  final AuthSessionStore store;
  final LearnCourseCatalog catalog;

  Future<T> _request<T>(
    Future<T> Function(TsinghuaAuthClient) operation,
  ) async {
    final credentials = store is AuthCredentialStore
        ? store as AuthCredentialStore
        : null;
    final client = TsinghuaAuthClient(
      sessionStore: store,
      credentialStore: credentials,
    );
    final session = await client.restore();
    if (session == null || session.userId != catalog.userId) {
      throw const PortalSessionRejected();
    }
    try {
      return await operation(client);
    } on Object catch (error) {
      if (error is! PortalSessionRejected && error is! PortalCsrfUnavailable) {
        rethrow;
      }
      final saved = await credentials?.readCredentials();
      if (saved == null || saved.userId != session.userId) rethrow;
      await client.login(
        userId: session.userId,
        password: saved.password,
        fingerprint: session.fingerprint,
      );
      return operation(client);
    }
  }

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

  Future<List<int>> document(LearnMaterial material) => _request(
    (client) => LearnMaterialService(
      client,
    ).downloadPdf(fileId: material.fileId, courseId: material.courseId),
  ).timeout(const Duration(minutes: 2));
}
