import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:thulium_auth/thulium_auth.dart';
import 'package:thulium_campus/thulium_campus.dart';

void main() {
  test(
    'loads the term and combines its date-specific primary schedule',
    () async {
      final transport = _ScheduleHttpClient(isGraduate: true);
      final store = MemoryAuthSessionStore();
      await store.write(_testSession(isGraduate: true));
      final authClient = TsinghuaAuthClient(
        httpClient: transport,
        sessionStore: store,
      );

      final diagnostics = <String>[];

      final schedule = await CourseScheduleService(
        authClient,
        trace: diagnostics.add,
      ).loadCurrentTerm();

      expect(
        diagnostics,
        contains('Calendar stage=fetching primary calendar entries'),
      );
      expect(diagnostics.last, 'Calendar completed occurrences=1');

      expect(schedule.term.name, 'Autumn term');
      expect(schedule.term.weekCount, 16);
      expect(schedule.occurrences, hasLength(1));
      expect(schedule.occurrences.single.name, 'Course A');
      expect(schedule.occurrences.single.location, 'Room 101');
      expect(schedule.occurrences.single.startsAt, DateTime(2026, 9, 7, 8));
      expect(
        transport.requestedUris.where(
          (uri) => uri.path.endsWith('jxmh_out.do'),
        ),
        hasLength(6),
      );
      final primaryRequests = transport.requestedUris.where(
        (uri) => uri.path.endsWith('jxmh_out.do'),
      );
      expect(
        primaryRequests.every(
          (uri) =>
              uri.scheme == 'https' &&
              uri.host == TsinghuaWebVpnRedirect.WEBVPN_HOST &&
              uri.path.startsWith(
                TsinghuaWebVpnRedirect.ACADEMIC_CALENDAR_REDIRECT_PATH,
              ) &&
              uri.queryParameters.keys.toSet().containsAll({
                'm',
                'p_start_date',
                'p_end_date',
                'jsoncallback',
              }) &&
              uri.queryParameters.length == 4 &&
              uri.queryParameters['jsoncallback'] == 'm',
        ),
        isTrue,
      );
      expect(
        primaryRequests.every(
          (uri) =>
              transport.requestCookieHeaders[uri]?.contains(
                'JSESSIONID=calendar-session',
              ) ??
              false,
        ),
        isTrue,
      );
      expect(
        primaryRequests.every(
          (uri) => !(transport.requestCookieHeaders[uri] ?? '').contains(
            'other-service-session',
          ),
        ),
        isTrue,
      );
      expect(
        primaryRequests.every(
          (uri) => (transport.requestCookieHeaders[uri] ?? '').contains(
            'wengine_vpn_ticket=proxy-ticket',
          ),
        ),
        isTrue,
      );
      final calendarSessionCookie = scheduleCookie(
        authClient.session!.scopedCookies,
        'JSESSIONID',
        TsinghuaWebVpnRedirect.ACADEMIC_CALENDAR_HOST,
      );
      expect(
        calendarSessionCookie.domain,
        TsinghuaWebVpnRedirect.ACADEMIC_CALENDAR_HOST,
      );
      final proxyTicketCookie = scheduleCookie(
        authClient.session!.scopedCookies,
        'wengine_vpn_ticket',
        TsinghuaWebVpnRedirect.WEBVPN_HOST,
      );
      expect(proxyTicketCookie.domain, TsinghuaWebVpnRedirect.WEBVPN_HOST);
    },
  );

  test('merges undergraduate weekly rules with actual-date courses', () async {
    final transport = _ScheduleHttpClient(isGraduate: false);
    final store = MemoryAuthSessionStore();
    await store.write(_testSession(isGraduate: false));
    final authClient = TsinghuaAuthClient(
      httpClient: transport,
      sessionStore: store,
    );

    final schedule = await CourseScheduleService(authClient).loadCurrentTerm();

    expect(schedule.occurrences, hasLength(2));
    expect(
      schedule.occurrences.map((course) => course.name),
      containsAll(['Course A', 'Weekly Course']),
    );
    final primaryRequests = transport.requestedUris.where(
      (uri) => uri.path.endsWith('jxmh_out.do'),
    );
    expect(primaryRequests, hasLength(6));
    expect(
      schedule.occurrences
          .singleWhere((course) => course.name == 'Weekly Course')
          .startsAt,
      DateTime(2026, 9, 7, 8),
    );
    expect(
      transport.requestedUris.any((uri) => uri.path.endsWith('portal3rd.do')),
      isTrue,
    );
  });

  test('combines consecutive API lesson rows in the Dart schedule', () async {
    final transport = _ScheduleHttpClient(
      isGraduate: true,
      consecutivePrimary: true,
    );
    final store = MemoryAuthSessionStore();
    await store.write(_testSession(isGraduate: true));

    final schedule = await CourseScheduleService(
      TsinghuaAuthClient(httpClient: transport, sessionStore: store),
    ).loadCurrentTerm();

    expect(schedule.occurrences, hasLength(1));
    expect(schedule.occurrences.single.startsAt, DateTime(2026, 9, 7, 8));
    expect(schedule.occurrences.single.endsAt, DateTime(2026, 9, 7, 11, 35));
    expect(schedule.occurrences.single.category, PlanCategories.LESSON);
  });

  test('merges only same-day lessons with exact names and locations', () {
    final schedule = CourseSchedule(
      term: _cachedSchedule().term,
      occurrences: [
        _occurrence('Course A', 'Room 101', 10, 50, 11, 35),
        _occurrence('Course A', 'Room 101', 8, 0, 9, 35),
        _occurrence('Course A', 'Room 101', 9, 50, 10, 35),
        // A 16-minute gap must remain separate from the preceding block.
        _occurrence('Course A', 'Room 101', 11, 51, 12, 30),
        _occurrence('Course A', 'Room 102', 9, 50, 10, 35),
        _occurrence('course A', 'Room 101', 9, 50, 10, 35),
        _occurrence('Course A', 'Room 101', 9, 50, 10, 35, day: 8),
        _occurrence(
          'Course A',
          'Room 101',
          9,
          50,
          10,
          35,
          category: 'personal',
        ),
      ],
    );

    expect(schedule.occurrences, hasLength(6));
    final merged = schedule.occurrences.singleWhere(
      (entry) =>
          entry.name == 'Course A' &&
          entry.location == 'Room 101' &&
          entry.category == PlanCategories.LESSON &&
          entry.startsAt.day == 7 &&
          entry.startsAt.hour == 8,
    );
    expect(merged.endsAt, DateTime(2026, 9, 7, 11, 35));
    expect(
      schedule.occurrences.where((entry) => entry.category == 'personal'),
      hasLength(1),
    );
  });

  test(
    'keeps the original request failure when session validation also fails',
    () async {
      final transport = _ScheduleHttpClient(
        isGraduate: true,
        malformedPrimary: true,
        invalidUserData: true,
      );
      final store = MemoryAuthSessionStore();
      await store.write(_testSession(isGraduate: true));
      final traces = <String>[];
      final authClient = TsinghuaAuthClient(
        httpClient: transport,
        sessionStore: store,
        trace: traces.add,
      );

      await expectLater(
        CourseScheduleService(authClient).loadCurrentTerm(),
        throwsA(
          isA<CourseScheduleException>().having(
            (error) => error.message,
            'message',
            allOf(
              contains('fetching primary calendar entries'),
              contains('The primary calendar response is not valid JSONP.'),
              contains('Session validation also failed'),
              contains('unexpected JSON envelope'),
              contains('result=failure'),
            ),
          ),
        ),
      );
      expect(
        traces,
        contains(
          allOf(
            contains('stage=primary-calendar'),
            contains('preview="invalid JSONP response"'),
          ),
        ),
      );
    },
  );

  test(
    'retains a saved session when the portal cookie endpoint is empty',
    () async {
      final transport = _ScheduleHttpClient(
        isGraduate: true,
        emptyCookieBody: true,
      );
      final store = MemoryAuthSessionStore();
      await store.write(_testSession(isGraduate: true));
      final authClient = TsinghuaAuthClient(
        httpClient: transport,
        sessionStore: store,
      );

      await expectLater(
        CourseScheduleService(authClient).loadCurrentTerm(),
        throwsA(
          isA<CourseScheduleException>().having(
            (error) => error.cause,
            'cause',
            isA<PortalCsrfUnavailable>(),
          ),
        ),
      );
      expect(await store.read(), isNotNull);
    },
  );

  test('a fresh account-scoped cache avoids schedule requests', () async {
    final store = MemoryAuthSessionStore();
    final session = _testSession(isGraduate: true);
    await store.write(session);
    final transport = _ScheduleHttpClient(isGraduate: true);
    final cache = CourseScheduleCache(_MemoryCacheStore());
    final fetchedAt = DateTime.utc(2026, 9, 25, 10);
    final original = _cachedSchedule();
    await cache.writeFor(session.userId, original, fetchedAt);

    expect((await cache.readFor('another-account')), isNull);
    final service = CourseScheduleService(
      TsinghuaAuthClient(httpClient: transport, sessionStore: store),
      cache: cache,
      now: () => fetchedAt.add(const Duration(hours: 1)),
    );
    final schedule = await service.loadCurrentTerm();

    expect(schedule.occurrences.single.name, 'Cached Course');
    expect(service.lastSource, CourseScheduleSource.freshCache);
    expect(transport.requestedUris, isEmpty);
  });

  test('refresh bypasses the cache and replaces it', () async {
    final store = MemoryAuthSessionStore();
    final session = _testSession(isGraduate: true);
    await store.write(session);
    final transport = _ScheduleHttpClient(isGraduate: true);
    final cache = CourseScheduleCache(_MemoryCacheStore());
    final fetchedAt = DateTime.utc(2026, 9, 25, 10);
    await cache.writeFor(session.userId, _cachedSchedule(), fetchedAt);

    final schedule = await CourseScheduleService(
      TsinghuaAuthClient(httpClient: transport, sessionStore: store),
      cache: cache,
      now: () => fetchedAt.add(const Duration(hours: 1)),
    ).loadCurrentTerm(forceRefresh: true);

    expect(schedule.occurrences.single.name, 'Course A');
    expect(transport.requestedUris, isNotEmpty);
    expect(
      (await cache.readFor(session.userId))!.schedule.occurrences.single.name,
      'Course A',
    );
  });

  test('uses an expired cache when the portal is unavailable', () async {
    final store = MemoryAuthSessionStore();
    final session = _testSession(isGraduate: true);
    await store.write(session);
    final transport = _ScheduleHttpClient(
      isGraduate: true,
      emptyCookieBody: true,
    );
    final cache = CourseScheduleCache(_MemoryCacheStore());
    final fetchedAt = DateTime.utc(2026, 9, 25, 10);
    await cache.writeFor(session.userId, _cachedSchedule(), fetchedAt);
    final traces = <String>[];

    final service = CourseScheduleService(
      TsinghuaAuthClient(httpClient: transport, sessionStore: store),
      cache: cache,
      trace: traces.add,
      now: () => fetchedAt.add(const Duration(days: 2)),
    );
    final schedule = await service.loadCurrentTerm();

    expect(schedule.occurrences.single.name, 'Cached Course');
    expect(service.lastSource, CourseScheduleSource.staleCache);
    expect(traces, contains(startsWith('Calendar using stale cache')));
    expect(transport.requestedUris, isNotEmpty);
  });

  test('ignores corrupt schedule cache data', () async {
    final store = _MemoryCacheStore()..value = 'not-base64';
    expect(await CourseScheduleCache(store).readFor('2024222050'), isNull);
  });

  test('reads version-one caches as lessons and merges their rows', () async {
    final data = {
      'version': 1,
      'userId': '2024222050',
      'fetchedAt': '2026-09-25T10:00:00.000Z',
      'term': {
        'id': '2026-2027-1',
        'name': 'Autumn term',
        'firstMonday': '2026-09-07T00:00:00.000',
        'weekCount': 16,
      },
      'occurrences': [
        {
          'name': 'Course A',
          'location': 'Room 101',
          'startsAt': '2026-09-07T08:00:00.000',
          'endsAt': '2026-09-07T09:35:00.000',
        },
        {
          'name': 'Course A',
          'location': 'Room 101',
          'startsAt': '2026-09-07T09:50:00.000',
          'endsAt': '2026-09-07T10:35:00.000',
        },
      ],
    };
    final store = _MemoryCacheStore()
      ..value = base64Encode(gzip.encode(utf8.encode(jsonEncode(data))));

    final cached = await CourseScheduleCache(store).readFor('2024222050');

    expect(cached!.schedule.occurrences, hasLength(1));
    expect(cached.schedule.occurrences.single.category, PlanCategories.LESSON);
    expect(
      cached.schedule.occurrences.single.endsAt,
      DateTime(2026, 9, 7, 10, 35),
    );
  });

  test('round-trips a custom category without merging its plans', () async {
    final store = _MemoryCacheStore();
    final cache = CourseScheduleCache(store);
    final schedule = CourseSchedule(
      term: _cachedSchedule().term,
      occurrences: [
        _occurrence('Workout', 'Gym', 8, 0, 9, 0, category: 'fitness'),
        _occurrence('Workout', 'Gym', 9, 10, 10, 0, category: 'fitness'),
      ],
    );

    await cache.writeFor('2024222050', schedule, DateTime.utc(2026, 9, 25));
    final restored = await cache.readFor('2024222050');

    expect(restored!.schedule.occurrences, hasLength(2));
    expect(
      restored.schedule.occurrences.map((entry) => entry.category),
      everyElement('fitness'),
    );
  });

  test('does not use a cache from an ended academic term', () async {
    final store = MemoryAuthSessionStore();
    final session = _testSession(isGraduate: true);
    await store.write(session);
    final transport = _ScheduleHttpClient(isGraduate: true);
    final cache = CourseScheduleCache(_MemoryCacheStore());
    await cache.writeFor(
      session.userId,
      _cachedSchedule(),
      DateTime.utc(2027, 2, 1),
    );

    final schedule = await CourseScheduleService(
      TsinghuaAuthClient(httpClient: transport, sessionStore: store),
      cache: cache,
      now: () => DateTime.utc(2027, 2, 1, 1),
    ).loadCurrentTerm();

    expect(schedule.occurrences.single.name, 'Course A');
    expect(transport.requestedUris, isNotEmpty);
  });
}

