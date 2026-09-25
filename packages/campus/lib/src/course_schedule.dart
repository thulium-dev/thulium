part of '../thulium_campus.dart';

const _LEARN_ROAMING_ID = '3E401364BDD7AEA7EBF1EDE3F15ED4B7';
const _UNDERGRADUATE_ACADEMIC_CALENDAR_ROAMING_ID =
    '287C0C6D90ABB364CD5FDF1495199962';
const _GRADUATE_ACADEMIC_CALENDAR_ROAMING_ID =
    'BEABB32641DC4EC3510B048BAF42471A';
const _SEMESTER_LIST_URL =
    '${TsinghuaWebVpnRedirect.WEBVPN_BASE_URL}'
    '${TsinghuaWebVpnRedirect.LEARNING_PLATFORM_REDIRECT_PATH}'
    'b/kc/zhjw_v_code_xnxq/getCurrentAndNextSemester?_csrf=';
const _UNDERGRADUATE_PRIMARY_URL =
    '${TsinghuaWebVpnRedirect.ACADEMIC_CALENDAR_BASE_URL}/jxmh_out.do';
const _GRADUATE_PRIMARY_URL =
    '${TsinghuaWebVpnRedirect.ACADEMIC_CALENDAR_BASE_URL}/jxmh_out.do';
const _SECONDARY_SCHEDULE_URL =
    '${TsinghuaWebVpnRedirect.ACADEMIC_CALENDAR_BASE_URL}'
    '/portal3rd.do?m=bks_ejkbSearch';
const _REQUEST_GROUP_WEEKS = 3;
const _SCHEDULE_CACHE_MAX_AGE = Duration(hours: 24);
const _BEGIN_TIMES = <String>[
  '',
  '08:00',
  '09:50',
  '13:30',
  '15:20',
  '17:05',
  '19:20',
];
const _END_TIMES = <String>[
  '',
  '09:35',
  '12:15',
  '15:05',
  '16:55',
  '18:40',
  '21:45',
];

/// The teaching term used to calculate calendar weeks.
final class AcademicTerm {
  const AcademicTerm({
    required this.id,
    required this.name,
    required this.firstMonday,
    required this.weekCount,
  });

  final String id;
  final String name;
  final DateTime firstMonday;
  final int weekCount;

  int weekFor(DateTime date) => date.difference(firstMonday).inDays ~/ 7 + 1;
}

/// Stable category identifiers for plans supplied by Thulium.
///
/// Category identifiers remain strings so future user-created plans can
/// introduce their own categories without changing this shared data model.
abstract final class PlanCategories {
  static const LESSON = 'lesson';
}

/// One dated occurrence of a course, rather than an unexpanded weekly rule.
final class CourseOccurrence {
  const CourseOccurrence({
    required this.name,
    required this.location,
    required this.startsAt,
    required this.endsAt,
    required this.category,
  });

  final String name;
  final String location;
  final DateTime startsAt;
  final DateTime endsAt;
  final String category;
}

/// A term and its combined actual-date course occurrences.
final class CourseSchedule {
  CourseSchedule({
    required this.term,
    required List<CourseOccurrence> occurrences,
  }) : occurrences = List.unmodifiable(_mergeAdjacentLessons(occurrences));

  final AcademicTerm term;
  final List<CourseOccurrence> occurrences;

  /// Normalizes dated lesson blocks before any UI or cache consumer sees them.
  ///
  /// Grouping by exact name, location, category, and civil date allows rows
  /// from separate API sources to merge even when they arrive out of order.
  /// Custom plan categories are intentionally left untouched.
  static List<CourseOccurrence> _mergeAdjacentLessons(
    List<CourseOccurrence> occurrences,
  ) {
    final groups =
        <(String, String, String, int, int, int), List<CourseOccurrence>>{};
    for (final occurrence in occurrences) {
      final date = occurrence.startsAt;
      final key = (
        occurrence.category,
        occurrence.name,
        occurrence.location,
        date.year,
        date.month,
        date.day,
      );
      groups.putIfAbsent(key, () => []).add(occurrence);
    }

    final merged = <CourseOccurrence>[];
    for (final group in groups.values) {
      group.sort((a, b) => a.startsAt.compareTo(b.startsAt));
      var current = group.first;
      for (final next in group.skip(1)) {
        final gap = next.startsAt.difference(current.endsAt);
        if (current.category == PlanCategories.LESSON &&
            !gap.isNegative &&
            gap <= const Duration(minutes: 15)) {
          current = CourseOccurrence(
            name: current.name,
            location: current.location,
            startsAt: current.startsAt,
            endsAt: next.endsAt,
            category: current.category,
          );
        } else {
          merged.add(current);
          current = next;
        }
      }
      merged.add(current);
    }
    merged.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return merged;
  }
}

