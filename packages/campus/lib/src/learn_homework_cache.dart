part of '../thulium_campus.dart';

const _HOMEWORK_CACHE_VERSION = 1;
const _HOMEWORK_CACHE_MAX_LENGTH = 2 * 1024 * 1024;

abstract interface class LearnHomeworkCacheStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> clear();
}

final class CachedLearnHomework {
  const CachedLearnHomework({required this.snapshot, required this.fetchedAt});

  final LearnHomeworkSnapshot snapshot;
  final DateTime fetchedAt;
}

/// Retains one account's semester snapshot for display while updating/offline.
/// Deadlines remain absolute instants; countdowns and urgency are never stored.
final class LearnHomeworkCache {
  const LearnHomeworkCache(this._store);

  final LearnHomeworkCacheStore _store;

  Future<CachedLearnHomework?> readFor(String userId, String semester) async {
    final value = await _store.read();
    if (value == null || value.length > _HOMEWORK_CACHE_MAX_LENGTH) return null;
    try {
      final data = jsonDecode(value);
      if (data is! Map ||
          data['version'] != _HOMEWORK_CACHE_VERSION ||
          data['userId'] != userId ||
          data['semester'] != semester) {
        return null;
      }
      final fetchedAt = _utcTime(data['fetchedAt']);
      if (fetchedAt == null) return null;
      final rawCounts = data['counts'] as Map;
      if (rawCounts.length > 1000) return null;
      final counts = <String, int>{};
      for (final entry in rawCounts.entries) {
        if (entry.key is! String ||
            (entry.key as String).isEmpty ||
            entry.value is! int ||
            (entry.value as int) < 0) {
          return null;
        }
        counts[entry.key as String] = entry.value as int;
      }
      final rows = data['assignments'] as List;
      if (rows.length > 10000) return null;
      final assignments = <LearnHomework>[];
      final ids = <(String, String)>{};
      final actualCounts = {for (final id in counts.keys) id: 0};
      for (final row in rows) {
        final entry = row as Map;
        final course = LearnCourse.fromJson(
          Map<String, dynamic>.from(entry['course'] as Map),
        );
        final id = entry['id'] as String;
        final title = entry['title'] as String;
        final deadline = entry['deadline'] == null
            ? null
            : _utcTime(entry['deadline']);
        if (!counts.containsKey(course.id) ||
            id.isEmpty ||
            title.trim().isEmpty ||
            !ids.add((course.id, id)) ||
            (entry['deadline'] != null && deadline == null)) {
          return null;
        }
        actualCounts[course.id] = actualCounts[course.id]! + 1;
        assignments.add(
          LearnHomework(
            id: id,
            course: course,
            title: title,
            deadline: deadline,
          ),
        );
      }
      if (counts.entries.any(
        (entry) => actualCounts[entry.key] != entry.value,
      )) {
        return null;
      }
      return CachedLearnHomework(
        fetchedAt: fetchedAt,
        snapshot: LearnHomeworkSnapshot(
          counts: counts,
          assignments: assignments,
        ),
      );
    } on Exception {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<void> writeFor(
    String userId,
    String semester,
    LearnHomeworkSnapshot snapshot,
    DateTime fetchedAt,
  ) async {
    final payload = jsonEncode({
      'version': _HOMEWORK_CACHE_VERSION,
      'userId': userId,
      'semester': semester,
      'fetchedAt': fetchedAt.toUtc().toIso8601String(),
      'counts': snapshot.counts,
      'assignments': [
        for (final assignment in snapshot.assignments)
          {
            'id': assignment.id,
            'course': assignment.course.toJson(),
            'title': assignment.title,
            'deadline': assignment.deadline?.toUtc().toIso8601String(),
          },
      ],
    });
    if (payload.length > _HOMEWORK_CACHE_MAX_LENGTH) {
      throw const FormatException('Homework snapshot is too large to cache.');
    }
    await _store.write(payload);
  }

  Future<void> clear() => _store.clear();

  DateTime? _utcTime(Object? value) =>
      value is String && value.endsWith('Z') ? DateTime.tryParse(value) : null;
}
