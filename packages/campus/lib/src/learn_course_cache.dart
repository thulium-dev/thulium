part of '../thulium_campus.dart';

const _LEARN_CACHE_VERSION = 1;
const _LEARN_CACHE_MAX_LENGTH = 1024 * 1024;

/// A platform-specific protected store for one account's semester catalog.
abstract interface class LearnCourseCacheStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> clear();
}

final class CachedLearnCourses {
  const CachedLearnCourses({required this.catalog, required this.fetchedAt});

  final LearnCourseCatalog catalog;
  final DateTime fetchedAt;

  bool isFresh(DateTime now, Duration maxAge) {
    final age = now.difference(fetchedAt);
    return !age.isNegative && age < maxAge;
  }
}

/// Stores the compressed catalog and CLI response, never auth credentials.
final class LearnCourseCache {
  const LearnCourseCache(this._store);

  final LearnCourseCacheStore _store;

  Future<CachedLearnCourses?> readFor(String userId, String semester) async {
    final encoded = await _store.read();
    if (encoded == null || encoded.length > _LEARN_CACHE_MAX_LENGTH) {
      return null;
    }
    try {
      final bytes = gzip.decode(base64Decode(encoded));
      if (bytes.length > _LEARN_CACHE_MAX_LENGTH) return null;
      final data = jsonDecode(utf8.decode(bytes));
      if (data is! Map<String, dynamic> ||
          data['version'] != _LEARN_CACHE_VERSION ||
          data['userId'] != userId ||
          data['semester'] != semester) {
        return null;
      }
      final rows = data['courses'] as List;
      if (rows.length > 1000) return null;
      return CachedLearnCourses(
        fetchedAt: DateTime.parse(data['fetchedAt'] as String),
        catalog: LearnCourseCatalog(
          userId: userId,
          semester: semester,
          rawResponse: data['rawResponse'] is Map
              ? Map<String, dynamic>.from(data['rawResponse'] as Map)
              : null,
          courses: [
            for (final raw in rows)
              LearnCourse.fromJson(Map<String, dynamic>.from(raw as Map)),
          ],
        ),
      );
    } on Exception {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<void> writeFor(LearnCourseCatalog catalog, DateTime fetchedAt) async {
    final payload = jsonEncode({
      'version': _LEARN_CACHE_VERSION,
      'userId': catalog.userId,
      'semester': catalog.semester,
      'fetchedAt': fetchedAt.toUtc().toIso8601String(),
      'courses': [for (final course in catalog.courses) course.toJson()],
      if (catalog.rawResponse != null) 'rawResponse': catalog.rawResponse,
    });
    await _store.write(base64Encode(gzip.encode(utf8.encode(payload))));
  }

  Future<void> clear() => _store.clear();
}
