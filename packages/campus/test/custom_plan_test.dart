import 'dart:convert';

import 'package:test/test.dart';
import 'package:thulium_campus/thulium_campus.dart';

void main() {
  final start = DateTime(2026, 9, 21, 9);
  final end = DateTime(2026, 9, 21, 10);

  CustomPlan plan(PlanRepeat repeat, {int intervalDays = 1}) => CustomPlan(
    id: 'plan-1',
    name: 'Study group',
    location: 'Library',
    startsAt: start,
    endsAt: end,
    category: 'user.study',
    repeat: repeat,
    intervalDays: intervalDays,
  );

  test('daily and interval rules expand only visible civil dates', () {
    final rangeStart = DateTime(2026, 9, 23);
    final rangeEnd = DateTime(2026, 9, 27);
    expect(
      plan(PlanRepeat.daily)
          .occurrencesBetween(rangeStart, rangeEnd)
          .map((occurrence) => occurrence.startsAt.day),
      [23, 24, 25, 26],
    );
    expect(
      plan(PlanRepeat.intervalDays, intervalDays: 3)
          .occurrencesBetween(rangeStart, rangeEnd)
          .map((occurrence) => occurrence.startsAt.day),
      [24],
    );
  });

  test('weekly rule starts on the selected date and does not drift', () {
    final dates = plan(
      PlanRepeat.weekly,
    ).occurrencesBetween(DateTime(2026, 9, 21), DateTime(2026, 10, 12));
    expect(dates.map((occurrence) => occurrence.startsAt.day), [21, 28, 5]);
  });

  test('one-time plans appear only in their starting week', () {
    expect(
      plan(
        PlanRepeat.none,
      ).occurrencesBetween(DateTime(2026, 9, 28), DateTime(2026, 10, 5)),
      isEmpty,
    );
  });

  test('categories and rules survive serialization', () {
    final collection = CustomPlanCollection(
      categories: [
        const CustomPlanCategory(
          id: 'user.study',
          name: 'Study',
          colorValue: 0xFF6B5CE7,
        ),
      ],
      plans: [plan(PlanRepeat.intervalDays, intervalDays: 3)],
    );
    final restored = CustomPlanCollection.decode(collection.encode());
    expect(restored.categories.single.colorValue, 0xFF6B5CE7);
    expect(restored.plans.single.repeat, PlanRepeat.intervalDays);
    expect(restored.plans.single.intervalDays, 3);
    expect(restored.plans.single.category, 'user.study');
  });

  test('invalid same-day time range is rejected', () {
    expect(
      () => CustomPlan(
        id: 'x',
        name: 'x',
        location: 'y',
        startsAt: end,
        endsAt: start,
        category: PlanCategories.LESSON,
        repeat: PlanRepeat.none,
      ),
      throwsArgumentError,
    );
  });

  test('one-off edits and cancellation leave other repetitions intact', () {
    final rule = plan(PlanRepeat.weekly);
    final original = CustomPlanCollection(categories: [], plans: [rule]);
    final firstWeek = original
        .entriesForWeek([], DateTime(2026, 9, 21), DateTime(2026, 9, 28))
        .single;
    final secondWeek = original
        .entriesForWeek([], DateTime(2026, 9, 28), DateTime(2026, 10, 5))
        .single;
    final moved = original.replaceOccurrence(
      secondWeek,
      CourseOccurrence(
        name: 'Revised group',
        location: 'Room 2',
        startsAt: DateTime(2026, 10, 1, 11),
        endsAt: DateTime(2026, 10, 1, 12),
        category: 'user.study',
      ),
    );
    expect(
      moved
          .entriesForWeek([], DateTime(2026, 9, 21), DateTime(2026, 9, 28))
          .single
          .occurrence
          .name,
      firstWeek.occurrence.name,
    );
    final edited = moved
        .entriesForWeek([], DateTime(2026, 9, 28), DateTime(2026, 10, 5))
        .single;
    expect(edited.occurrence.startsAt, DateTime(2026, 10, 1, 11));
    expect(edited.originalStartsAt, secondWeek.originalStartsAt);
    final cancelled = moved.replaceOccurrence(edited, null);
    expect(
      cancelled.entriesForWeek(
        [],
        DateTime(2026, 9, 28),
        DateTime(2026, 10, 5),
      ),
      isEmpty,
    );
    expect(
      cancelled.entriesForWeek(
        [],
        DateTime(2026, 10, 5),
        DateTime(2026, 10, 12),
      ),
      hasLength(1),
    );
  });

  test('moved occurrence appears in a different week exactly once', () {
    final original = CustomPlanCollection(
      categories: [],
      plans: [plan(PlanRepeat.weekly)],
    );
    final selected = original
        .entriesForWeek([], DateTime(2026, 9, 21), DateTime(2026, 9, 28))
        .single;
    final moved = original.replaceOccurrence(
      selected,
      CourseOccurrence(
        name: selected.occurrence.name,
        location: selected.occurrence.location,
        startsAt: DateTime(2026, 9, 29, 9),
        endsAt: DateTime(2026, 9, 29, 10),
        category: selected.occurrence.category,
      ),
    );
    expect(
      moved.entriesForWeek([], DateTime(2026, 9, 21), DateTime(2026, 9, 28)),
      isEmpty,
    );
    expect(
      moved.entriesForWeek([], DateTime(2026, 9, 28), DateTime(2026, 10, 5)),
      hasLength(2),
    );
  });

  test(
    'series edit resets exceptions and series deletion removes every week',
    () {
      final original = CustomPlanCollection(
        categories: [],
        plans: [plan(PlanRepeat.weekly)],
      );
      final first = original
          .entriesForWeek([], DateTime(2026, 9, 21), DateTime(2026, 9, 28))
          .single;
      final cancelled = original.replaceOccurrence(first, null);
      final renamed = cancelled.replaceSeries(
        CustomPlan(
          id: 'plan-1',
          name: 'New title',
          location: 'Library',
          startsAt: start,
          endsAt: end,
          category: 'user.study',
          repeat: PlanRepeat.weekly,
        ),
      );
      expect(renamed.overrides, hasLength(1));
      final revised = cancelled.replaceSeries(plan(PlanRepeat.daily));
      expect(revised.overrides, isEmpty);
      expect(
        revised.entriesForWeek(
          [],
          DateTime(2026, 9, 21),
          DateTime(2026, 9, 28),
        ),
        hasLength(7),
      );
      final deleted = revised.deleteSeries(
        revised
            .entriesForWeek([], DateTime(2026, 9, 21), DateTime(2026, 9, 28))
            .first,
      );
      expect(deleted.plans, isEmpty);
      expect(deleted.overrides, isEmpty);
    },
  );

  test('fetched lessons have no repetition and use local-only overrides', () {
    final lesson = CourseOccurrence(
      name: 'Physics',
      location: 'Room 1',
      startsAt: start,
      endsAt: end,
      category: PlanCategories.LESSON,
    );
    final original = CustomPlanCollection.empty();
    final entry = original
        .entriesForWeek([lesson], DateTime(2026, 9, 21), DateTime(2026, 9, 28))
        .single;
    expect(entry.repeats, isFalse);
    expect(entry.fetchedLesson, isTrue);
    final hidden = original.deleteSeries(entry);
    expect(
      hidden.entriesForWeek(
        [lesson],
        DateTime(2026, 9, 21),
        DateTime(2026, 9, 28),
      ),
      isEmpty,
    );
    expect(hidden.plans, isEmpty);
  });

  test('version-one data migrates and warning preferences persist', () {
    final old = jsonEncode({
      'version': 1,
      'categories': <Object>[],
      'plans': [plan(PlanRepeat.weekly).toJson()],
    });
    final restored = CustomPlanCollection.decode(old);
    expect(restored.plans, hasLength(1));
    expect(restored.overrides, isEmpty);
    final updated = CustomPlanCollection.decode(
      restored
          .copyWith(skipDeleteConfirmation: true, skipCancelConfirmation: true)
          .encode(),
    );
    expect(updated.skipDeleteConfirmation, isTrue);
    expect(updated.skipCancelConfirmation, isTrue);
  });

  test('legacy Personal plans keep a selectable category after migration', () {
    final legacyPlan = CustomPlan(
      id: 'old',
      name: 'Gym',
      location: 'Sports center',
      startsAt: start,
      endsAt: end,
      category: 'personal',
      repeat: PlanRepeat.none,
    );
    final old = jsonEncode({
      'version': 1,
      'categories': <Object>[],
      'plans': [legacyPlan.toJson()],
    });
    final restored = CustomPlanCollection.decode(old);
    expect(restored.categories.single.id, 'personal');
    expect(restored.plans.single.category, 'personal');
    expect(CustomPlanCollection.empty().categories, isEmpty);
  });
}
