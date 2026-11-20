import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:thulium_auth/thulium_auth.dart';
import 'package:thulium_campus/thulium_campus.dart';

import '../auth/secure_course_schedule_cache_store.dart';
import '../plans/personal_plan_repository.dart';

enum AssistantActivity { calendar, assignments, plans, categories }

/// What one tool call changed in the stored calendar.
enum PlanChangeKind {
  create,
  update,
  move,
  cancel,
  delete,
  categoryCreate,
  categoryUpdate,
  categoryDelete,
}

/// One applied change, structured for the confirmation-free summary in the UI.
final class PlanChange {
  const PlanChange({
    required this.kind,
    this.title,
    this.start,
    this.end,
    this.location,
    this.categoryName,
    this.repeat,
    this.intervalDays,
    this.series = false,
  });

  final PlanChangeKind kind;
  final String? title;
  final DateTime? start;
  final DateTime? end;
  final String? location;
  final String? categoryName;
  final PlanRepeat? repeat;
  final int? intervalDays;
  final bool series;
}

/// One step of the model's own plan for this turn. Steps are presentation only;
/// they never gate a tool call.
final class PlanStep {
  const PlanStep({required this.text, this.done = false});

  final String text;
  final bool done;
}

/// Palette shared with the plan editor. Values are ARGB colors.
const _categoryPalette = <int>[
  0xFF6B5CE7,
  0xFFE65C73,
  0xFF1C9B86,
  0xFFDD8838,
  0xFF3988D4,
  0xFFAA63BD,
];

/// A model turn may inspect plenty of data, but writes stay bounded so one turn
/// cannot rewrite an entire term unattended.
const _maxCalls = 32;
const _maxWrites = 12;
const _maxWindowDays = 92;
const _maxEntries = 400;

/// Reads campus and local plan data and applies calendar changes directly.
///
/// Overlapping plans are allowed: the calendar lays them out side by side, so a
/// draft never fails because another entry occupies the same time. Writes are
/// still serialized through [PersonalPlanRepository] so a concurrent edit in the
/// calendar is never overwritten silently.
final class AssistantTools {
  AssistantTools({
    required this.account,
    required this.session,
    required this.plans,
    required this.homework,
    required this.onActivity,
    required this.isActive,
    this.onChanged,
    this.onSteps,
    this.loadSchedule,
  });

  final String account;
  final AuthSessionStore session;
  final PersonalPlanRepository plans;
  final Map<String, Object?> Function() homework;
  final void Function(AssistantActivity?) onActivity;
  final bool Function() isActive;
  final void Function(PlanChange)? onChanged;
  final void Function(List<PlanStep>)? onSteps;
  final Future<({CourseSchedule schedule, bool stale})> Function()?
  loadSchedule;
  final _entries = <String, CalendarPlanEntry>{};
  final _rules = <String, CustomPlan>{};
  final _categories = <String, CustomPlanCategory>{};
  int _calls = 0;
  int _writes = 0;

