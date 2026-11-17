import 'package:thulium_auth/thulium_auth.dart';
import 'package:thulium_campus/thulium_campus.dart';

/// Course requests share the app's authentication queue. Document responses
/// are not logged, and only typed session failures trigger credential recovery.
class CourseContentSource {
  const CourseContentSource({required this.store, required this.catalog});

  final AuthSessionStore store;
  final LearnCourseCatalog catalog;

  Future<T> _request<T>(Future<T> Function(TsinghuaAuthClient) operation) =>
      AuthSessionRunner(store).run(
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

  Future<List<int>> document(LearnMaterial material) => _request(
    (client) => LearnMaterialService(
      client,
    ).downloadPdf(fileId: material.fileId, courseId: material.courseId),
  ).timeout(const Duration(minutes: 2));
}
