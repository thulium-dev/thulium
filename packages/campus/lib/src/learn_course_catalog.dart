part of '../thulium_campus.dart';

const _LEARN_COURSE_CACHE_MAX_AGE = Duration(hours: 24);

/// Converts a local calendar date into the academic semester used by Learn.
///
/// The middle of February, July, and September is the chosen boundary. This
/// keeps the summer term attached to the academic year that just ended.
abstract final class AcademicSemester {
  static String forDate(DateTime date) {
    final year = date.year;
    final month = date.month;
    final day = date.day;
    if (month > 9 || (month == 9 && day >= 15)) {
      return '$year-${year + 1}-1';
    }
    if (month > 7 || (month == 7 && day >= 15)) {
      return '${year - 1}-$year-3';
    }
    if (month > 2 || (month == 2 && day >= 15)) {
      return '${year - 1}-$year-2';
    }
    return '${year - 1}-$year-1';
  }
}

/// One course from Learn, with names kept separate from calendar occurrences.
final class LearnCourse {
  const LearnCourse({
    required this.id,
    required this.name,
    required this.englishName,
    required this.teacherName,
    required this.schedule,
  });

  final String id;
  final String name;
  final String englishName;
  final String teacherName;
  final String schedule;

  Map<String, String> toJson() => {
    'id': id,
    'name': name,
    'englishName': englishName,
    'teacherName': teacherName,
    'schedule': schedule,
  };

  factory LearnCourse.fromJson(Map<String, dynamic> data) => LearnCourse(
    id: data['id'] as String,
    name: data['name'] as String,
    englishName: data['englishName'] as String,
    teacherName: data['teacherName'] as String,
    schedule: data['schedule'] as String,
  );
}

/// Account- and semester-scoped names used by Study and the teaching calendar.
final class LearnCourseCatalog {
  LearnCourseCatalog({
    required this.userId,
    required this.semester,
    required List<LearnCourse> courses,
    this.rawResponse,
  }) : courses = List.unmodifiable(courses);

  final String userId;
  final String semester;
  final List<LearnCourse> courses;

  /// Retains the complete provider response for the CLI's detailed view.
  final Map<String, dynamic>? rawResponse;

  factory LearnCourseCatalog.fromResponse(
    Map<String, dynamic> response,
    String semester,
  ) {
    final rows = response['resultList'] as List;
    final courses = <LearnCourse>[];
    for (final raw in rows) {
      final row = raw as Map;
      final primaryName = _courseField(row['kcm']);
      final name = primaryName.isNotEmpty
          ? primaryName
          : _courseField(row['zywkcm']);
      if (name.isEmpty) continue;
      courses.add(
        LearnCourse(
          id: _courseField(row['wlkcid'] ?? row['kch']),
          name: name,
          englishName: _courseField(row['ywkcm']),
          teacherName: _courseField(row['jsm']),
          schedule: _courseField(row['sjddb']),
        ),
      );
    }
    return LearnCourseCatalog(
      userId: response['currentUser'] as String,
      semester: semester,
      courses: courses,
      rawResponse: Map<String, dynamic>.unmodifiable(response),
    );
  }

  /// Only exact, unambiguous names are translated; user plans are excluded.
  CourseSchedule applyEnglishNames(CourseSchedule schedule) {
    final translations = <String, String>{};
    final ambiguous = <String>{};
    for (final course in courses) {
      final chinese = course.name.trim();
      final english = course.englishName.trim();
      if (chinese.isEmpty || english.isEmpty) continue;
      if (translations.containsKey(chinese) &&
          translations[chinese] != english) {
        ambiguous.add(chinese);
      } else {
        translations[chinese] = english;
      }
    }
    return CourseSchedule(
      term: schedule.term,
      occurrences: [
        for (final occurrence in schedule.occurrences)
          occurrence.category != PlanCategories.LESSON ||
                  ambiguous.contains(occurrence.name.trim())
              ? occurrence
              : occurrence.copyWith(
                  coursesPlanEnglishName:
                      translations[occurrence.name.trim()] ?? '',
                ),
      ],
    );
  }
}

String _courseField(Object? value) => value is String ? value.trim() : '';

enum LearnCourseSource { network, freshCache, staleCache }

/// Reads Learn only when the semester cache is missing or older than a day.
final class LearnCourseCatalogService {
  LearnCourseCatalogService(this._authClient, {this.cache, this.now});

  final TsinghuaAuthClient _authClient;
  final LearnCourseCache? cache;
  final DateTime Function()? now;

  /// Origin of the most recent result, including offline fallback.
  LearnCourseSource? lastSource;

  Future<LearnCourseCatalog> loadSemester(
    String semester, {
    bool forceRefresh = false,
  }) async {
    final userId = _authClient.session?.userId;
    if (userId == null) throw StateError('Restore a session first.');
    final currentTime = (now ?? DateTime.now)();
    CachedLearnCourses? cached;
    try {
      cached = await cache?.readFor(userId, semester);
    } on Exception {
      // A secure-store read failure must not prevent a network request.
    }
    if (!forceRefresh &&
        cached != null &&
        cached.isFresh(currentTime, _LEARN_COURSE_CACHE_MAX_AGE)) {
      lastSource = LearnCourseSource.freshCache;
      return cached.catalog;
    }

    try {
      final response = await LearnCourseService(
        _authClient,
        now: now,
      ).fetchSemester(semester);
      final catalog = LearnCourseCatalog.fromResponse(response, semester);
      try {
        await cache?.writeFor(catalog, currentTime);
      } on Exception {
        // A successful response remains usable even if persistence fails.
      }
      lastSource = LearnCourseSource.network;
      return catalog;
    } on Object catch (error) {
      if (error is! Exception && error is! StateError) rethrow;
      if (cached == null || forceRefresh) rethrow;
      lastSource = LearnCourseSource.staleCache;
      return cached.catalog;
    }
  }
}