  List<Tool> get tools => [
    _tool(
      'plan_steps',
      'Show the user your ordered plan for this turn before acting. Send the '
          'full list again whenever progress changes, with done set to how many '
          'leading steps are finished. Steps never block tool calls.',
      {
        'steps': {
          'type': 'array',
          'items': _text('One short step.'),
          'description': 'Ordered steps, most important first.',
        },
        'done': _text('How many leading steps are finished.'),
      },
      const {'steps'},
      _steps,
    ),
    _tool(
      'list_calendar',
      'Read calendar entries for a range of at most $_maxWindowDays local days. '
          'Use YYYY-MM-DD dates; end is exclusive. Every entry exposes an '
          'edit_reference; personal rules also expose series_reference, repeat, '
          'and category. Overlapping entries are normal and all are returned.',
      {
        'start': _text('First local date, inclusive.'),
        'end': _text('Last local date, exclusive.'),
      },
      const {'start', 'end'},
      _calendar,
      activity: AssistantActivity.calendar,
    ),
    _tool(
      'list_plans',
      'Read every stored personal plan rule with its reference, category, and '
          'repeat so a series can be edited or deleted.',
      const {},
      const {},
      (_) => _listPlans(),
      activity: AssistantActivity.plans,
    ),
    _tool(
      'list_categories',
      'Read the plan categories available for assignment or editing. Lesson is '
          'built in and has no reference.',
      const {},
      const {},
      (_) => _listCategories(),
      activity: AssistantActivity.categories,
    ),
    _tool(
      'list_assignments',
      'Read upcoming unsubmitted assignments, their deadlines, and course '
          'titles. This snapshot does not contain assignment body text.',
      const {},
      const {},
      (_) async => homework(),
      activity: AssistantActivity.assignments,
    ),
    _tool(
      'create_plan',
      'Create a personal plan and save it immediately. Use local ISO date-times '
          'with minutes and no offset; start and end must be on the same day. '
          'category accepts an existing id or name from list_categories, or a '
          'new name that is created too. repeat is none, daily, weekly, or '
          'interval_days; interval_days defaults to 2. Overlaps are allowed.',
      {
        'title': _text('Plan title.'),
        'location': _text('Place shown on the calendar.'),
        'start': _text('Local ISO start date-time.'),
        'end': _text('Local ISO end date-time.'),
        'category': _text('Existing category id or name, or a new name.'),
        'repeat': _text('none, daily, weekly, or interval_days.'),
        'interval_days': _text('Repeat step in days when repeating.'),
        'category_color': _text(
          'Optional #RRGGBB for a newly created category.',
        ),
      },
      const {'title', 'location', 'start', 'end'},
      _create,
    ),
    _tool(
      'update_plan',
      'Edit one occurrence or the whole stored rule and save it immediately. '
          'Use the edit_reference from list_calendar or the reference from '
          'list_plans. Omit fields that should stay unchanged. Fetched lessons '
          'only accept occurrence scope.',
      {
        'reference': _text('Edit reference from list_calendar or list_plans.'),
        'scope': _text('occurrence or series.'),
        'title': _text('New title.'),
        'location': _text('New location.'),
        'start': _text('New local ISO start date-time.'),
        'end': _text('New local ISO end date-time.'),
        'category': _text('Existing category id or name, or a new name.'),
        'repeat': _text('none, daily, weekly, or interval_days.'),
        'interval_days': _text('Repeat step in days when repeating.'),
        'category_color': _text(
          'Optional #RRGGBB for a newly created category.',
        ),
      },
      const {'reference'},
      _update,
    ),
    _tool(
      'move_plan',
      'Move a single occurrence and save it immediately. Use its edit reference '
          'from list_calendar and local ISO start/end times with no offset. '
          'This never moves the whole series.',
      {
        'reference': _text('Edit reference from list_calendar.'),
        'start': _text('New local ISO start date-time.'),
        'end': _text('New local ISO end date-time.'),
      },
      const {'reference', 'start', 'end'},
      _move,
    ),
    _tool(
      'remove_plan',
      'Cancel one occurrence or delete a stored rule and save it immediately. '
          'scope is occurrence or series; repeating rules default to occurrence '
          'and single plans default to series. A fetched lesson can only be '
          'hidden locally.',
      {
        'reference': _text('Edit reference from list_calendar or list_plans.'),
        'scope': _text('occurrence or series.'),
      },
      const {'reference'},
      _remove,
    ),
    _tool(
      'create_category',
      'Create a plan category with a name and optional #RRGGBB color and save '
          'it immediately.',
      {
        'name': _text('Category name.'),
        'color': _text('Optional #RRGGBB color.'),
      },
      const {'name'},
      _createCategory,
    ),
    _tool(
      'update_category',
      'Rename or recolor a category and save it immediately. Use the reference '
          'from list_categories.',
      {
        'reference': _text('Category reference from list_categories.'),
        'name': _text('New category name.'),
        'color': _text('New #RRGGBB color.'),
      },
      const {'reference'},
      _updateCategory,
    ),
    _tool(
      'delete_category',
      'Delete an unused category and save it immediately. Reassign its plans '
          'before deleting it.',
      {'reference': _text('Category reference from list_categories.')},
      const {'reference'},
      _deleteCategory,
    ),
  ];

