part of '../thulium_campus.dart';

/// How a user-created plan repeats after its first calendar date.
enum PlanRepeat { none, daily, weekly, intervalDays }

/// A user-owned plan category; [colorValue] is an ARGB color value.
final class CustomPlanCategory {
  const CustomPlanCategory({
    required this.id,
    required this.name,
    required this.colorValue,
  });

  final String id;
  final String name;
  final int colorValue;

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'colorValue': colorValue,
  };

  factory CustomPlanCategory.fromJson(Map<String, dynamic> json) =>
      CustomPlanCategory(
        id: json['id'] as String,
        name: json['name'] as String,
        colorValue: json['colorValue'] as int,
      );
}

/// One local plan rule, stored independently from fetched teaching-calendar data.
///
/// The first start and end must be on the same civil day. Repeating rules
/// preserve local wall-clock time across daylight-saving changes.
final class CustomPlan {
  CustomPlan({
    required this.id,
    required this.name,
    required this.location,
    required this.startsAt,
    required this.endsAt,
    required this.category,
    required this.repeat,
    this.intervalDays = 1,
  }) {
    if (name.trim().isEmpty || location.trim().isEmpty) {
      throw ArgumentError('Plan name and location are required.');
    }
    if (!endsAt.isAfter(startsAt) ||
        startsAt.year != endsAt.year ||
        startsAt.month != endsAt.month ||
        startsAt.day != endsAt.day) {
      throw ArgumentError('A plan must end later on its starting day.');
    }
    if (intervalDays < 1) {
      throw ArgumentError.value(intervalDays, 'intervalDays');
    }
  }

  final String id;
  final String name;
  final String location;
  final DateTime startsAt;
  final DateTime endsAt;
  final String category;
  final PlanRepeat repeat;
  final int intervalDays;

  /// Expands only the requested half-open date range, so infinite rules do
  /// not create an unbounded list of occurrences or enlarge the cache.
  Iterable<CourseOccurrence> occurrencesBetween(
    DateTime start,
    DateTime end,
  ) sync* {
    if (!end.isAfter(start)) return;
    final firstDay = DateTime(startsAt.year, startsAt.month, startsAt.day);
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    final step = switch (repeat) {
      PlanRepeat.none => 0,
      PlanRepeat.daily => 1,
      PlanRepeat.weekly => 7,
      PlanRepeat.intervalDays => intervalDays,
    };
    if (step == 0) {
      if (!startsAt.isBefore(start) && startsAt.isBefore(end)) {
        yield _occurrence(startsAt, endsAt);
      }
      return;
    }
    // Civil-date arithmetic avoids counting 23- or 25-hour days as a
    // different number of recurrence days at a DST boundary.
    final elapsedDays =
        DateTime.utc(startDay.year, startDay.month, startDay.day)
            .difference(
              DateTime.utc(firstDay.year, firstDay.month, firstDay.day),
            )
            .inDays;
    var index = elapsedDays <= 0 ? 0 : (elapsedDays + step - 1) ~/ step;
    while (true) {
      final day = DateTime(
        firstDay.year,
        firstDay.month,
        firstDay.day + index * step,
      );
      if (!day.isBefore(endDay)) break;
      final occurrenceStart = DateTime(
        day.year,
        day.month,
        day.day,
        startsAt.hour,
        startsAt.minute,
      );
      final occurrenceEnd = DateTime(
        day.year,
        day.month,
        day.day,
        endsAt.hour,
        endsAt.minute,
      );
      if (!occurrenceStart.isBefore(start) && occurrenceStart.isBefore(end)) {
        yield _occurrence(occurrenceStart, occurrenceEnd);
      }
      index++;
    }
  }

  CourseOccurrence _occurrence(DateTime start, DateTime end) =>
      CourseOccurrence(
        name: name,
        location: location,
        startsAt: start,
        endsAt: end,
        category: category,
      );

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'location': location,
    'startsAt': startsAt.toIso8601String(),
    'endsAt': endsAt.toIso8601String(),
    'category': category,
    'repeat': repeat.name,
    'intervalDays': intervalDays,
  };

  factory CustomPlan.fromJson(Map<String, dynamic> json) => CustomPlan(
    id: json['id'] as String,
    name: json['name'] as String,
    location: json['location'] as String,
    startsAt: DateTime.parse(json['startsAt'] as String),
    endsAt: DateTime.parse(json['endsAt'] as String),
    category: json['category'] as String,
    repeat: PlanRepeat.values.byName(json['repeat'] as String),
    intervalDays: json['intervalDays'] as int,
  );
}

/// Identifies the original occurrence even after a one-off edit moves it.
final class CalendarPlanEntry {
  const CalendarPlanEntry({
    required this.occurrence,
    required this.sourceId,
    required this.originalStartsAt,
    required this.fetchedLesson,
    this.rule,
  });

