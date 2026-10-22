import 'package:thulium_campus/thulium_campus.dart';

/// Time boundaries are inclusive; an assignment due now is already overdue.
enum HomeworkUrgency {
  expired,
  withinHour,
  withinDay,
  withinThreeDays,
  later,
  unknown,
}

enum HomeworkGroup { today, thisWeek, later, overdue }

DateTime beijingTime(DateTime instant) =>
    instant.toUtc().add(const Duration(hours: 8));

HomeworkUrgency homeworkUrgency(DateTime? deadline, DateTime now) {
  if (deadline == null) return HomeworkUrgency.unknown;
  final remaining = deadline.difference(now);
  if (remaining <= Duration.zero) return HomeworkUrgency.expired;
  if (remaining <= const Duration(hours: 1)) return HomeworkUrgency.withinHour;
  if (remaining <= const Duration(hours: 24)) return HomeworkUrgency.withinDay;
  if (remaining <= const Duration(days: 3)) {
    return HomeworkUrgency.withinThreeDays;
  }
  return HomeworkUrgency.later;
}

List<LearnHomework> sortHomeworkByUrgency(
  Iterable<LearnHomework> assignments,
  DateTime now,
) => assignments.toList()
  ..sort((left, right) {
    final leftExpired = left.deadline != null && !left.deadline!.isAfter(now);
    final rightExpired =
        right.deadline != null && !right.deadline!.isAfter(now);
    if (leftExpired != rightExpired) return leftExpired ? 1 : -1;
    final a = left.deadline;
    final b = right.deadline;
    if (a == null && b != null) return 1;
    if (a != null && b == null) return -1;
    final date = a != null && b != null ? a.compareTo(b) : 0;
    if (date != 0) return date;
    final course = left.course.id.compareTo(right.course.id);
    return course != 0 ? course : left.id.compareTo(right.id);
  });

HomeworkGroup homeworkGroup(DateTime? deadline, DateTime now) {
  if (deadline == null) return HomeworkGroup.later;
  if (!deadline.isAfter(now)) return HomeworkGroup.overdue;
  final today = beijingTime(now);
  final date = beijingTime(deadline);
  final tomorrow = DateTime.utc(today.year, today.month, today.day + 1);
  if (date.isBefore(tomorrow)) return HomeworkGroup.today;
  final nextMonday = DateTime.utc(
    today.year,
    today.month,
    today.day + (8 - today.weekday),
  );
  return date.isBefore(nextMonday)
      ? HomeworkGroup.thisWeek
      : HomeworkGroup.later;
}

Map<HomeworkGroup, List<LearnHomework>> groupHomework(
  Iterable<LearnHomework> assignments,
  DateTime now,
) {
  final groups = <HomeworkGroup, List<LearnHomework>>{};
  for (final assignment in sortHomeworkByUrgency(assignments, now)) {
    (groups[homeworkGroup(assignment.deadline, now)] ??= []).add(assignment);
  }
  return {
    for (final group in HomeworkGroup.values)
      if (groups.containsKey(group)) group: groups[group]!,
  };
}