/// Thrown when portal access is still valid but schedule data cannot be read.
final class CourseScheduleException implements Exception {
  const CourseScheduleException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'CourseScheduleException: $message';
}

/// Thrown after a protected schedule request proves the saved session expired.
final class CourseScheduleSessionExpired implements Exception {
  const CourseScheduleSessionExpired();
}

/// Indicates whether the last calendar result came from the server or cache.
enum CourseScheduleSource { network, freshCache, staleCache }

/// Loads the academic term plus primary and secondary course occurrences.
///
/// The service deliberately uses the shared auth client's cookie jar and
/// roaming implementation. Primary-calendar rows are already date-specific;
/// secondary-course week rules are expanded into dated occurrences here.
final class CourseScheduleService {
  CourseScheduleService(this._authClient, {this.cache, this.trace, this.now});

  final TsinghuaAuthClient _authClient;

  /// Optional persistent snapshot. Cache reads and writes never contain auth.
  final CourseScheduleCache? cache;

  /// Optional stage diagnostics. No account, cookie, or response body is sent.
  final void Function(String message)? trace;

  /// Injectable clock keeps cache expiry deterministic in tests.
  final DateTime Function()? now;

  /// Identifies whether the most recent result was fetched or cached.
  CourseScheduleSource? lastSource;

  /// Fetches current-term metadata and combines all available course sources.
  Future<CourseSchedule> loadCurrentTerm({bool forceRefresh = false}) async {
    lastSource = null;
    if (_authClient.session == null && await _authClient.restore() == null) {
      throw const CourseScheduleSessionExpired();
    }

    final userId = _authClient.session!.userId;
    final currentTime = (now ?? DateTime.now)();
    CachedCourseSchedule? cached;
    try {
      cached = await cache?.readFor(userId);
    } on Exception catch (error) {
      trace?.call('Calendar cache read failed type=${error.runtimeType}');
    }
    if (cached != null && !cached.isRelevant(currentTime)) {
      trace?.call('Calendar cache belongs to an ended term');
      cached = null;
    }
    if (!forceRefresh &&
        cached != null &&
        cached.isFresh(currentTime, _SCHEDULE_CACHE_MAX_AGE)) {
      trace?.call(
        'Calendar cache hit ageHours=${currentTime.difference(cached.fetchedAt).inHours}',
      );
      lastSource = CourseScheduleSource.freshCache;
      return cached.schedule;
    }

    try {
      final schedule = await _fetchCurrentTerm();
      try {
        await cache?.writeFor(userId, schedule, (now ?? DateTime.now)());
      } on Exception catch (error) {
        trace?.call('Calendar cache write failed type=${error.runtimeType}');
      }
      lastSource = CourseScheduleSource.network;
      return schedule;
    } on Exception catch (error) {
      if (cached == null || forceRefresh) rethrow;
      trace?.call('Calendar using stale cache after ${error.runtimeType}');
      lastSource = CourseScheduleSource.staleCache;
      return cached.schedule;
    }
  }

