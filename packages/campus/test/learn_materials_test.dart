import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:thulium_auth/thulium_auth.dart';
import 'package:thulium_campus/thulium_campus.dart';

void main() {
  test(
    'requests the captured route with shared roaming, scoped cookies and limit',
    () async {
      final requests = <http.Request>[];
      var landings = 0;
      final auth = await _auth((request) {
        requests.add(request);
        return _response(
          request,
          request.url.queryParameters['wlkcid'] == 'physics' ? [_row()] : [],
        );
      }, onLanding: () => landings++);
      final courses = await LearnMaterialService(auth).fetchCourses(_catalog);
      expect(landings, 1);
      expect(requests, hasLength(2));
      for (final request in requests) {
        expect(request.method, 'GET');
        expect(request.url.host, TsinghuaWebVpnRedirect.WEBVPN_HOST);
        expect(
          request.url.path,
          endsWith(
            '/b/wlxt/kj/wlkc_kjxxb/student/kjxxbByWlkcidAndSizeForStudent',
          ),
        );
        expect(request.url.queryParameters['size'], '200');
        expect(request.url.queryParameters['_csrf'], 'learn-csrf');
        expect(request.headers['cookie'], contains('JSESSIONID=learn-session'));
      }
      final item = courses.first.materials.single;
      expect(item.title, 'ATP synthase');
      expect(item.sizeBytes, 2855509);
      expect(
        item.displaySize,
        '2.0M',
      ); // Do not infer bytes from the rounded label.
      expect(item.uploadedAt, DateTime.utc(2026, 10, 20, 7, 12));
      expect(
        item.availableAt,
        DateTime.fromMillisecondsSinceEpoch(1792562400000, isUtc: true),
      );
      expect(item.isNew, isTrue);
      expect(item.viewCount, 0);
      expect(item.downloadCount, 5);
      expect(item.rawResponse['sfqd'], 0);
      expect(courses.first.mayBeTruncated, isFalse);
      expect(courses.last.materials, isEmpty);
    },
  );

  test(
    'filters before requests and flags a response at the requested limit',
    () async {
      final requests = <http.Request>[];
      final auth = await _auth((request) {
        requests.add(request);
        return _response(request, [_row()]);
      });
      final result = await LearnMaterialService(
        auth,
      ).fetchCourses(_catalog, courseId: 'physics', size: 1);
      expect(requests, hasLength(1));
      expect(requests.single.url.queryParameters['wlkcid'], 'physics');
      expect(requests.single.url.queryParameters['size'], '1');
      expect(result.single.requestedLimit, 1);
      expect(result.single.mayBeTruncated, isTrue);
    },
  );

  test(
    'invalid size, account and course selection fail before any network access',
    () async {
      final auth = await _auth(
        (_) => throw StateError('Unexpected request'),
        onLanding: () => fail('Unexpected roaming'),
      );
      final service = LearnMaterialService(auth);
      for (final size in [0, -1]) {
        await expectLater(
          service.fetchCourses(_catalog, size: size),
          throwsArgumentError,
        );
      }
      await expectLater(
        service.fetchCourses(_catalog, courseId: 'missing'),
        throwsArgumentError,
      );
      await expectLater(
        service.fetchCourses(
          LearnCourseCatalog(
            userId: 'other',
            semester: '2026-2027-1',
            courses: [],
          ),
        ),
        throwsStateError,
      );
      final result = await service.fetchCourses(
        LearnCourseCatalog(
          userId: 'student',
          semester: '2026-2027-1',
          courses: [],
        ),
      );
      expect(result, isEmpty);
    },
  );

  test(
    'auth failures remain reconnectable and HTTP failures are not empty results',
    () async {
      for (final status in [401, 403, 500]) {
        final auth = await _auth(
          (request) => http.Response('', status, request: request),
        );
        await expectLater(
          LearnMaterialService(auth).fetchCourses(_catalog),
          status == 500
              ? throwsStateError
              : throwsA(isA<PortalSessionRejected>()),
        );
      }
      final auth = await _auth(
        (request) =>
            http.Response('<html>sm2publickey</html>', 200, request: request),
      );
      await expectLater(
        LearnMaterialService(auth).fetchCourses(_catalog),
        throwsA(isA<PortalSessionRejected>()),
      );
    },
  );

  test(
    'malformed responses and cross-course rows fail instead of silently omitting files',
    () async {
      for (final body in [
        '<html>not JSON</html>',
        jsonEncode({'result': 'error', 'object': []}),
        jsonEncode({'result': 'success', 'object': {}}),
        jsonEncode({
          'result': 'success',
          'object': [null],
        }),
        jsonEncode({
          'result': 'success',
          'object': [_row()..['wlkcid'] = 'another-course'],
        }),
        jsonEncode({
          'result': 'success',
          'object': [_row()..['wjid'] = null],
        }),
        jsonEncode({
          'result': 'success',
          'object': [_row(), _row()],
        }),
      ]) {
        final auth = await _auth(
          (request) => http.Response(body, 200, request: request),
        );
        await expectLater(
          LearnMaterialService(auth).fetchCourses(_catalog),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'optional fields stay unknown, string numbers parse, raw fields stay immutable',
    () {
      final row = _row()
        ..['wjdx'] = '2855509'
        ..['isNew'] = '0'
        ..['scsj'] = 'not a timestamp'
        ..['sxsj'] = '99999999999999999999'
        ..['llcs'] = -1
        ..['xzcs'] = '7';
      final material = LearnMaterial.fromResponse(row);
      expect(material.sizeBytes, 2855509);
      expect(material.isNew, isFalse);
      expect(material.uploadedAt, isNull);
      expect(material.availableAt, isNull);
      expect(material.viewCount, isNull);
      expect(material.downloadCount, 7);
      expect(() => material.rawResponse['sfqd'] = 1, throwsUnsupportedError);
    },
  );
}

Map<String, dynamic> _row() => {
  'wlkcid': 'physics',
  'kjxxid': 'material-1',
  'bt': 'ATP synthase',
  'wjid': 'file-1',
  'wjlx': 'pdf',
  'sfqd': 0,
  'scsj': '2026-10-20 15:12',
  'sxsj': 1792562400000,
  'isNew': 1,
  'fileSize': '2.0M',
  'wjdx': 2855509,
  'llcs': 0,
  'xzcs': 5,
  'ms': '',
  'kjflid': 'category-1',
};

http.Response _response(http.Request request, List<Object?> rows) =>
    http.Response(
      jsonEncode({'result': 'success', 'object': rows}),
      200,
      request: request,
    );

final _catalog = LearnCourseCatalog(
  userId: 'student',
  semester: '2026-2027-1',
  courses: const [
    LearnCourse(
      id: 'physics',
      name: 'Physics',
      englishName: '',
      teacherName: '',
      schedule: '',
    ),
    LearnCourse(
      id: 'empty',
      name: 'Empty',
      englishName: '',
      teacherName: '',
      schedule: '',
    ),
  ],
);

Future<TsinghuaAuthClient> _auth(
  http.Response Function(http.Request) respond, {
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
    return respond(request);
  });
  final store = MemoryAuthSessionStore();
  await store.write(
    const AuthSession(userId: 'student', fingerprint: 'test', cookies: {}),
  );
  final client = TsinghuaAuthClient(httpClient: transport, sessionStore: store);
  await client.restore();
  return client;
}
