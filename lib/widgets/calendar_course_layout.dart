import 'package:thulium_campus/thulium_campus.dart';

/// A course's equal-width lane within one overlapping group of a day.
final class CalendarCoursePlacement {
  const CalendarCoursePlacement({
    required this.course,
    required this.lane,
    required this.laneCount,
  });

  final CourseOccurrence course;
  final int lane;
  final int laneCount;
}

/// The maximal continuous time region formed by overlapping courses.
final class CalendarCourseGroup {
  const CalendarCourseGroup({
    required this.courses,
    required this.placements,
    required this.startsAt,
    required this.endsAt,
    required this.laneCount,
  });

  final List<CourseOccurrence> courses;
  final List<CalendarCoursePlacement> placements;
  final DateTime startsAt;
  final DateTime endsAt;
  final int laneCount;

  bool get hasOverlap => laneCount > 1;
}

/// Assigns overlapping courses to equal-width lanes for one calendar day.
///
/// A connected overlap group uses its maximum simultaneous course count as
/// its lane count. Courses with touching endpoints do not overlap and may
/// reuse a lane. This lets staggered courses share space without covering one
/// another, while every course in the group retains the same allocated width.
List<CalendarCourseGroup> layoutCalendarCourseGroups(
  List<CourseOccurrence> courses,
) {
  final sorted = courses.toList()
    ..sort((a, b) {
      final start = a.startsAt.compareTo(b.startsAt);
      if (start != 0) return start;
      return a.endsAt.compareTo(b.endsAt);
    });
  final groups = <CalendarCourseGroup>[];
  final group = <CourseOccurrence>[];
  DateTime? groupEnd;

  void finishGroup() {
    if (group.isEmpty) return;
    final laneEnds = <DateTime>[];
    final assignments = <(CourseOccurrence, int)>[];
    for (final course in group) {
      var lane = laneEnds.indexWhere((end) => !end.isAfter(course.startsAt));
      if (lane == -1) {
        lane = laneEnds.length;
        laneEnds.add(course.endsAt);
      } else {
        laneEnds[lane] = course.endsAt;
      }
      assignments.add((course, lane));
    }
    groups.add(
      CalendarCourseGroup(
        courses: List.unmodifiable(group),
        placements: List.unmodifiable([
          for (final (course, lane) in assignments)
            CalendarCoursePlacement(
              course: course,
              lane: lane,
              laneCount: laneEnds.length,
            ),
        ]),
        startsAt: group.first.startsAt,
        endsAt: groupEnd!,
        laneCount: laneEnds.length,
      ),
    );
    group.clear();
  }

  for (final course in sorted) {
    if (groupEnd != null && !course.startsAt.isBefore(groupEnd)) {
      finishGroup();
      groupEnd = null;
    }
    group.add(course);
    if (groupEnd == null || course.endsAt.isAfter(groupEnd)) {
      groupEnd = course.endsAt;
    }
  }
  finishGroup();
  return groups;
}

/// Flattens overlap groups for callers that only need lane assignments.
List<CalendarCoursePlacement> layoutCalendarCourses(
  List<CourseOccurrence> courses,
) => [
  for (final group in layoutCalendarCourseGroups(courses)) ...group.placements,
];