  Future<CourseSchedule> _fetchCurrentTerm() async {
    var stage = 'roaming to the learning platform';
    try {
      trace?.call('Calendar stage=$stage');
      final landingPage = await _authClient.roamToPortalApp(_LEARN_ROAMING_ID);
      late final String csrf;
      try {
        _ensurePortalResponse(landingPage.body, landingPage.statusCode);
        csrf = _readCsrf(landingPage.body);
      } catch (_) {
        _authClient.traceUnexpectedResponse('learning-landing', landingPage);
        rethrow;
      }
      stage = 'fetching the current academic term';
      trace?.call('Calendar stage=$stage');
      final semesterResponse = await _authClient.getAuthenticated(
        Uri.parse('$_SEMESTER_LIST_URL${Uri.encodeQueryComponent(csrf)}'),
      );
      Object? semesterJson;
      try {
        _ensurePortalResponse(
          semesterResponse.body,
          semesterResponse.statusCode,
        );
        semesterJson = jsonDecode(semesterResponse.body);
      } catch (_) {
        _authClient.traceUnexpectedResponse('semester-list', semesterResponse);
        rethrow;
      }
      if (semesterJson is! Map<String, dynamic> ||
          semesterJson['message'] != 'success' ||
          semesterJson['result'] is! Map) {
        _authClient.traceUnexpectedResponse('semester-list', semesterResponse);
        throw const CourseScheduleException(
          'The academic calendar returned an unexpected response.',
        );
      }
      final term = _parseTerm(
        Map<String, dynamic>.from(semesterJson['result'] as Map),
      );

      final userId = _authClient.session!.userId;
      final isGraduate =
          userId.length > 4 && (userId[4] == '2' || userId[4] == '3');
      stage = 'roaming to the academic calendar service';
      trace?.call('Calendar stage=$stage');
      await _authClient.roamToPortalApp(
        isGraduate
            ? _GRADUATE_ACADEMIC_CALENDAR_ROAMING_ID
            : _UNDERGRADUATE_ACADEMIC_CALENDAR_ROAMING_ID,
      );
      final occurrences = <CourseOccurrence>[];
      stage = 'fetching primary calendar entries';
      trace?.call('Calendar stage=$stage');
      occurrences.addAll(await _loadPrimary(term, isGraduate));
      if (!isGraduate) {
        stage = 'fetching secondary undergraduate calendar entries';
        trace?.call('Calendar stage=$stage');
        occurrences.addAll(await _loadSecondary(term));
      }

      final unique = <String, CourseOccurrence>{};
      for (final occurrence in occurrences) {
        final key = [
          occurrence.name,
          occurrence.location,
          occurrence.category,
          occurrence.startsAt.toIso8601String(),
          occurrence.endsAt.toIso8601String(),
        ].join('|');
        unique.putIfAbsent(key, () => occurrence);
      }

      trace?.call('Calendar completed occurrences=${unique.length}');
      return CourseSchedule(
        term: term,
        occurrences: List<CourseOccurrence>.unmodifiable(unique.values),
      );
    } on CourseScheduleSessionExpired {
      rethrow;
    } on FormatException catch (error) {
      await _verifyOrThrow(error, stage);
    } on StateError catch (error) {
      await _verifyOrThrow(error, stage);
    } on PortalCsrfUnavailable catch (error) {
      await _verifyOrThrow(error, stage);
    } on PortalSessionRejected catch (error) {
      await _verifyOrThrow(error, stage);
    } on _PortalAuthenticationRequired catch (error) {
      await _verifyOrThrow(error, stage);
    }
  }

  Future<List<CourseOccurrence>> _loadPrimary(
    AcademicTerm term,
    bool isGraduate,
  ) async {
    final prefix = isGraduate
        ? _GRADUATE_PRIMARY_URL
        : _UNDERGRADUATE_PRIMARY_URL;
    final mode = isGraduate ? 'yjs_jxrl_all' : 'bks_jxrl_all';
    final result = <CourseOccurrence>[];
    for (var firstWeek = 0; firstWeek < term.weekCount; firstWeek += 3) {
      final lastWeek = (firstWeek + _REQUEST_GROUP_WEEKS).clamp(
        1,
        term.weekCount,
      );
      final firstDate = term.firstMonday.add(Duration(days: firstWeek * 7));
      final lastDate = term.firstMonday.add(Duration(days: lastWeek * 7 - 1));
      final uri = Uri.parse(prefix).replace(
        queryParameters: {
          'm': mode,
          'p_start_date': _formatDate(firstDate),
          'p_end_date': _formatDate(lastDate),
          'jsoncallback': 'm',
        },
      );
      final response = await _authClient.getAuthenticated(uri);
      try {
        _ensurePortalResponse(response.body, response.statusCode);
        result.addAll(_parsePrimary(response.body));
      } catch (_) {
        _authClient.traceUnexpectedResponse('primary-calendar', response);
        rethrow;
      }
    }
    return result;
  }

  Future<List<CourseOccurrence>> _loadSecondary(AcademicTerm term) async {
    final response = await _authClient.getAuthenticated(
      Uri.parse(_SECONDARY_SCHEDULE_URL),
    );
    try {
      _ensurePortalResponse(response.body, response.statusCode);
      return _parseSecondary(response.body, term);
    } catch (_) {
      _authClient.traceUnexpectedResponse('secondary-calendar', response);
      rethrow;
    }
  }