CourseSchedule _cachedSchedule() => CourseSchedule(
  term: AcademicTerm(
    id: '2026-2027-1',
    name: 'Autumn term',
    firstMonday: DateTime(2026, 9, 7),
    weekCount: 16,
  ),
  occurrences: [
    CourseOccurrence(
      name: 'Cached Course',
      location: 'Room 101',
      category: PlanCategories.LESSON,
      startsAt: DateTime(2026, 9, 7, 8),
      endsAt: DateTime(2026, 9, 7, 9, 35),
    ),
  ],
);

CourseOccurrence _occurrence(
  String name,
  String location,
  int startHour,
  int startMinute,
  int endHour,
  int endMinute, {
  int day = 7,
  String category = PlanCategories.LESSON,
}) => CourseOccurrence(
  name: name,
  location: location,
  category: category,
  startsAt: DateTime(2026, 9, day, startHour, startMinute),
  endsAt: DateTime(2026, 9, day, endHour, endMinute),
);

final class _MemoryCacheStore implements CourseScheduleCacheStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String encoded) async => value = encoded;

  @override
  Future<void> clear() async => value = null;
}

AuthSession _testSession({required bool isGraduate}) => AuthSession(
  userId: isGraduate ? '2024222050' : '2024012050',
  fingerprint: 'test-fingerprint',
  cookies: const {'SESSION': 'session-value'},
  scopedCookies: const [
    AuthCookie(
      name: 'SESSION',
      value: 'session-value',
      domain: 'webvpn.tsinghua.edu.cn',
      path: '/',
      hostOnly: true,
      secure: true,
    ),
    AuthCookie(
      name: 'JSESSIONID',
      value: 'other-service-session',
      domain: 'zhjwxk.cic.tsinghua.edu.cn',
      path: '/',
      hostOnly: true,
      secure: false,
    ),
  ],
);