  Tool<Map<String, dynamic>> _tool(
    String name,
    String description,
    Map<String, Object> properties,
    Set<String> required,
    Future<Object> Function(Map<String, dynamic>) run, {
    AssistantActivity? activity,
  }) => Tool<Map<String, dynamic>>(
    name: name,
    description: description,
    inputSchema: Schema.fromMap({
      'type': 'object',
      'properties': properties,
      'required': required.toList(),
      'additionalProperties': false,
    }),
    onCall: (args) async {
      if (!isActive() || ++_calls > _maxCalls) {
        return {'error': 'Tool limit reached or turn stopped.'};
      }
      try {
        await _checkAccount();
        if (activity != null) onActivity(activity);
        final result = await run(args);
        await _checkAccount();
        return result;
      } on Object {
        return {
          'error':
              'The request could not be completed with the available campus data or arguments.',
        };
      } finally {
        if (activity != null && isActive()) onActivity(null);
      }
    },
  );

  Map<String, Object> _text(String description) => {
    'type': 'string',
    'description': description,
  };

  Future<void> _checkAccount() async {
    if ((await session.read())?.userId != account || !isActive()) {
      throw StateError('Assistant account or turn changed.');
    }
  }

  Future<Object> _steps(Map<String, dynamic> args) async {
    final raw = args['steps'];
    if (raw is! List || raw.isEmpty || raw.length > 12) {
      throw const FormatException('Expected between one and twelve steps.');
    }
    final texts = <String>[];
    for (final item in raw) {
      if (item is! String) throw const FormatException('Expected text steps.');
      final text = item.trim();
      if (text.isEmpty || text.length > 200) {
        throw const FormatException('Invalid step.');
      }
      texts.add(text);
    }
    final done = switch (_optional(args, 'done', max: 4)) {
      null => 0,
      final value => int.tryParse(value) ?? 0,
    };
    if (done < 0 || done > texts.length) {
      throw const FormatException('Invalid completed step count.');
    }
    onSteps?.call([
      for (var index = 0; index < texts.length; index++)
        PlanStep(text: texts[index], done: index < done),
    ]);
    return {'status': 'shown', 'steps': texts.length, 'done': done};
  }

  Future<({CourseSchedule schedule, bool stale})> _schedule() =>
      loadSchedule?.call() ??
      AuthSessionRunner(session)
          .run(
            expectedUserId: account,
            shouldReconnect: (error) =>
                error is CourseScheduleSessionExpired ||
                error is PortalSessionRejected ||
                error is PortalCsrfUnavailable ||
                (error is CourseScheduleException &&
                    (error.cause is PortalSessionRejected ||
                        error.cause is PortalCsrfUnavailable)),
            request: (client, retry) async {
              final service = CourseScheduleService(
                client,
                cache: CourseScheduleCache(SecureCourseScheduleCacheStore()),
              );
              final schedule = await service.loadCurrentTerm(
                forceRefresh: retry,
              );
              return (
                schedule: schedule,
                stale: service.lastSource == CourseScheduleSource.staleCache,
              );
            },
          )
          .timeout(const Duration(seconds: 30));

  /// Campus facts are optional for personal-plan operations. A failed or stale
  /// timetable is reported to the model but never blocks reading local plans.
  Future<({CourseSchedule schedule, bool stale})?> _optionalSchedule() async {
    try {
      return await _schedule();
    } on Object {
      return null;
    }
  }