  Future<Never> _verifyOrThrow(Object originalError, String stage) async {
    if (originalError is PortalCsrfUnavailable) {
      // Validation uses the same cookie endpoint. Retrying it here cannot
      // prove logout and only obscures the original failure.
      throw CourseScheduleException(
        'The request failed while $stage: ${_safeError(originalError)}. '
        'The saved session was retained because its status is unknown.',
        cause: originalError,
      );
    }
    bool sessionIsValid;
    try {
      sessionIsValid = await _authClient.validateSession();
    } catch (validationError) {
      throw CourseScheduleException(
        'The request failed while $stage: ${_safeError(originalError)}. '
        'Session validation also failed: ${_safeError(validationError)}.',
        cause: originalError,
      );
    }

    if (!sessionIsValid) {
      throw const CourseScheduleSessionExpired();
    }
    throw CourseScheduleException(
      'The request failed while $stage: ${_safeError(originalError)}. '
      'The portal session is still valid.',
      cause: originalError,
    );
  }

  String _safeError(Object error) {
    if (error is FormatException) {
      return 'FormatException: ${error.message}';
    }
    return error.toString();
  }

  AcademicTerm _parseTerm(Map<String, dynamic> json) {
    final start = DateTime.parse(json['kssj'] as String);
    final end = DateTime.parse(json['jssj'] as String);
    final weekday = start.weekday;
    final mondayOffset = switch (weekday) {
      DateTime.saturday => 2,
      DateTime.sunday => 1,
      _ => 1 - weekday,
    };
    final firstMonday = DateTime(
      start.year,
      start.month,
      start.day,
    ).add(Duration(days: mondayOffset));
    final weekCount = end.difference(firstMonday).inDays ~/ 7 + 1;
    if (weekCount <= 0) {
      throw const FormatException(
        'The academic term has an invalid date range.',
      );
    }
    return AcademicTerm(
      id: json['id'] as String,
      name: json['xnxqmc'] as String,
      firstMonday: firstMonday,
      weekCount: weekCount,
    );
  }

  List<CourseOccurrence> _parsePrimary(String body) {
    final start = body.indexOf('[');
    final end = body.lastIndexOf(']');
    if (start < 0 || end < start) {
      throw const FormatException(
        'The primary calendar response is not valid JSONP.',
      );
    }
    final decoded = jsonDecode(body.substring(start, end + 1));
    if (decoded is! List) {
      throw const FormatException(
        'The primary calendar response is not a list.',
      );
    }
    return decoded
        .map((entry) {
          if (entry is! Map) {
            throw const FormatException('A primary calendar entry is invalid.');
          }
          final row = Map<String, dynamic>.from(entry);
          final date = DateTime.parse(row['nq'] as String);
          final startTime = _parseTime(row['kssj'] as String);
          final endTime = _parseTime(row['jssj'] as String);
          return CourseOccurrence(
            name: row['nr'] as String,
            location: (row['dd'] as String?) ?? '',
            category: PlanCategories.LESSON,
            startsAt: DateTime(
              date.year,
              date.month,
              date.day,
              startTime.$1,
              startTime.$2,
            ),
            endsAt: DateTime(
              date.year,
              date.month,
              date.day,
              endTime.$1,
              endTime.$2,
            ),
          );
        })
        .toList(growable: false);
  }

