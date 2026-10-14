import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:thulium_auth/thulium_auth.dart';
import 'package:thulium_campus/thulium_campus.dart';

void main() {
  test(
    'counts all courses and statuses from totals rather than page rows',
    () async {
      final requests = <http.Request>[];
      var landings = 0;
      final auth = await _auth((request) {
        requests.add(request);
        final endpoint = request.url.path.split('/').last;
        final count = request.url.queryParameters['wlkcid'] == 'empty-course'
            ? 0
            : switch (endpoint) {
                'zyListWj' => 12,
                'zyListYjwg' => 3,
                'zyListYpg' => 8,
                _ => throw StateError('Unexpected endpoint: $endpoint'),
              };
        return http.Response(
          jsonEncode({
            'result': 'success',
            'object': {
              'iTotalRecords': endpoint == 'zyListYpg' ? count : '$count',
              'iTotalDisplayRecords': '$count',
              'aaData': [],
            },
          }),
          200,
          request: request,
        );
      }, onLanding: () => landings++);
      final result = await LearnHomeworkService(auth).fetchCourses(_catalog);
      expect(result, hasLength(2));
      expect(result.first.counts.unsubmitted, 12);
      expect(result.first.counts.submittedUngraded, 3);
      expect(result.first.counts.graded, 8);
      expect(result.first.counts.total, 23);
      expect(result.last.counts.total, 0);
      expect(landings, 1);
      expect(requests, hasLength(6));
      for (final request in requests) {
        expect(request.method, 'GET');
        expect(request.url.host, TsinghuaWebVpnRedirect.WEBVPN_HOST);
        expect(request.url.path, contains('/b/wlxt/kczy/zy/student/index/'));
        expect(request.url.queryParameters['_csrf'], 'learn-csrf');
        expect(request.url.queryParameters['size'], '5');
        expect(request.headers['cookie'], contains('JSESSIONID=learn-session'));
      }
    },
  );

  test(
    'authentication failure is reconnectable and never a zero count',
    () async {
      final auth = await _auth(
        (request) => http.Response('', 401, request: request),
      );
      await expectLater(
        LearnHomeworkService(auth).fetchCourses(_catalog),
        throwsA(isA<PortalSessionRejected>()),
      );
    },
  );

  test(
    'invalid totals and provider failures do not produce partial summaries',
    () async {
      for (final body in [
        '<html>not JSON</html>',
        jsonEncode({
          'result': 'error',
          'object': {'iTotalRecords': '0'},
        }),
        jsonEncode({'result': 'success', 'object': {}}),
        for (final value in ['bad', '-1', 1.5, null])
          jsonEncode({
            'result': 'success',
            'object': {'iTotalRecords': value},
          }),
      ]) {
        final auth = await _auth(
          (request) => http.Response(body, 200, request: request),
        );
        await expectLater(
          LearnHomeworkService(auth).fetchCourses(_catalog),
          throwsFormatException,
        );
      }
    },
  );

  test('an empty catalog needs no homework requests', () async {
    final auth = await _auth((_) => throw StateError('Unexpected request'));
    expect(
      await LearnHomeworkService(auth).fetchCourses(
        LearnCourseCatalog(
          userId: 'test-student',
          semester: '2026-2027-1',
          courses: [],
        ),
      ),
      isEmpty,
    );
  });

  test(
    'rejects a catalog from another account before requesting data',
    () async {
      final auth = await _auth((_) => throw StateError('Unexpected request'));
      await expectLater(
        LearnHomeworkService(auth).fetchCourses(
          LearnCourseCatalog(
            userId: 'other-student',
            semester: '2026-2027-1',
            courses: [],
          ),
        ),
        throwsStateError,
      );
    },
  );
}

final _catalog = LearnCourseCatalog(
  userId: 'test-student',
  semester: '2026-2027-1',
  courses: const [
    LearnCourse(
      id: 'course-id',
      name: 'Physics',
      englishName: '',
      teacherName: '',
      schedule: '',
    ),
    LearnCourse(
      id: 'empty-course',
      name: 'Empty',
      englishName: '',
      teacherName: '',
      schedule: '',
    ),
  ],
);

Future<TsinghuaAuthClient> _auth(
  http.Response Function(http.Request) homeworkResponse, {
  void Function()? onLanding,
}) async {
  final transport = MockClient((request) async {
    if (request.url.path == '/wengine-vpn/cookie') {
      return http.Response(
        'XSRF-TOKEN=portal-csrf; Path=/;',
        200,
        request: request,
      );
    }
    if (request.url.path.endsWith('onlineAppRedirect')) {
      return http.Response(
        jsonEncode({
          'object': {
            'roamingurl':
                'https://learn.tsinghua.edu.cn/f/wlxt/index/course/student/index',
          },
        }),
        200,
        request: request,
      );
    }
    if (request.url.path.contains('/f/wlxt/index/course/student/index')) {
      onLanding?.call();
      return http.Response(
        '<html>_csrf=learn-csrf</html>',
        200,
        headers: {'set-cookie': 'JSESSIONID=learn-session; Path=/; Secure'},
        request: request,
      );
    }
    return homeworkResponse(request);
  });
  final store = MemoryAuthSessionStore();
  await store.write(
    const AuthSession(userId: 'test-student', fingerprint: 'test', cookies: {}),
  );
  final auth = TsinghuaAuthClient(httpClient: transport, sessionStore: store);
  await auth.restore();
  return auth;
}
