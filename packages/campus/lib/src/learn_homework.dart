part of '../thulium_campus.dart';

/// Counts are taken from each status endpoint, independently of page size.
final class LearnHomeworkCounts {
  const LearnHomeworkCounts({
    required this.unsubmitted,
    required this.submittedUngraded,
    required this.graded,
  });

  final int unsubmitted;
  final int submittedUngraded;
  final int graded;

  int get total => unsubmitted + submittedUngraded + graded;
}

final class LearnCourseHomework {
  const LearnCourseHomework({required this.course, required this.counts});

  final LearnCourse course;
  final LearnHomeworkCounts counts;
}

/// Reads current homework totals using the captured GET `/student/index/`
/// API. OneTHU confirms Wj = unsubmitted, Yjwg = submitted but ungraded,
/// and Ypg = graded, although it uses a separate non-index POST API.
final class LearnHomeworkService {
  const LearnHomeworkService(this._authClient);

  final TsinghuaAuthClient _authClient;

  /// Fetches only Wj totals for course reminders, without graded-list requests.
  Future<Map<String, int>> fetchUnsubmittedCounts(
    LearnCourseCatalog catalog,
  ) async {
    _validateCatalog(catalog);
    if (catalog.courses.isEmpty) return const {};
    final csrf = await LearnPlatformSession(_authClient).open();
    final counts = <String, int>{};
    for (final course in catalog.courses) {
      counts[course.id] = await _fetchCount(course.id, 'zyListWj', csrf);
    }
    return Map.unmodifiable(counts);
  }

  Future<List<LearnCourseHomework>> fetchCourses(
    LearnCourseCatalog catalog,
  ) async {
    _validateCatalog(catalog);
    if (catalog.courses.isEmpty) return const [];
    final csrf = await LearnPlatformSession(_authClient).open();
    final result = <LearnCourseHomework>[];
    // Keep requests sequential to avoid overwhelming Learn or racing its
    // shared authentication cookies. One roaming session serves all courses.
    for (final course in catalog.courses) {
      final unsubmitted = await _fetchCount(course.id, 'zyListWj', csrf);
      final submitted = await _fetchCount(course.id, 'zyListYjwg', csrf);
      final graded = await _fetchCount(course.id, 'zyListYpg', csrf);
      result.add(
        LearnCourseHomework(
          course: course,
          counts: LearnHomeworkCounts(
            unsubmitted: unsubmitted,
            submittedUngraded: submitted,
            graded: graded,
          ),
        ),
      );
    }
    return result;
  }

  void _validateCatalog(LearnCourseCatalog catalog) {
    if (_authClient.session?.userId != catalog.userId) {
      throw StateError('Restore the course catalog account first.');
    }
    for (final course in catalog.courses) {
      if (course.id.isEmpty) {
        throw const FormatException('A course has no learning platform ID.');
      }
    }
  }

  Future<int> _fetchCount(String courseId, String endpoint, String csrf) async {
    // The index route is captured for Wj. Reusing that prefix for Yjwg/Ypg
    // is inferred from the sibling endpoint names; OneTHU confirms those
    // names on its non-index POST route, not this GET variant.
    final target = Uri.https(
      _LEARN_HOST,
      '/b/wlxt/kczy/zy/student/index/$endpoint',
      {'wlkcid': courseId, 'size': '5', '_csrf': csrf},
    );
    final response = await _authClient.getAuthenticated(
      TsinghuaWebVpnRedirect.forTarget(target),
    );
    if (_isLearnSignInResponse(
      response.statusCode,
      response.request?.url,
      response.body,
    )) {
      _authClient.traceUnexpectedResponse('learning-homework', response);
      throw const PortalSessionRejected();
    }
    if (response.statusCode != 200) {
      throw StateError(
        'Homework request failed for $courseId ($endpoint): '
        'HTTP ${response.statusCode}.',
      );
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const FormatException('Learn did not return homework-list JSON.');
    }
    if (decoded is! Map ||
        decoded['result'] != 'success' ||
        decoded['object'] is! Map) {
      throw const FormatException('Learn returned an invalid homework list.');
    }
    final data = decoded['object'] as Map;
    // DataTables metadata is authoritative. aaData contains only this page,
    // while iTotalDisplayRecords is the filtered count, not the full total.
    final value = data['iTotalRecords'];
    final count = value is int
        ? value
        : value is String
        ? int.tryParse(value)
        : null;
    if (count == null || count < 0) {
      throw const FormatException('Learn returned an invalid homework total.');
    }
    return count;
  }
}