AuthCookie scheduleCookie(
  List<AuthCookie> cookies,
  String name,
  String domain,
) => cookies.singleWhere(
  (cookie) => cookie.name == name && cookie.domain == domain,
);

final class _ScheduleHttpClient extends http.BaseClient {
  _ScheduleHttpClient({
    required this.isGraduate,
    this.consecutivePrimary = false,
    this.malformedPrimary = false,
    this.invalidUserData = false,
    this.emptyCookieBody = false,
  });

  final bool isGraduate;
  final bool consecutivePrimary;
  final bool malformedPrimary;
  final bool invalidUserData;
  final bool emptyCookieBody;
  final requestedUris = <Uri>[];
  final requestCookieHeaders = <Uri, String?>{};

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final uri = request.url;
    requestedUris.add(uri);
    requestCookieHeaders[uri] = request.headers['cookie'];
    final body = switch (uri.path) {
      '/wengine-vpn/cookie' =>
        emptyCookieBody ? '' : 'XSRF-TOKEN=csrf-token; Path=/;',
      _ when uri.path.endsWith('onlineAppRedirect') => jsonEncode({
        'object': {
          'roamingurl':
              uri.queryParameters['yyfwid'] ==
                  '3E401364BDD7AEA7EBF1EDE3F15ED4B7'
              ? 'https://learn.tsinghua.edu.cn/f/wlxt/index/course/student/index'
              : 'http://zhjw.cic.tsinghua.edu.cn/',
        },
      }),
      _ when uri.path.contains('getCurrentAndNextSemester') => jsonEncode({
        'message': 'success',
        'result': {
          'id': '2026-2027-1',
          'xnxqmc': 'Autumn term',
          'kssj': '2026-09-07',
          'jssj': '2026-12-27',
        },
      }),
      _ when uri.path.endsWith('jxmh_out.do') =>
        malformedPrimary
            ? 'invalid JSONP response'
            : uri.queryParameters['p_start_date'] == '20260907'
            ? consecutivePrimary
                  ? 'm([{"nq":"2026-09-07","kssj":"08:00",'
                        '"jssj":"09:35","nr":"Course A","dd":"Room 101"},'
                        '{"nq":"2026-09-07","kssj":"09:50",'
                        '"jssj":"10:35","nr":"Course A","dd":"Room 101"},'
                        '{"nq":"2026-09-07","kssj":"10:50",'
                        '"jssj":"11:35","nr":"Course A","dd":"Room 101"}])'
                  : 'm([{"nq":"2026-09-07","kssj":"08:00",'
                        '"jssj":"09:35","nr":"Course A","dd":"Room 101"}])'
            : 'm([])',
      _ when invalidUserData && uri.path.contains('grjbxx') =>
        '{"result":"failure"}',
      _ when !isGraduate && uri.path.endsWith('portal3rd.do') =>
        r'''function setInitValue() {
          strHTML = ""; var strHTML1 = "";
          strHTML += "<span onmouseover=\"return overlib('Weekly Course(Room 101，Teacher，第1周)');\" onmouseout='return nd();'>Weekly Course</span>";
          document.getElementById('a1_1').innerHTML += strHTML+"<br>";
        }''',
      _
          when uri.host == TsinghuaWebVpnRedirect.WEBVPN_HOST &&
              uri.path.startsWith(
                TsinghuaWebVpnRedirect.ACADEMIC_CALENDAR_REDIRECT_PATH,
              ) =>
        '<html>Academic calendar landing page</html>',
      _ when uri.path.contains('/https/') => '<html>_csrf=csrf-token</html>',
      _ => 'function setInitValue() {}',
    };

    final responseHeaders = <String, String>{
      'content-type': 'application/json; charset=utf-8',
    };
    if (uri.host == TsinghuaWebVpnRedirect.WEBVPN_HOST &&
        uri.path.startsWith(
          TsinghuaWebVpnRedirect.ACADEMIC_CALENDAR_REDIRECT_PATH,
        )) {
      responseHeaders['set-cookie'] =
          'JSESSIONID=calendar-session; Path=/, '
          'wengine_vpn_ticket=proxy-ticket; Path=/; Secure';
    }

    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      200,
      request: request,
      headers: responseHeaders,
    );
  }
}