  final CourseOccurrence occurrence;
  final String sourceId;
  final DateTime originalStartsAt;
  final bool fetchedLesson;
  final CustomPlan? rule;

  bool get repeats => rule != null && rule!.repeat != PlanRepeat.none;
}

/// A local replacement or cancellation of exactly one dated occurrence.
final class PlanOccurrenceOverride {
  const PlanOccurrenceOverride({
    required this.sourceId,
    required this.originalStartsAt,
    this.replacement,
  });

  final String sourceId;
  final DateTime originalStartsAt;
  final CourseOccurrence? replacement;

  Map<String, Object?> toJson() => {
    'sourceId': sourceId,
    'originalStartsAt': originalStartsAt.toIso8601String(),
    'replacement': replacement == null ? null : _encodeOccurrence(replacement!),
  };

  factory PlanOccurrenceOverride.fromJson(Map<String, dynamic> json) =>
      PlanOccurrenceOverride(
        sourceId: json['sourceId'] as String,
        originalStartsAt: DateTime.parse(json['originalStartsAt'] as String),
        replacement: json['replacement'] == null
            ? null
            : _decodeOccurrence(
                Map<String, dynamic>.from(json['replacement'] as Map),
              ),
      );
}

Map<String, Object> _encodeOccurrence(CourseOccurrence occurrence) => {
  'name': occurrence.name,
  'location': occurrence.location,
  'startsAt': occurrence.startsAt.toIso8601String(),
  'endsAt': occurrence.endsAt.toIso8601String(),
  'category': occurrence.category,
};

CourseOccurrence _decodeOccurrence(Map<String, dynamic> json) =>
    CourseOccurrence(
      name: json['name'] as String,
      location: json['location'] as String,
      startsAt: DateTime.parse(json['startsAt'] as String),
      endsAt: DateTime.parse(json['endsAt'] as String),
      category: json['category'] as String,
    );

/// Fetched lessons have no server rule ID, so their original fields identify
/// the local override without altering or writing back to the school server.
String fetchedLessonSourceId(CourseOccurrence lesson) =>
    'lesson:${jsonEncode(_encodeOccurrence(lesson))}';

/// Versioned, account-scoped payload for custom categories and rules.
final class CustomPlanCollection {
  CustomPlanCollection({
    required List<CustomPlanCategory> categories,
    required List<CustomPlan> plans,
    List<PlanOccurrenceOverride> overrides = const [],
    this.skipDeleteConfirmation = false,
    this.skipCancelConfirmation = false,
  }) : categories = List.unmodifiable(categories),
       plans = List.unmodifiable(plans),
       overrides = List.unmodifiable(overrides);

  factory CustomPlanCollection.empty() =>
      CustomPlanCollection(categories: [], plans: []);

  final List<CustomPlanCategory> categories;
  final List<CustomPlan> plans;
  final List<PlanOccurrenceOverride> overrides;
  final bool skipDeleteConfirmation;
  final bool skipCancelConfirmation;

  /// Applies single-occurrence overrides after expanding rules for one week.
  /// Moved replacements are included even if their original date was outside
  /// this week, avoiding an invisible event after a date change.
  List<CalendarPlanEntry> entriesForWeek(
    List<CourseOccurrence> fetchedLessons,
    DateTime start,
    DateTime end,
  ) {
    final changes = {
      for (final override in overrides)
        (override.sourceId, override.originalStartsAt): override,
    };
    final entries = <CalendarPlanEntry>[];
    final rulesById = {for (final rule in plans) rule.id: rule};

    void addOriginal(
      CourseOccurrence occurrence,
      String sourceId,
      CustomPlan? rule,
      bool fetchedLesson,
    ) {
      final override = changes[(sourceId, occurrence.startsAt)];
      if (override != null && override.replacement == null) return;
      final visible = override?.replacement ?? occurrence;
      if (!visible.startsAt.isBefore(start) && visible.startsAt.isBefore(end)) {
        entries.add(
          CalendarPlanEntry(
            occurrence: visible,
            sourceId: sourceId,
            originalStartsAt: occurrence.startsAt,
            fetchedLesson: fetchedLesson,
            rule: rule,
          ),
        );
      }
    }

    for (final lesson in fetchedLessons) {
      if (!lesson.startsAt.isBefore(start) && lesson.startsAt.isBefore(end)) {
        addOriginal(lesson, fetchedLessonSourceId(lesson), null, true);
      }
    }
    for (final rule in plans) {
      for (final occurrence in rule.occurrencesBetween(start, end)) {
        addOriginal(occurrence, rule.id, rule, false);
      }
    }
    for (final override in overrides) {
      final replacement = override.replacement;
      if (replacement == null ||
          replacement.startsAt.isBefore(start) ||
          !replacement.startsAt.isBefore(end) ||
          (!override.originalStartsAt.isBefore(start) &&
              override.originalStartsAt.isBefore(end))) {
        continue;
      }
      final rule = rulesById[override.sourceId];
      entries.add(
        CalendarPlanEntry(
          occurrence: replacement,
          sourceId: override.sourceId,
          originalStartsAt: override.originalStartsAt,
          fetchedLesson: rule == null,
          rule: rule,
        ),
      );
    }
    entries.sort(
      (a, b) => a.occurrence.startsAt.compareTo(b.occurrence.startsAt),
    );
    return entries;
  }

