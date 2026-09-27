import 'package:flutter_test/flutter_test.dart';
import 'package:thulium/widgets/calendar_course_layout.dart';
import 'package:thulium_campus/thulium_campus.dart';

void main() {
  test('simultaneous overlaps receive equal, separate lanes', () {
    final placements = layoutCalendarCourses([
      _course('C', 9, 30, 10, 30),
      _course('A', 8, 0, 10, 0),
      _course('B', 9, 0, 11, 0),
    ]);

    expect(placements, hasLength(3));
    expect(placements.map((entry) => entry.laneCount), everyElement(3));
    expect(placements.map((entry) => entry.lane).toSet(), {0, 1, 2});
  });

  test('staggered overlaps reuse lanes but keep the group width equal', () {
    final placements = layoutCalendarCourses([
      _course('C', 10, 0, 12, 0),
      _course('B', 9, 0, 11, 0),
      _course('A', 8, 0, 10, 0),
      _course('D', 13, 0, 14, 0),
    ]);

    final group = placements.take(3).toList();
    expect(group.map((entry) => entry.laneCount), everyElement(2));
    expect(group.map((entry) => entry.lane), [0, 1, 0]);
    expect(placements.last.laneCount, 1);
    expect(placements.last.lane, 0);
  });

  test('courses touching at an endpoint do not split the day width', () {
    final placements = layoutCalendarCourses([
      _course('A', 8, 0, 9, 0),
      _course('B', 9, 0, 10, 0),
    ]);

    expect(placements.map((entry) => entry.laneCount), everyElement(1));
    expect(placements.map((entry) => entry.lane), everyElement(0));
  });

  test('records the maximal union interval for the overlap tap target', () {
    final groups = layoutCalendarCourseGroups([
      _course('A', 8, 0, 9, 0),
      _course('B', 8, 30, 10, 0),
      _course('C', 9, 30, 11, 0),
      _course('D', 11, 0, 12, 0),
    ]);

    expect(groups, hasLength(2));
    expect(groups.first.hasOverlap, isTrue);
    expect(groups.first.courses.map((entry) => entry.name), ['A', 'B', 'C']);
    expect(groups.first.startsAt, DateTime(2026, 9, 7, 8));
    expect(groups.first.endsAt, DateTime(2026, 9, 7, 11));
    expect(groups.last.hasOverlap, isFalse);
  });
}

CourseOccurrence _course(
  String name,
  int startHour,
  int startMinute,
  int endHour,
  int endMinute,
) => CourseOccurrence(
  name: name,
  location: 'Room 101',
  category: PlanCategories.LESSON,
  startsAt: DateTime(2026, 9, 7, startHour, startMinute),
  endsAt: DateTime(2026, 9, 7, endHour, endMinute),
);