  DateTime _date(Map<String, dynamic> args, String key, {required bool time}) {
    final raw = args[key];
    final pattern = time
        ? r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2})?$'
        : r'^\d{4}-\d{2}-\d{2}(T\d{2}:\d{2}(:\d{2})?)?$';
    if (raw is! String || !RegExp(pattern).hasMatch(raw)) {
      throw const FormatException('Expected a local ISO date or date-time.');
    }
    final date = DateTime.parse(raw);
    if (!date.toIso8601String().startsWith(raw)) {
      throw const FormatException('Invalid date.');
    }
    return date;
  }

  String? _optional(Map<String, dynamic> args, String key, {int max = 200}) {
    final raw = args[key];
    if (raw == null) return null;
    if (raw is! String) throw const FormatException('Expected text.');
    final value = raw.trim();
    if (value.isEmpty) return null;
    if (value.length > max) throw const FormatException('Text is too long.');
    return value;
  }

  String _required(Map<String, dynamic> args, String key, {int max = 200}) {
    final value = _optional(args, key, max: max);
    if (value == null) throw FormatException('Missing $key.');
    return value;
  }

  Future<Object> _listPlans() async {
    final collection = await plans.readFor(account);
    return {
      'plans': [
        for (final rule in collection.plans)
          {
            'reference': _registerRule(rule),
            'title': rule.name,
            'location': rule.location,
            'start': rule.startsAt.toIso8601String(),
            'end': rule.endsAt.toIso8601String(),
            'category': rule.category,
            'category_name': _categoryName(collection, rule.category),
            'repeat': rule.repeat.name,
            if (rule.repeat == PlanRepeat.intervalDays)
              'interval_days': rule.intervalDays,
          },
      ],
    };
  }

  Future<Object> _listCategories() async {
    final collection = await plans.readFor(account);
    int usage(String id) =>
        collection.plans.where((plan) => plan.category == id).length;
    return {
      'categories': [
        {
          'name': 'Lesson',
          'id': PlanCategories.LESSON,
          'built_in': true,
          'usage': usage(PlanCategories.LESSON),
        },
        for (final category in collection.categories)
          {
            'reference': _registerCategory(category),
            'name': category.name,
            'id': category.id,
            'color': _hex(category.colorValue),
            'built_in': false,
            'usage': usage(category.id),
          },
      ],
    };
  }

  Future<Object> _calendar(Map<String, dynamic> args) async {
    final start = _date(args, 'start', time: false);
    final end = _date(args, 'end', time: false);
    if (start != _dayStart(start) ||
        end != _dayStart(end) ||
        !end.isAfter(start) ||
        end.isAfter(_dayStart(start, offset: _maxWindowDays))) {
      throw const FormatException('Invalid date range.');
    }
    final timetable = await _optionalSchedule();
    final collection = await plans.readFor(account);
    final entries = collection.entriesBetween(
      timetable?.schedule.occurrences ?? const [],
      start,
      end,
    );
    return {
      'course_schedule_available': timetable != null,
      'course_schedule_stale': timetable?.stale,
      'truncated': entries.length > _maxEntries,
      'entries': [
        for (final entry in entries.take(_maxEntries))
          {
            'title': entry.occurrence.nameForLanguage('en'),
            'start': entry.occurrence.startsAt.toIso8601String(),
            'end': entry.occurrence.endsAt.toIso8601String(),
            'location': entry.occurrence.location,
            'kind': entry.fetchedLesson ? 'lesson' : 'personal',
            'category': entry.occurrence.category,
            'category_name': _categoryName(
              collection,
              entry.occurrence.category,
            ),
            'repeats': entry.repeats,
            'repeat': entry.rule?.repeat.name ?? PlanRepeat.none.name,
            'edit_reference': _registerEntry(entry),
            if (entry.rule case final rule?)
              'series_reference': _registerRule(rule),
          },
      ],
    };
  }

  String _registerEntry(CalendarPlanEntry entry) {
    for (final item in _entries.entries) {
      if (_sameOccurrence(item.value, entry) &&
          _sameFields(item.value.occurrence, entry.occurrence)) {
        return item.key;
      }
    }
    final key = 'entry-${_entries.length + 1}';
    _entries[key] = entry;
    return key;
  }

  String _registerRule(CustomPlan rule) {
    for (final item in _rules.entries) {
      if (item.value.id == rule.id) return item.key;
    }
    final key = 'plan-${_rules.length + 1}';
    _rules[key] = rule;
    return key;
  }

  String _registerCategory(CustomPlanCategory category) {
    for (final item in _categories.entries) {
      if (item.value.id == category.id) return item.key;
    }
    final key = 'category-${_categories.length + 1}';
    _categories[key] = category;
    return key;
  }

  String? _categoryName(CustomPlanCollection collection, String category) =>
      category == PlanCategories.LESSON
      ? null
      : collection.categories
            .where((item) => item.id == category)
            .map((item) => item.name)
            .firstOrNull;

  String _hex(int value) =>
      '#${(value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  int _color(String? raw) {
    if (raw == null) return _categoryPalette.first;
    final value = raw.replaceFirst('#', '').toUpperCase();
    if (!RegExp(r'^[0-9A-F]{6}$').hasMatch(value)) {
      throw const FormatException('Expected a #RRGGBB color.');
    }
    return 0xFF000000 | int.parse(value, radix: 16);
  }

  PlanRepeat _repeat(
    Map<String, dynamic> args, {
    PlanRepeat fallback = PlanRepeat.none,
  }) {
    final raw = _optional(args, 'repeat', max: 32)?.toLowerCase();
    if (raw == null) return fallback;
    return switch (raw) {
      'none' || 'never' => PlanRepeat.none,
      'daily' => PlanRepeat.daily,
      'weekly' => PlanRepeat.weekly,
      'interval_days' || 'interval' || 'days' => PlanRepeat.intervalDays,
      _ => throw const FormatException('Unknown repeat rule.'),
    };
  }

  int _intervalDays(
    Map<String, dynamic> args,
    PlanRepeat repeat, {
    int fallback = 2,
  }) {
    if (repeat != PlanRepeat.intervalDays) return 1;
    final raw = _optional(args, 'interval_days', max: 8);
    final days = raw == null ? fallback : int.tryParse(raw);
    if (days == null || days < 1 || days > 365) {
      throw const FormatException('Invalid interval.');
    }
    return days;
  }

  /// Category names stay unique and must not shadow the built-in Lesson.
  String _categoryLabel(
    String raw,
    CustomPlanCollection collection, {
    String? ignoreId,
  }) {
    final name = raw.trim();
    if (name.isEmpty || name.length > 60) {
      throw const FormatException('Invalid category name.');
    }
    if (name.toLowerCase() == PlanCategories.LESSON) {
      throw const FormatException('Lesson is a built-in category.');
    }
    if (collection.categories.any(
      (category) =>
          category.id != ignoreId &&
          category.name.toLowerCase() == name.toLowerCase(),
    )) {
      throw const FormatException('A category with this name already exists.');
    }
    return name;
  }

  /// Resolves an existing id or name, or prepares the category to create.
  ({String id, CustomPlanCategory? added}) _resolveCategory(
    Map<String, dynamic> args,
    CustomPlanCollection collection,
  ) {
    final raw = _optional(args, 'category', max: 60);
    if (raw == null || raw.toLowerCase() == PlanCategories.LESSON) {
      return (id: PlanCategories.LESSON, added: null);
    }
    for (final category in collection.categories) {
      if (category.id == raw ||
          category.name.toLowerCase() == raw.toLowerCase()) {
        return (id: category.id, added: null);
      }
    }
    final name = _categoryLabel(raw, collection);
    final category = CustomPlanCategory(
      id: 'user.${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      colorValue: _color(_optional(args, 'category_color', max: 9)),
    );
    return (id: category.id, added: category);
  }

  /// Resolves a `category` argument once so a new name creates exactly one
  /// category. Returns null when the argument is absent.
  ({String id, CustomPlanCategory? added})? _resolveCategoryArg(
    Map<String, dynamic> args,
    CustomPlanCollection collection,
  ) {
    if (!args.containsKey('category')) return null;
    return _resolveCategory(args, collection);
  }

  Future<Object> _create(Map<String, dynamic> args) async {
    final collection = await plans.readFor(account);
    final start = _date(args, 'start', time: true);
    final end = _date(args, 'end', time: true);
    _validateRange(start, end);
    final repeat = _repeat(args);
    final resolved = _resolveCategory(args, collection);
    final plan = CustomPlan(
      id: 'plan.${DateTime.now().microsecondsSinceEpoch}',
      name: _required(args, 'title'),
      location: _required(args, 'location'),
      startsAt: start,
      endsAt: end,
      category: resolved.id,
      repeat: repeat,
      intervalDays: _intervalDays(args, repeat),
    );
    return _commit(
      kind: PlanChangeKind.create,
      expected: collection,
      next: collection.copyWith(
        categories: [...collection.categories, ?resolved.added],
        plans: [...collection.plans, plan],
      ),
      after: _occurrence(plan),
      rule: plan,
      categoryName:
          resolved.added?.name ?? _categoryName(collection, plan.category),
    );
  }

  Future<Object> _update(Map<String, dynamic> args) async {
    final collection = await plans.readFor(account);
    final entry = await _requireEntry(args['reference'], collection);
    final series = _seriesScope(args, entry);
    final rule = entry.rule;
    if (series && rule == null) {
      throw const FormatException(
        'A fetched lesson can only be edited as one occurrence.',
      );
    }
    final hasStart = args.containsKey('start');
    final hasEnd = args.containsKey('end');
    if (hasStart != hasEnd) {
      throw const FormatException('Provide both start and end together.');
    }
    final start = hasStart ? _date(args, 'start', time: true) : null;
    final end = hasEnd ? _date(args, 'end', time: true) : null;
    if (start != null && end != null) _validateRange(start, end);
    // Resolve the category once: a new name must create exactly one category.
    final resolved = _resolveCategoryArg(args, collection);
    final title = _optional(args, 'title');
    final location = _optional(args, 'location');
    final categories = [...collection.categories, ?resolved?.added];
    final next = series
        ? CustomPlan(
            id: rule!.id,
            name: title ?? rule.name,
            location: location ?? rule.location,
            startsAt: start ?? rule.startsAt,
            endsAt: end ?? rule.endsAt,
            category: resolved?.id ?? rule.category,
            repeat: _repeat(args, fallback: rule.repeat),
            intervalDays: _intervalDays(
              args,
              _repeat(args, fallback: rule.repeat),
              fallback: rule.intervalDays,
            ),
          )
        : null;
    final after = next == null
        ? CourseOccurrence(
            name: title ?? entry.occurrence.name,
            location: location ?? entry.occurrence.location,
            startsAt: start ?? entry.occurrence.startsAt,
            endsAt: end ?? entry.occurrence.endsAt,
            category: resolved?.id ?? entry.occurrence.category,
          )
        : _occurrence(next);
    final updated = collection.copyWith(categories: categories);
    return _commit(
      kind: PlanChangeKind.update,
      expected: collection,
      next: next == null
          ? updated.replaceOccurrence(entry, after)
          : updated.replaceSeries(next),
      before: entry.occurrence,
      after: after,
      rule: next,
      series: series,
      categoryName:
          resolved?.added?.name ?? _categoryName(collection, after.category),
    );
  }

  Future<Object> _move(Map<String, dynamic> args) async {
    final collection = await plans.readFor(account);
    final entry = await _requireEntry(args['reference'], collection);
    final start = _date(args, 'start', time: true);
    final end = _date(args, 'end', time: true);
    _validateRange(start, end);
    final after = CourseOccurrence(
      name: entry.occurrence.name,
      location: entry.occurrence.location,
      startsAt: start,
      endsAt: end,
      category: entry.occurrence.category,
    );
    return _commit(
      kind: PlanChangeKind.move,
      expected: collection,
      next: collection.replaceOccurrence(entry, after),
      before: entry.occurrence,
      after: after,
      rule: entry.rule,
      categoryName: _categoryName(collection, after.category),
    );
  }

  Future<Object> _remove(Map<String, dynamic> args) async {
    final collection = await plans.readFor(account);
    final entry = await _requireEntry(args['reference'], collection);
    final series = _seriesScope(args, entry);
    final deleting = series && entry.rule != null;
    return _commit(
      kind: deleting ? PlanChangeKind.delete : PlanChangeKind.cancel,
      expected: collection,
      next: deleting
          ? collection.deleteSeries(entry)
          : collection.replaceOccurrence(entry, null),
      before: entry.occurrence,
      series: deleting,
      categoryName: _categoryName(collection, entry.occurrence.category),
    );
  }

  Future<Object> _createCategory(Map<String, dynamic> args) async {
    final collection = await plans.readFor(account);
    final name = _categoryLabel(_required(args, 'name', max: 60), collection);
    final category = CustomPlanCategory(
      id: 'user.${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      colorValue: _color(_optional(args, 'color', max: 9)),
    );
    return _commit(
      kind: PlanChangeKind.categoryCreate,
      expected: collection,
      next: collection.copyWith(
        categories: [...collection.categories, category],
      ),
      category: category,
      categoryName: name,
    );
  }

  Future<Object> _updateCategory(Map<String, dynamic> args) async {
    final collection = await plans.readFor(account);
    final category = await _requireCategory(args['reference']);
    final name = args.containsKey('name')
        ? _categoryLabel(
            _required(args, 'name', max: 60),
            collection,
            ignoreId: category.id,
          )
        : category.name;
    final updated = CustomPlanCategory(
      id: category.id,
      name: name,
      colorValue: args.containsKey('color')
          ? _color(_required(args, 'color', max: 9))
          : category.colorValue,
    );
    return _commit(
      kind: PlanChangeKind.categoryUpdate,
      expected: collection,
      next: collection.copyWith(
        categories: [
          for (final item in collection.categories)
            item.id == updated.id ? updated : item,
        ],
      ),
      category: updated,
      categoryName: updated.name,
    );
  }

  Future<Object> _deleteCategory(Map<String, dynamic> args) async {
    final collection = await plans.readFor(account);
    final category = await _requireCategory(args['reference']);
    if (collection.plans.any((plan) => plan.category == category.id)) {
      throw const FormatException(
        'Reassign plans in this category before deleting it.',
      );
    }
    return _commit(
      kind: PlanChangeKind.categoryDelete,
      expected: collection,
      next: collection.copyWith(
        categories: [
          for (final item in collection.categories)
            if (item.id != category.id) item,
        ],
      ),
      category: category,
      categoryName: category.name,
    );
  }

  Future<CustomPlanCategory> _requireCategory(String? reference) async {
    final category = reference == null ? null : _categories[reference];
    if (category == null) {
      throw StateError('Select a category with list_categories first.');
    }
    final collection = await plans.readFor(account);
    if (!collection.categories.any((item) => item.id == category.id)) {
      throw StateError('That category no longer exists.');
    }
    return category;
  }

  /// Resolves a reference and confirms the entry still describes the same
  /// visible occurrence, so a stale reference cannot rewrite a newer edit. A
  /// rule reference resolves to that rule's first stored occurrence.
  Future<CalendarPlanEntry> _requireEntry(
    String? reference,
    CustomPlanCollection collection,
  ) async {
    final stored = reference == null ? null : _entries[reference];
    final ruleReference = reference == null ? null : _rules[reference];
    if (reference == null || (stored == null && ruleReference == null)) {
      throw StateError('Select an entry with list_calendar or list_plans.');
    }
    if (stored == null) {
      final rule = collection.plans
          .where((plan) => plan.id == ruleReference!.id)
          .firstOrNull;
      if (rule == null) {
        throw StateError('That plan rule changed or no longer exists.');
      }
      return CalendarPlanEntry(
        occurrence: _occurrence(rule),
        sourceId: rule.id,
        originalStartsAt: rule.startsAt,
        fetchedLesson: false,
        rule: rule,
      );
    }
    final timetable = await _optionalSchedule();
    final start = _dayStart(stored.occurrence.startsAt);
    final current = collection
        .entriesBetween(
          timetable?.schedule.occurrences ?? const [],
          start,
          _dayStart(start, offset: 1),
        )
        .where(
          (entry) =>
              _sameOccurrence(entry, stored) &&
              _sameFields(entry.occurrence, stored.occurrence),
        )
        .firstOrNull;
    if (current == null) {
      throw StateError('That calendar entry changed or no longer exists.');
    }
    return current;
  }

  /// Defaults to one occurrence for repeating rules and the whole rule for a
  /// single plan, matching the calendar's own scope default.
  bool _seriesScope(Map<String, dynamic> args, CalendarPlanEntry entry) {
    final raw = _optional(args, 'scope', max: 16)?.toLowerCase();
    return switch (raw) {
      null => entry.rule != null && entry.rule!.repeat == PlanRepeat.none,
      'occurrence' || 'one' || 'single' => false,
      'series' || 'all' || 'rule' => true,
      _ => throw const FormatException('Unknown scope.'),
    };
  }

  void _validateRange(DateTime start, DateTime end) {
    if (!end.isAfter(start) ||
        start.year != end.year ||
        start.month != end.month ||
        start.day != end.day) {
      throw const FormatException('A plan must end later on its starting day.');
    }
  }

  CourseOccurrence _occurrence(CustomPlan plan) => CourseOccurrence(
    name: plan.name,
    location: plan.location,
    startsAt: plan.startsAt,
    endsAt: plan.endsAt,
    category: plan.category,
  );

  /// Saves one change immediately and reports it to the UI summary.
  Future<Object> _commit({
    required PlanChangeKind kind,
    required CustomPlanCollection expected,
    required CustomPlanCollection next,
    CourseOccurrence? before,
    CourseOccurrence? after,
    CustomPlan? rule,
    CustomPlanCategory? category,
    String? categoryName,
    bool series = false,
  }) async {
    await _checkAccount();
    if (++_writes > _maxWrites) {
      return {'error': 'Change limit reached for this turn.'};
    }
    await plans.save(
      account,
      expected: expected,
      next: next,
      validate: _checkAccount,
    );
    final change = PlanChange(
      kind: kind,
      title: after?.name ?? before?.name ?? category?.name,
      start: after?.startsAt,
      end: after?.endsAt,
      location: after?.location,
      categoryName: categoryName,
      repeat: rule?.repeat,
      intervalDays: rule?.repeat == PlanRepeat.intervalDays
          ? rule!.intervalDays
          : null,
      series: series,
    );
    onChanged?.call(change);
    return {
      'status': 'applied',
      'change': kind.name,
      if (after != null) ...{
        'title': after.name,
        'start': after.startsAt.toIso8601String(),
        'end': after.endsAt.toIso8601String(),
        'location': after.location,
      },
      'category': ?categoryName,
      if (rule != null) ...{
        'repeat': _repeatName(rule.repeat),
        if (rule.repeat == PlanRepeat.intervalDays)
          'interval_days': rule.intervalDays.toString(),
      },
      if (series) 'scope': 'series',
      'remaining_changes': _maxWrites - _writes,
    };
  }

  /// Tool arguments use snake case, so echoing the same spelling avoids
  /// surprising the model with Dart enum names.
  String _repeatName(PlanRepeat repeat) => switch (repeat) {
    PlanRepeat.none => 'none',
    PlanRepeat.daily => 'daily',
    PlanRepeat.weekly => 'weekly',
    PlanRepeat.intervalDays => 'interval_days',
  };

  DateTime _dayStart(DateTime date, {int offset = 0}) =>
      DateTime(date.year, date.month, date.day + offset);

  bool _sameOccurrence(CalendarPlanEntry a, CalendarPlanEntry b) =>
      a.sourceId == b.sourceId && a.originalStartsAt == b.originalStartsAt;

  bool _sameFields(CourseOccurrence a, CourseOccurrence b) =>
      a.name == b.name &&
      a.location == b.location &&
      a.startsAt == b.startsAt &&
      a.endsAt == b.endsAt &&
      a.category == b.category;
}