  CustomPlanCollection copyWith({
    List<CustomPlanCategory>? categories,
    List<CustomPlan>? plans,
    List<PlanOccurrenceOverride>? overrides,
    bool? skipDeleteConfirmation,
    bool? skipCancelConfirmation,
  }) => CustomPlanCollection(
    categories: categories ?? this.categories,
    plans: plans ?? this.plans,
    overrides: overrides ?? this.overrides,
    skipDeleteConfirmation:
        skipDeleteConfirmation ?? this.skipDeleteConfirmation,
    skipCancelConfirmation:
        skipCancelConfirmation ?? this.skipCancelConfirmation,
  );

  CustomPlanCollection replaceOccurrence(
    CalendarPlanEntry entry,
    CourseOccurrence? replacement,
  ) => copyWith(
    overrides: [
      for (final override in overrides)
        if (override.sourceId != entry.sourceId ||
            override.originalStartsAt != entry.originalStartsAt)
          override,
      PlanOccurrenceOverride(
        sourceId: entry.sourceId,
        originalStartsAt: entry.originalStartsAt,
        replacement: replacement,
      ),
    ],
  );

  CustomPlanCollection replaceSeries(CustomPlan updated) {
    final previous = plans.where((plan) => plan.id == updated.id).firstOrNull;
    if (previous == null) {
      throw ArgumentError.value(updated.id, 'updated.id', 'Unknown plan rule.');
    }
    final sameSchedule =
        previous.startsAt == updated.startsAt &&
        previous.endsAt == updated.endsAt &&
        previous.repeat == updated.repeat &&
        previous.intervalDays == updated.intervalDays;
    return copyWith(
      plans: [for (final plan in plans) plan.id == updated.id ? updated : plan],
      // Keep one-off exceptions when only metadata changed. A time or repeat
      // change shifts original occurrence keys, so old exceptions cannot be
      // applied reliably and are removed with the replaced schedule.
      overrides: [
        for (final override in overrides)
          if (sameSchedule || override.sourceId != updated.id) override,
      ],
    );
  }

  CustomPlanCollection deleteSeries(CalendarPlanEntry entry) {
    if (entry.rule == null) return replaceOccurrence(entry, null);
    return copyWith(
      plans: [
        for (final plan in plans)
          if (plan.id != entry.sourceId) plan,
      ],
      overrides: [
        for (final override in overrides)
          if (override.sourceId != entry.sourceId) override,
      ],
    );
  }

  String encode() => jsonEncode({
    'version': 2,
    'categories': [for (final category in categories) category.toJson()],
    'plans': [for (final plan in plans) plan.toJson()],
    'overrides': [for (final override in overrides) override.toJson()],
    'skipDeleteConfirmation': skipDeleteConfirmation,
    'skipCancelConfirmation': skipCancelConfirmation,
  });

  factory CustomPlanCollection.decode(String value) {
    final json = jsonDecode(value) as Map<String, dynamic>;
    if (json['version'] != 1 && json['version'] != 2) {
      throw const FormatException('Unsupported custom-plan version.');
    }
    final categories = [
      for (final value in json['categories'] as List)
        CustomPlanCategory.fromJson(Map<String, dynamic>.from(value as Map)),
    ];
    final plans = [
      for (final value in json['plans'] as List)
        CustomPlan.fromJson(Map<String, dynamic>.from(value as Map)),
    ];
    // Version one offered a built-in Personal category. Preserve only accounts
    // that actually used it; new accounts still start with Lesson alone.
    if (json['version'] == 1 &&
        plans.any((plan) => plan.category == 'personal') &&
        !categories.any((category) => category.id == 'personal')) {
      categories.add(
        const CustomPlanCategory(
          id: 'personal',
          name: 'Personal',
          colorValue: 0xFF6B5CE7,
        ),
      );
    }
    return CustomPlanCollection(
      categories: categories,
      plans: plans,
      overrides: [
        for (final value in (json['overrides'] as List? ?? []))
          PlanOccurrenceOverride.fromJson(
            Map<String, dynamic>.from(value as Map),
          ),
      ],
      skipDeleteConfirmation: json['skipDeleteConfirmation'] == true,
      skipCancelConfirmation: json['skipCancelConfirmation'] == true,
    );
  }
}
