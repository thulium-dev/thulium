import 'package:test/test.dart';
import 'package:thulium_campus/thulium_campus.dart';

void main() {
  test('uses mid-month academic semester boundaries', () {
    final examples = <DateTime, String>{
      DateTime(2025, 9, 15): '2025-2026-1',
      DateTime(2026, 2, 14): '2025-2026-1',
      DateTime(2026, 2, 15): '2025-2026-2',
      DateTime(2026, 7, 14): '2025-2026-2',
      DateTime(2026, 7, 15): '2025-2026-3',
      DateTime(2026, 9, 14): '2025-2026-3',
      DateTime(2026, 9, 15): '2026-2027-1',
    };
    for (final entry in examples.entries) {
      expect(AcademicSemester.forDate(entry.key), entry.value);
    }
  });

  test('translates only fetched lessons with an exact course name', () {
    final catalog = LearnCourseCatalog(
      userId: 'student',
      semester: '2025-2026-1',
      courses: [
        const LearnCourse(
          id: 'id-1',
          name: '大学物理',
          englishName: 'University Physics',
          teacherName: '',
          schedule: '',
        ),
      ],
    );
    final start = DateTime(2025, 9, 15, 8);
    final lesson = CourseOccurrence(
      name: '大学物理',
      location: 'A101',
      startsAt: start,
      endsAt: start.add(const Duration(hours: 1)),
      category: PlanCategories.LESSON,
    );
    final personal = CourseOccurrence(
      name: '大学物理',
      location: 'Library',
      startsAt: start.add(const Duration(hours: 2)),
      endsAt: start.add(const Duration(hours: 3)),
      category: 'my-category',
    );
    final schedule = CourseSchedule(
      term: AcademicTerm(
        id: '2025-2026-1',
        name: 'Fall',
        firstMonday: DateTime(2025, 9, 15),
        weekCount: 16,
      ),
      occurrences: [lesson, personal],
    );

    final translated = catalog.applyEnglishNames(schedule);
    expect(
      translated.occurrences.first.coursesPlanEnglishName,
      'University Physics',
    );
    expect(
      translated.occurrences.first.nameForLanguage('en'),
      'University Physics',
    );
    expect(translated.occurrences.first.nameForLanguage('zh'), '大学物理');
    expect(translated.occurrences.last.coursesPlanEnglishName, isEmpty);
    expect(translated.occurrences.last.nameForLanguage('en'), '大学物理');
  });

  test('leaves ambiguous English titles untranslated', () {
    final catalog = LearnCourseCatalog(
      userId: 'student',
      semester: '2025-2026-1',
      courses: [
        for (final english in ['Course A', 'Course B'])
          LearnCourse(
            id: english,
            name: '同名课程',
            englishName: english,
            teacherName: '',
            schedule: '',
          ),
      ],
    );
    final schedule = CourseSchedule(
      term: AcademicTerm(
        id: '2025-2026-1',
        name: 'Fall',
        firstMonday: DateTime(2025, 9, 15),
        weekCount: 16,
      ),
      occurrences: [
        CourseOccurrence(
          name: '同名课程',
          location: 'A',
          startsAt: DateTime(2025, 9, 15, 8),
          endsAt: DateTime(2025, 9, 15, 9),
          category: PlanCategories.LESSON,
        ),
      ],
    );
    expect(
      catalog
          .applyEnglishNames(schedule)
          .occurrences
          .single
          .nameForLanguage('en'),
      '同名课程',
    );
  });

  test('course list cache is account- and semester-scoped', () async {
    final store = _InMemoryStore();
    final cache = LearnCourseCache(store);
    final catalog = LearnCourseCatalog(
      userId: 'student-a',
      semester: '2025-2026-1',
      courses: [
        const LearnCourse(
          id: 'course-1',
          name: '课程',
          englishName: 'Course',
          teacherName: 'Teacher',
          schedule: 'Monday',
        ),
      ],
      rawResponse: const {
        'currentUser': 'student-a',
        'resultList': [
          {'kcm': '课程', 'xss': 25},
        ],
      },
    );
    final fetchedAt = DateTime.utc(2026, 2, 1);
    await cache.writeFor(catalog, fetchedAt);

    final restored = await cache.readFor('student-a', '2025-2026-1');
    expect(restored?.catalog.courses.single.englishName, 'Course');
    expect(restored?.catalog.rawResponse?['resultList'], isNotNull);
    expect(
      restored?.isFresh(
        fetchedAt.add(const Duration(hours: 23)),
        const Duration(hours: 24),
      ),
      isTrue,
    );
    expect(
      restored?.isFresh(
        fetchedAt.add(const Duration(hours: 24)),
        const Duration(hours: 24),
      ),
      isFalse,
    );
    expect(await cache.readFor('student-b', '2025-2026-1'), isNull);
    expect(await cache.readFor('student-a', '2025-2026-2'), isNull);
    await cache.clear();
    expect(await cache.readFor('student-a', '2025-2026-1'), isNull);
  });
}

final class _InMemoryStore implements LearnCourseCacheStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;

  @override
  Future<void> clear() async => value = null;
}
