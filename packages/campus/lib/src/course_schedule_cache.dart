part of '../thulium_campus.dart';

const _SCHEDULE_CACHE_VERSION = 2;
const _MAX_CACHE_LENGTH = 1024 * 1024;

/// A platform-specific store for one compressed, account-scoped timetable.
/// Implementations should protect the value as local student data.
abstract interface class CourseScheduleCacheStore {
  Future<String?> read();

  Future<void> write(String value);

  Future<void> clear();
}

/// A dated snapshot lets callers distinguish fresh and offline schedule data.
final class CachedCourseSchedule {
  const CachedCourseSchedule({
    required this.userId,
    required this.fetchedAt,
    required this.schedule,
  });

  final String userId;
  final DateTime fetchedAt;
  final CourseSchedule schedule;

  bool isFresh(DateTime now, Duration maxAge) {
    final age = now.difference(fetchedAt);
    return !age.isNegative && age < maxAge;
  }

  /// An ended term must not masquerade as the current timetable indefinitely.
  bool isRelevant(DateTime now) => now.isBefore(
    schedule.term.firstMonday.add(
      Duration(days: (schedule.term.weekCount + 2) * DateTime.daysPerWeek),
    ),
  );
}

/// Serializes schedule snapshots without storing sessions or credentials.
final class CourseScheduleCache {
  const CourseScheduleCache(this._store);

  final CourseScheduleCacheStore _store;

  Future<CachedCourseSchedule?> readFor(String userId) async {
    final encoded = await _store.read();
    if (encoded == null || encoded.length > _MAX_CACHE_LENGTH) return null;
    try {
      final bytes = gzip.decode(base64Decode(encoded));
      if (bytes.length > _MAX_CACHE_LENGTH) return null;
      final data = jsonDecode(utf8.decode(bytes));
      if (data is! Map<String, dynamic> ||
          (data['version'] != 1 &&
              data['version'] != _SCHEDULE_CACHE_VERSION) ||
          data['userId'] != userId) {
        return null;
      }
      final termJson = data['term'] as Map<String, dynamic>;
      final rows = data['occurrences'] as List<dynamic>;
      final term = AcademicTerm(
        id: termJson['id'] as String,
        name: termJson['name'] as String,
        firstMonday: DateTime.parse(termJson['firstMonday'] as String),
        weekCount: termJson['weekCount'] as int,
      );
      if (term.weekCount <= 0 || term.weekCount > 60 || rows.length > 10000) {
        return null;
      }
      return CachedCourseSchedule(
        userId: userId,
        fetchedAt: DateTime.parse(data['fetchedAt'] as String),
        schedule: CourseSchedule(
          term: term,
          occurrences: List<CourseOccurrence>.unmodifiable(
            rows.map((entry) {
              final row = entry as Map<String, dynamic>;
              return CourseOccurrence(
                name: row['name'] as String,
                location: row['location'] as String,
                // Version 1 predates categories and only stored lessons.
                category: data['version'] == 1
                    ? PlanCategories.LESSON
                    : row['category'] as String,
                startsAt: DateTime.parse(row['startsAt'] as String),
                endsAt: DateTime.parse(row['endsAt'] as String),
              );
            }),
          ),
        ),
      );
    } on Exception {
      // A damaged or older cache is a miss, not a calendar failure.
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<void> writeFor(
    String userId,
    CourseSchedule schedule,
    DateTime fetchedAt,
  ) async {
    final data = <String, Object>{
      'version': _SCHEDULE_CACHE_VERSION,
      'userId': userId,
      'fetchedAt': fetchedAt.toUtc().toIso8601String(),
      'term': {
        'id': schedule.term.id,
        'name': schedule.term.name,
        'firstMonday': schedule.term.firstMonday.toIso8601String(),
        'weekCount': schedule.term.weekCount,
      },
      'occurrences': [
        for (final row in schedule.occurrences)
          {
            'name': row.name,
            'location': row.location,
            'category': row.category,
            'startsAt': row.startsAt.toIso8601String(),
            'endsAt': row.endsAt.toIso8601String(),
          },
      ],
    };
    final encoded = base64Encode(gzip.encode(utf8.encode(jsonEncode(data))));
    await _store.write(encoded);
  }

  Future<void> clear() => _store.clear();
}