  List<CourseOccurrence> _parseSecondary(String body, AcademicTerm term) {
    final scriptStart = body.indexOf('function setInitValue');
    final scriptEnd = body.indexOf('}', scriptStart);
    if (scriptStart < 0 || scriptEnd < 0) {
      throw const FormatException('The secondary calendar script is missing.');
    }
    final segments = body.substring(scriptStart, scriptEnd).split('strHTML =');
    final rowPattern = RegExp(
      r'''"<span onmouseover=\\"return overlib\('(.+?)'\);\\" onmouseout='return nd\(\);'>(.+?)</span>";[\s\n\t\r]+?document\.getElementById\('(.+?)'\)\.innerHTML \+= strHTML\+"<br>";''',
      dotAll: true,
    );
    final detailPattern = RegExp(r'[^(]+?\(([^，]+?)，');
    final weekPattern = RegExp(
      r'第([\d\-~,]+)周|Week([\d\-~,]+)',
      caseSensitive: false,
    );
    final courses = <CourseOccurrence>[];

    for (final segment in segments.skip(1)) {
      final row = rowPattern.firstMatch(segment);
      if (row == null) continue;
      final detail = row.group(1)!.replaceAll(RegExp(r'\s'), '');
      final name = row.group(2)!;
      final slot = row.group(3)!;
      final slotMatch = RegExp(r'^a([1-6])_([1-7])$').firstMatch(slot);
      final locationMatch = detailPattern.firstMatch(detail);
      if (slotMatch == null || locationMatch == null) continue;
      final session = int.parse(slotMatch.group(1)!);
      final dayOfWeek = int.parse(slotMatch.group(2)!);
      final location = locationMatch.group(1)!;
      final weeks = _parseWeeks(detail, term.weekCount, weekPattern);

      for (final week in weeks) {
        final date = term.firstMonday.add(
          Duration(days: (week - 1) * 7 + dayOfWeek - 1),
        );
        final begin = _parseTime(_BEGIN_TIMES[session]);
        final end = _parseTime(_END_TIMES[session]);
        courses.add(
          CourseOccurrence(
            name: name,
            location: location,
            category: PlanCategories.LESSON,
            startsAt: DateTime(
              date.year,
              date.month,
              date.day,
              begin.$1,
              begin.$2,
            ),
            endsAt: DateTime(date.year, date.month, date.day, end.$1, end.$2),
          ),
        );
      }
    }
    return courses;
  }

  List<int> _parseWeeks(String detail, int weekCount, RegExp pattern) {
    if (detail.contains('单周')) {
      return [for (var week = 1; week <= weekCount; week += 2) week];
    }
    if (detail.contains('双周')) {
      return [for (var week = 2; week <= weekCount; week += 2) week];
    }
    if (detail.contains('全周')) {
      return [for (var week = 1; week <= weekCount; week++) week];
    }
    if (detail.contains('前八周') || detail.contains('前8周')) {
      return [for (var week = 1; week <= weekCount && week <= 8; week++) week];
    }
    if (detail.contains('后八周') || detail.contains('后8周')) {
      final first = (weekCount - 7).clamp(1, weekCount);
      return [for (var week = first; week <= weekCount; week++) week];
    }
    final match = pattern.firstMatch(detail);
    if (match == null) return const [];
    final expression = match.group(1) ?? match.group(2)!;
    final weeks = <int>{};
    for (final part in expression.split(',')) {
      final bounds = part.split('-');
      if (bounds.length == 1) {
        final week = int.tryParse(bounds.single);
        if (week != null && week >= 1 && week <= weekCount) weeks.add(week);
      } else if (bounds.length == 2) {
        final first = int.tryParse(bounds.first);
        final last = int.tryParse(bounds.last);
        if (first != null && last != null && first <= last) {
          for (var week = first; week <= last && week <= weekCount; week++) {
            if (week >= 1) weeks.add(week);
          }
        }
      }
    }
    return weeks.toList()..sort();
  }

  (int, int) _parseTime(String value) {
    final normalized = value.replaceAll('：', ':');
    final parts = normalized.split(':');
    if (parts.length != 2) {
      throw const FormatException('The calendar contains an invalid time.');
    }
    return (int.parse(parts[0]), int.parse(parts[1]));
  }

  void _ensurePortalResponse(String body, int statusCode) {
    final lowerBody = body.toLowerCase();
    if (statusCode == 401 ||
        statusCode == 403 ||
        lowerBody.contains('sm2publickey')) {
      throw const _PortalAuthenticationRequired();
    }
    if (statusCode < 200 || statusCode >= 300) {
      throw CourseScheduleException(
        'The campus service returned HTTP $statusCode.',
      );
    }
  }

  String _readCsrf(String body) {
    final match = RegExp(
      r"""_csrf=([\w-]+)|name=["']_csrf["'][^>]*value=["']([\w-]+)""",
      caseSensitive: false,
    ).firstMatch(body);
    final token = match?.group(1) ?? match?.group(2);
    if (token == null || token.isEmpty) {
      throw const FormatException(
        'The campus service did not return a CSRF token.',
      );
    }
    return token;
  }

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}'
      '${date.month.toString().padLeft(2, '0')}'
      '${date.day.toString().padLeft(2, '0')}';
}

final class _PortalAuthenticationRequired implements Exception {
  const _PortalAuthenticationRequired();
}
