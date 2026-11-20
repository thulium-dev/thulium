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
  PlanProposal? proposal;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    plans = PersonalPlanRepository();
    session = MemoryAuthSessionStore();
    await session.write(
      const AuthSession(userId: 'student', fingerprint: 'test', cookies: {}),
    );
    proposal = null;
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
      onProposal: (value) => proposal = value,
      onActivity: (_) {},
      isActive: () => true,
      loadSchedule: () async => (schedule: schedule, stale: false),
    );
  });

  tearDown(() => plans.dispose());

  Future<void> propose({
    String start = '2026-11-20T15:00',
    String end = '2026-11-20T16:00',
  }) async {
    final draft = agent.tools.singleWhere(
      (tool) => tool.name == 'propose_plan',
    );
    await draft.call({
      'title': 'Review physics',
      'location': 'Library',
      'start': start,
      'end': end,
    });
    expect(proposal, isNotNull);
  }

  test(
    'tool drafts without writing, confirmation saves and notifies once',
    () async {
      var changes = 0;
      plans.addListener(() => changes++);
      await propose();
      expect((await plans.readFor('student')).plans, isEmpty);
      expect(changes, 0);

      await agent.apply(proposal!);

      expect(
        (await plans.readFor('student')).plans.single.name,
        'Review physics',
      );
      expect((await plans.readFor('other')).plans, isEmpty);
      expect(changes, 1);
      await expectLater(agent.apply(proposal!), throwsStateError);
      expect(changes, 1);
    },
  );

  test(
    'confirmation rejects a slot that overlaps the course timetable',
    () async {
      await propose(start: '2026-11-20T14:00', end: '2026-11-20T15:00');

      await expectLater(agent.apply(proposal!), throwsA(isA<PlanConflict>()));

      expect((await plans.readFor('student')).plans, isEmpty);
    },
  );

  test('confirmation preserves a calendar edit made after drafting', () async {
    await propose();
    final current = await plans.readFor('student');
    await plans.save(
      'student',
      expected: current,
      next: current.copyWith(skipDeleteConfirmation: true),
    );

    await expectLater(agent.apply(proposal!), throwsStateError);

    final stored = await plans.readFor('student');
    expect(stored.skipDeleteConfirmation, isTrue);
    expect(stored.plans, isEmpty);
  });

  test(
    'moving a repeating plan changes only the selected occurrence',
    () async {
      final current = await plans.readFor('student');
      final rule = CustomPlan(
        id: 'weekly',
        name: 'Study session',
        location: 'Library',
        startsAt: DateTime(2026, 11, 20, 9),
        endsAt: DateTime(2026, 11, 20, 10),
        category: PlanCategories.LESSON,
        repeat: PlanRepeat.weekly,
      );
      await plans.save(
        'student',
        expected: current,
        next: current.copyWith(plans: [rule]),
      );
      final calendar = agent.tools.singleWhere(
        (tool) => tool.name == 'list_calendar',
      );
      final result = await calendar.call({
        'start': '2026-11-20',
        'end': '2026-11-21',
      });
      final entry = (result['entries'] as List).firstWhere(
        (entry) => entry['kind'] == 'personal',
      );
      final move = agent.tools.singleWhere(
        (tool) => tool.name == 'propose_plan_move',
      );
      await move.call({
        'reference': entry['edit_reference'],
        'start': '2026-11-20T10:00',
        'end': '2026-11-20T11:00',
      });
      await agent.apply(proposal!);

      final updated = await plans.readFor('student');
      final dates = updated.entriesBetween(
        const [],
        DateTime(2026, 11, 20),
        DateTime(2026, 11, 28),
      );
      expect(dates.map((entry) => entry.occurrence.startsAt), [
        DateTime(2026, 11, 20, 10),
        DateTime(2026, 11, 27, 9),
      ]);
    },
  );

  Tool<Object> tool(String name) =>
      agent.tools.singleWhere((item) => item.name == name);

  Future<Map<String, dynamic>> calendar(String start, String end) async {
    final result = await tool(
      'list_calendar',
    ).call({'start': start, 'end': end});
    return Map<String, dynamic>.from(result as Map);
  }

  test('creates a repeating plan and its new category in one draft', () async {
    final result = await tool('propose_plan').call({
      'title': 'Reading group',
      'location': 'Library',
      'start': '2026-11-21T09:00',
      'end': '2026-11-21T10:00',
      'category': 'Research',
      'category_color': '#1C9B86',
      'repeat': 'weekly',
    });
    expect(result['status'], 'awaiting_user_confirmation');
    expect(result['repeat'], 'weekly');
    expect(proposal!.rule!.repeat, PlanRepeat.weekly);
    expect(proposal!.category!.name, 'Research');

    await agent.apply(proposal!);

    final stored = await plans.readFor('student');
    expect(stored.plans.single.name, 'Reading group');
    expect(stored.plans.single.intervalDays, 1);
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

      await tool('propose_plan').call({
        'title': 'Lab meeting',
        'location': 'Lab',
        'start': '2026-11-21T09:00',
        'end': '2026-11-21T10:00',
        'category': 'research',
      });
      await agent.apply(proposal!);

      final stored = await plans.readFor('student');
      expect(stored.categories, hasLength(1));
      expect(stored.plans.single.category, 'user.existing');
    },
  );

  test('edits one occurrence and then the whole repeating rule', () async {
    final current = await plans.readFor('student');
    final rule = CustomPlan(
      id: 'weekly',
      name: 'Study session',
      location: 'Library',
      startsAt: DateTime(2026, 11, 21, 9),
      endsAt: DateTime(2026, 11, 21, 10),
      category: PlanCategories.LESSON,
      repeat: PlanRepeat.weekly,
    );
    await plans.save(
      'student',
      expected: current,
      next: current.copyWith(plans: [rule]),
    );
    final lists = await tool('list_plans').call({});
    final reference = (lists['plans'] as List).single['reference'];

    final once = await tool('propose_plan_update').call({
      'reference': reference,
      'scope': 'occurrence',
      'title': 'Study alone',
      'start': '2026-11-21T11:00',
      'end': '2026-11-21T12:00',
    });
    expect(once['title'], 'Study alone');
    expect(proposal!.series, isFalse);
    await agent.apply(proposal!);

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

    await tool('propose_plan_update').call({
      'reference': reference,
      'scope': 'series',
      'title': 'Study group',
      'repeat': 'interval_days',
      'interval_days': '3',
    });
    expect(proposal!.series, isTrue);
    await agent.apply(proposal!);

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

    await tool('propose_plan_remove').call({'reference': reference});
    expect(proposal!.kind, PlanChangeKind.cancel);
    await agent.apply(proposal!);

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
    await tool('propose_plan_remove').call({'reference': reference});
    expect(proposal!.kind, PlanChangeKind.delete);
    await agent.apply(proposal!);

    expect((await plans.readFor('student')).plans, isEmpty);
  });

  test('creates, renames, recolors, and deletes a category', () async {
    final created = await tool(
      'propose_category_create',
    ).call({'name': 'Research', 'color': '#1C9B86'});
    expect(created['category'], 'Research');
    await agent.apply(proposal!);

    var stored = await plans.readFor('student');
    expect(stored.categories.single.name, 'Research');

    final listed = await tool('list_categories').call({});
    final reference = (listed['categories'] as List).firstWhere(
      (item) => item['built_in'] == false,
    )['reference'];

    await tool(
      'propose_category_update',
    ).call({'reference': reference, 'name': 'Reading', 'color': '#E65C73'});
    await agent.apply(proposal!);

    stored = await plans.readFor('student');
    expect(stored.categories.single.name, 'Reading');
    expect(stored.categories.single.colorValue, 0xFFE65C73);

    await tool('propose_category_delete').call({'reference': reference});
    await agent.apply(proposal!);

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
    final listed = await tool('list_categories').call({});
    final reference = (listed['categories'] as List).firstWhere(
      (item) => item['usage'] == 1,
    )['reference'];

    final result = await tool(
      'propose_category_delete',
    ).call({'reference': reference});
    expect(result['error'], isNotNull);
    expect(proposal, isNull);

    await tool('propose_category_create').call({'name': 'Research'});
    expect(proposal, isNull, reason: 'Duplicate names are rejected.');
  });

  test('a stale entry reference cannot rewrite a newer edit', () async {
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
    final result = await calendar('2026-11-20', '2026-11-21');
    final reference = (result['entries'] as List).firstWhere(
      (entry) => entry['kind'] == 'personal',
    )['edit_reference'];

    // The user edits the plan in the calendar while the draft reference is held.
    final listed = await plans.readFor('student');
    await plans.save(
      'student',
      expected: listed,
      next: listed.replaceSeries(
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

    final moved = await tool('propose_plan_move').call({
      'reference': reference,
      'start': '2026-11-20T10:00',
      'end': '2026-11-20T11:00',
    });
    expect(moved['error'], isNotNull);
    expect(proposal, isNull);
  });

  test('rejects Lesson as a new category name', () async {
    final result = await tool(
      'propose_category_create',
    ).call({'name': 'lesson'});
    expect(result['error'], isNotNull);
    expect(proposal, isNull);
  });
}
