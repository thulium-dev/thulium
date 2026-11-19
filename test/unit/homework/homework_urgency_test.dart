import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:thulium/homework/homework_presentation.dart';
import 'package:thulium/homework/homework_theme.dart';
import 'package:thulium/homework/homework_urgency.dart';
import 'package:thulium_campus/thulium_campus.dart';

void main() {
  final now = DateTime.utc(2026, 10, 21, 8); // Wednesday, 16:00 Beijing.
  LearnHomework entry(String id, DateTime? deadline) =>
      LearnHomework(id: id, title: id, course: _course, deadline: deadline);
  test(
    'urgency boundaries include exactly one hour, one day and three days',
    () {
      final cases = <Duration, HomeworkUrgency>{
        const Duration(seconds: -1): HomeworkUrgency.expired,
        Duration.zero: HomeworkUrgency.expired,
        const Duration(seconds: 1): HomeworkUrgency.withinHour,
        const Duration(hours: 1): HomeworkUrgency.withinHour,
        const Duration(hours: 1, seconds: 1): HomeworkUrgency.withinDay,
        const Duration(hours: 24): HomeworkUrgency.withinDay,
        const Duration(hours: 24, seconds: 1): HomeworkUrgency.withinThreeDays,
        const Duration(days: 3): HomeworkUrgency.withinThreeDays,
        const Duration(days: 3, seconds: 1): HomeworkUrgency.later,
      };
      for (final testCase in cases.entries) {
        expect(homeworkUrgency(now.add(testCase.key), now), testCase.value);
      }
      expect(homeworkUrgency(null, now), HomeworkUrgency.unknown);
    },
  );
  test(
    'sorts upcoming deadlines first and overdue last without mutating input',
    () {
      final input = [
        entry('unknown', null),
        entry('later', now.add(const Duration(days: 6))),
        entry('b', now),
        entry('old', now.subtract(const Duration(days: 1))),
        entry('a', now),
      ];
      expect(sortHomeworkByUrgency(input, now).map((e) => e.id), [
        'later',
        'unknown',
        'old',
        'a',
        'b',
      ]);
      expect(input.first.id, 'unknown');
    },
  );
  test('groups by Beijing dates, Monday week boundary, omits empty groups', () {
    final groups = groupHomework([
      entry('next-week', DateTime.utc(2026, 10, 25, 16)),
      entry('sunday', DateTime.utc(2026, 10, 25, 15, 59)),
      entry('tomorrow', DateTime.utc(2026, 10, 21, 16)),
      entry('today', DateTime.utc(2026, 10, 21, 15, 59)),
      entry('expired', now),
      entry('unknown', null),
    ], now);
    expect(groups.keys, HomeworkGroup.values);
    expect(groups[HomeworkGroup.overdue]!.single.id, 'expired');
    expect(groups[HomeworkGroup.today]!.single.id, 'today');
    expect(groups[HomeworkGroup.thisWeek]!.map((e) => e.id), [
      'tomorrow',
      'sunday',
    ]);
    expect(groups[HomeworkGroup.later]!.map((e) => e.id), [
      'next-week',
      'unknown',
    ]);
    expect(groupHomework([], now), isEmpty);
    expect(
      groupHomework([
        entry('today', now.add(const Duration(minutes: 1))),
      ], now).keys,
      [HomeworkGroup.today],
    );
  });
  test(
    'Beijing grouping crosses UTC month and year without device timezone',
    () {
      final newYear = DateTime.utc(2026, 12, 31, 16);
      expect(beijingTime(newYear), DateTime.utc(2027));
      expect(
        homeworkGroup(newYear.add(const Duration(hours: 1)), newYear),
        HomeworkGroup.today,
      );
      final sunday = DateTime.utc(2026, 10, 25, 15);
      expect(
        homeworkGroup(sunday.add(const Duration(hours: 1)), sunday),
        HomeworkGroup.later,
      );
    },
  );
  for (final dark in [false, true]) {
    test(
      'small text contrast meets WCAG AA in ${dark ? 'dark' : 'light'} theme',
      () {
        final theme = dark
            ? FThemes.neutral.dark.touch
            : FThemes.neutral.light.touch;
        expect(
          textContrast(readableSecondary(theme), theme.colors.background),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          textContrast(destructiveBadgeText(theme), theme.colors.destructive),
          greaterThanOrEqualTo(4.5),
        );
        final palette = HomeworkPalette.forBrightness(theme.colors.brightness);
        for (final background in [palette.yellow, palette.green]) {
          expect(
            textContrast(badgeTextOn(theme, background), background),
            greaterThanOrEqualTo(4.5),
          );
        }
        final badge = theme.badgeStyles.resolve({FBadgeVariant.secondary});
        expect(
          textContrast(
            badge.contentStyle.labelTextStyle.color!,
            theme.colors.secondary,
          ),
          greaterThanOrEqualTo(4.5),
        );
      },
    );
  }
}

const _course = LearnCourse(
  id: 'physics',
  name: '物理',
  englishName: 'Physics',
  teacherName: '',
  schedule: '',
);
