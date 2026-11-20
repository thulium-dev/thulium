import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thulium/assistant/assistant_tools.dart';
import 'package:thulium/plans/personal_plan_repository.dart';
import 'package:thulium_auth/thulium_auth.dart';
import 'package:thulium_campus/thulium_campus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PersonalPlanRepository plans;
  late MemoryAuthSessionStore session;
  late AssistantTools agent;
  late CourseSchedule schedule;
  final changes = <PlanChange>[];
  var steps = <PlanStep>[];

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    plans = PersonalPlanRepository();
    session = MemoryAuthSessionStore();
    await session.write(
      const AuthSession(userId: 'student', fingerprint: 'test', cookies: {}),
    );
    changes.clear();
    steps = [];
    schedule = CourseSchedule(
      term: AcademicTerm(
        id: 'test',
        name: 'Test',
        firstMonday: DateTime(2026, 11, 16),
        weekCount: 16,
      ),
      occurrences: [
        CourseOccurrence(
          name: 'Physics',
          location: 'Classroom',
          startsAt: DateTime(2026, 11, 20, 13),
          endsAt: DateTime(2026, 11, 20, 15),
          category: PlanCategories.LESSON,
        ),
      ],
    );
    agent = AssistantTools(
      account: 'student',
      session: session,
      plans: plans,
      homework: () => {'available': true, 'assignments': []},
      onChanged: changes.add,
      onSteps: (value) => steps = value,
      onActivity: (_) {},
      isActive: () => true,
      loadSchedule: () async => (schedule: schedule, stale: false),
    );
  });

  tearDown(() => plans.dispose());

  Tool<Object> tool(String name) =>
      agent.tools.singleWhere((item) => item.name == name);

  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic> args = const {},
  ]) async {
    final result = await tool(name).call(args);
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> calendar(String start, String end) =>
      call('list_calendar', {'start': start, 'end': end});

  test('a plan is saved immediately without confirmation', () async {
    var notified = 0;
    plans.addListener(() => notified++);

    final result = await call('create_plan', {
      'title': 'Review physics',
      'location': 'Library',
      'start': '2026-11-20T15:00',
      'end': '2026-11-20T16:00',
    });

    expect(result['status'], 'applied');
    expect(notified, 1);
    expect(changes.single.kind, PlanChangeKind.create);
    expect(
      (await plans.readFor('student')).plans.single.name,
      'Review physics',
    );
    expect((await plans.readFor('other')).plans, isEmpty);
  });

  test('a plan may overlap the course timetable', () async {
    final result = await call('create_plan', {
      'title': 'Lab meeting',
      'location': 'Classroom',
      'start': '2026-11-20T14:00',
      'end': '2026-11-20T15:00',
    });

    expect(result['status'], 'applied');
    final stored = await plans.readFor('student');
    expect(stored.plans.single.name, 'Lab meeting');
    final day = stored.entriesBetween(
      const [],
      DateTime(2026, 11, 20),
      DateTime(2026, 11, 21),
    );
    expect(day.single.occurrence.name, 'Lab meeting');
  });

  test('two plans may share the exact same time', () async {
    for (final title in ['Reading group', 'Study group']) {
      final result = await call('create_plan', {
        'title': title,
        'location': 'Library',
        'start': '2026-11-21T09:00',
        'end': '2026-11-21T10:00',
      });
      expect(result['status'], 'applied');
    }

    final stored = await plans.readFor('student');
    expect(stored.plans, hasLength(2));
    expect(changes, hasLength(2));
  });

  test('a stale reference cannot rewrite a newer edit', () async {
    final current = await plans.readFor('student');
    await plans.save(
      'student',
      expected: current,
      next: current.copyWith(
        plans: [
          CustomPlan(
            id: 'plan.old',
            name: 'Draft me',
            location: 'Hall',
            startsAt: DateTime(2026, 11, 20, 13),
            endsAt: DateTime(2026, 11, 20, 15),
            category: PlanCategories.LESSON,
            repeat: PlanRepeat.none,
          ),
        ],
      ),
    );
    final listed = await calendar('2026-11-20', '2026-11-21');
    final reference = (listed['entries'] as List).firstWhere(
      (entry) => entry['kind'] == 'personal',
    )['edit_reference'];

    final edited = await plans.readFor('student');
    await plans.save(
      'student',
      expected: edited,
      next: edited.replaceSeries(
        CustomPlan(
          id: 'plan.old',
          name: 'Changed elsewhere',
          location: 'Hall',
          startsAt: DateTime(2026, 11, 20, 13),
          endsAt: DateTime(2026, 11, 20, 15),
          category: PlanCategories.LESSON,
          repeat: PlanRepeat.none,
        ),
      ),
    );

    final result = await call('move_plan', {
      'reference': reference,
      'start': '2026-11-20T10:00',
      'end': '2026-11-20T11:00',
    });
    expect(result['error'], isNotNull);
    expect(changes, isEmpty);
  });

  test('creates a repeating plan and its new category in one call', () async {
    final result = await call('create_plan', {
      'title': 'Reading group',
      'location': 'Library',
      'start': '2026-11-21T09:00',
      'end': '2026-11-21T10:00',
      'category': 'Research',
      'category_color': '#1C9B86',
      'repeat': 'interval_days',
      'interval_days': '3',
    });

    expect(result['status'], 'applied');
    expect(result['repeat'], 'interval_days');
    final stored = await plans.readFor('student');
    expect(stored.plans.single.repeat, PlanRepeat.intervalDays);
    expect(stored.plans.single.intervalDays, 3);
    expect(stored.categories.single.name, 'Research');
    expect(stored.categories.single.colorValue, 0xFF1C9B86);
  });

  test(
    'reuses an existing category by name instead of duplicating it',
    () async {
      final current = await plans.readFor('student');
      const category = CustomPlanCategory(
        id: 'user.existing',
        name: 'Research',
        colorValue: 0xFF1C9B86,
      );
      await plans.save(
        'student',
        expected: current,
        next: current.copyWith(categories: [category]),
      );

      await call('create_plan', {
        'title': 'Lab meeting',
        'location': 'Lab',
        'start': '2026-11-21T09:00',
        'end': '2026-11-21T10:00',
        'category': 'research',
      });

      final stored = await plans.readFor('student');
      expect(stored.categories, hasLength(1));
      expect(stored.plans.single.category, 'user.existing');
    },
  );

  test('edits one occurrence and then the whole repeating rule', () async {
    final current = await plans.readFor('student');
    await plans.save(
      'student',
      expected: current,
      next: current.copyWith(
        plans: [
          CustomPlan(
            id: 'weekly',
            name: 'Study session',
            location: 'Library',
            startsAt: DateTime(2026, 11, 21, 9),
            endsAt: DateTime(2026, 11, 21, 10),
            category: PlanCategories.LESSON,
            repeat: PlanRepeat.weekly,
          ),
        ],
      ),
    );
    final lists = await call('list_plans');
    final reference = (lists['plans'] as List).single['reference'];

    final once = await call('update_plan', {
      'reference': reference,
      'scope': 'occurrence',
      'title': 'Study alone',
      'start': '2026-11-21T11:00',
      'end': '2026-11-21T12:00',
    });
    expect(once['title'], 'Study alone');
    expect(changes.single.series, isFalse);

    final afterOne = await plans.readFor('student');
    expect(afterOne.plans.single.name, 'Study session');
    expect(
      afterOne
          .entriesBetween(
            const [],
            DateTime(2026, 11, 21),
            DateTime(2026, 11, 22),
          )
          .single
          .occurrence
          .name,
      'Study alone',
    );

    await call('update_plan', {
      'reference': reference,
      'scope': 'series',
      'title': 'Study group',
      'repeat': 'interval_days',
      'interval_days': '3',
    });
    expect(changes.last.series, isTrue);

    final updated = await plans.readFor('student');
    expect(updated.plans.single.name, 'Study group');
    expect(updated.plans.single.repeat, PlanRepeat.intervalDays);
    expect(updated.plans.single.intervalDays, 3);
    // A schedule change drops one-off exceptions that can no longer line up.
    expect(updated.overrides, isEmpty);
  });

  test('cancelling a repeating occurrence keeps the series', () async {
    final current = await plans.readFor('student');
    await plans.save(
      'student',
      expected: current,
      next: current.copyWith(
        plans: [
          CustomPlan(
            id: 'weekly',
            name: 'Study session',
            location: 'Library',
            startsAt: DateTime(2026, 11, 21, 9),
            endsAt: DateTime(2026, 11, 21, 10),
            category: PlanCategories.LESSON,
            repeat: PlanRepeat.weekly,
          ),
        ],
      ),
    );
    final result = await calendar('2026-11-21', '2026-11-22');
    final reference = (result['entries'] as List).single['edit_reference'];

    final removed = await call('remove_plan', {'reference': reference});
    expect(removed['change'], PlanChangeKind.cancel.name);

    final stored = await plans.readFor('student');
    expect(stored.plans, hasLength(1));
    expect(
      stored.entriesBetween(
        const [],
        DateTime(2026, 11, 21),
        DateTime(2026, 11, 22),
      ),
      isEmpty,
    );
    expect(
      stored.entriesBetween(
        const [],
        DateTime(2026, 11, 28),
        DateTime(2026, 11, 29),
      ),
      hasLength(1),
    );
  });

  test('deleting a series removes its rule and overrides', () async {
    final current = await plans.readFor('student');
    await plans.save(
      'student',
      expected: current,
      next: current.copyWith(
        plans: [
          CustomPlan(
            id: 'single',
            name: 'Defense',
            location: 'Room',
            startsAt: DateTime(2026, 11, 21, 9),
            endsAt: DateTime(2026, 11, 21, 10),
            category: PlanCategories.LESSON,
            repeat: PlanRepeat.none,
          ),
        ],
      ),
    );
    final result = await calendar('2026-11-21', '2026-11-22');
    final reference = (result['entries'] as List).single['edit_reference'];

    // A single plan defaults to editing the stored rule.
    final removed = await call('remove_plan', {'reference': reference});
    expect(removed['change'], PlanChangeKind.delete.name);

    expect((await plans.readFor('student')).plans, isEmpty);
  });

  test('creates, renames, recolors, and deletes a category', () async {
    final created = await call('create_category', {
      'name': 'Research',
      'color': '#1C9B86',
    });
    expect(created['category'], 'Research');

    var stored = await plans.readFor('student');
    expect(stored.categories.single.name, 'Research');

    final listed = await call('list_categories');
    final reference = (listed['categories'] as List).firstWhere(
      (item) => item['built_in'] == false,
    )['reference'];

    await call('update_category', {
      'reference': reference,
      'name': 'Reading',
      'color': '#E65C73',
    });

    stored = await plans.readFor('student');
    expect(stored.categories.single.name, 'Reading');
    expect(stored.categories.single.colorValue, 0xFFE65C73);

    await call('delete_category', {'reference': reference});

    expect((await plans.readFor('student')).categories, isEmpty);
  });

  test('refuses to delete a category that still owns plans', () async {
    final current = await plans.readFor('student');
    const category = CustomPlanCategory(
      id: 'user.owned',
      name: 'Research',
      colorValue: 0xFF1C9B86,
    );
    await plans.save(
      'student',
      expected: current,
      next: current.copyWith(
        categories: [category],
        plans: [
          CustomPlan(
            id: 'plan.1',
            name: 'Reading group',
            location: 'Library',
            startsAt: DateTime(2026, 11, 21, 9),
            endsAt: DateTime(2026, 11, 21, 10),
            category: category.id,
            repeat: PlanRepeat.none,
          ),
        ],
      ),
    );
    final listed = await call('list_categories');
    final reference = (listed['categories'] as List).firstWhere(
      (item) => item['usage'] == 1,
    )['reference'];

    final result = await call('delete_category', {'reference': reference});
    expect(result['error'], isNotNull);
    expect(changes, isEmpty);

    final duplicate = await call('create_category', {'name': 'Research'});
    expect(
      duplicate['error'],
      isNotNull,
      reason: 'Duplicate names are rejected.',
    );
  });

  test('rejects Lesson as a new category name', () async {
    final result = await call('create_category', {'name': 'lesson'});
    expect(result['error'], isNotNull);
    expect((await plans.readFor('student')).categories, isEmpty);
  });

  test('several changes in one turn are each applied', () async {
    final result = await call('create_plan', {
      'title': 'First',
      'location': 'Library',
      'start': '2026-11-22T09:00',
      'end': '2026-11-22T10:00',
    });
    expect(result['remaining_changes'], greaterThan(0));

    for (final title in ['Second', 'Third']) {
      final reply = await call('create_plan', {
        'title': title,
        'location': 'Library',
        'start': '2026-11-22T09:00',
        'end': '2026-11-22T10:00',
      });
      expect(reply['status'], 'applied');
    }

    final stored = await plans.readFor('student');
    expect(stored.plans.map((plan) => plan.name), ['First', 'Second', 'Third']);
    expect(changes, hasLength(3));
  });

  test('steps are shown and never block a change', () async {
    final result = await call('plan_steps', {
      'steps': ['Read the week', 'Add the reading group'],
    });
    expect(result['status'], 'shown');
    expect(steps.map((step) => step.text), [
      'Read the week',
      'Add the reading group',
    ]);
    expect(steps.any((step) => step.done), isFalse);

    await call('plan_steps', {
      'steps': ['Read the week', 'Add the reading group'],
      'done': '1',
    });
    expect(steps.first.done, isTrue);
    expect(steps.last.done, isFalse);

    await call('create_plan', {
      'title': 'Reading group',
      'location': 'Library',
      'start': '2026-11-23T09:00',
      'end': '2026-11-23T10:00',
    });
    expect((await plans.readFor('student')).plans, hasLength(1));
  });

  test('a write limit stops an unbounded turn', () async {
    for (var index = 0; index < 12; index++) {
      final result = await call('create_plan', {
        'title': 'Plan $index',
        'location': 'Library',
        'start': '2026-11-24T09:00',
        'end': '2026-11-24T10:00',
      });
      expect(result['status'], 'applied');
    }
    final blocked = await call('create_plan', {
      'title': 'Plan 13',
      'location': 'Library',
      'start': '2026-11-24T09:00',
      'end': '2026-11-24T10:00',
    });
    expect(blocked['error'], isNotNull);
    expect((await plans.readFor('student')).plans, hasLength(12));
  });
}
