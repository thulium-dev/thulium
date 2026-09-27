import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:thulium_auth/thulium_auth.dart';
import 'package:thulium_campus/thulium_campus.dart';

void main() {
  test(
    'fetches the Learn course list through WebVPN with scoped cookies',
    () async {
      final transport = _LearnHttpClient();
      final store = MemoryAuthSessionStore();
      await store.write(_session);
      final auth = TsinghuaAuthClient(
        httpClient: transport,
        sessionStore: store,
      );
      expect(await auth.restore(), isNotNull);

      final response = await LearnCourseService(
        auth,
        now: () => DateTime.fromMillisecondsSinceEpoch(1790484534941),
      ).fetchSemester('2026-2027-1');

      expect(response['currentUser'], '2024012050');
      expect((response['resultList'] as List).single['kcm'], 'Course A');
      final request = transport.courseRequest!;
      expect(request.url.host, TsinghuaWebVpnRedirect.WEBVPN_HOST);
      expect(
        request.url.path,
        startsWith(TsinghuaWebVpnRedirect.LEARNING_PLATFORM_REDIRECT_PATH),
      );
      expect(request.url.path, endsWith('/2026-2027-1/zh'));
      expect(request.url.queryParameters['timestamp'], '1790484534941');
      expect(request.url.queryParameters['_csrf'], 'learn-csrf');
      final cookies = request.headers['cookie'] ?? '';
      expect(cookies, contains('JSESSIONID=learn-session'));
      expect(cookies, contains('XSRF-TOKEN=learn-csrf'));
      expect(cookies, contains('!Proxy!PHPSESSID=proxy-php'));
      expect(cookies, contains('wengine_vpn_ticket=vpn-ticket'));
      expect(cookies, isNot(contains('other-service-session')));
      expect(cookies, isNot(contains('portal-csrf')));
    },
  );

  test('uses Learn XSRF cookie if landing page omits the CSRF field', () async {
    final transport = _LearnHttpClient(omitPageCsrf: true);
    final store = MemoryAuthSessionStore();
    await store.write(_session);
    final auth = TsinghuaAuthClient(httpClient: transport, sessionStore: store);
    await auth.restore();

    await LearnCourseService(auth).fetchSemester('2026-2027-1');

    expect(transport.courseRequest!.url.queryParameters['_csrf'], 'learn-csrf');
  });

  test('rejects unsafe semester paths before making a request', () async {
    final transport = _LearnHttpClient();
    final auth = TsinghuaAuthClient(httpClient: transport);
    await expectLater(
      LearnCourseService(auth).fetchSemester('../login'),
      throwsArgumentError,
    );
    expect(transport.courseRequest, isNull);
  });

  test('rejects a course list belonging to another account', () async {
    final transport = _LearnHttpClient(currentUser: 'another-student');
    final store = MemoryAuthSessionStore();
    await store.write(_session);
    final auth = TsinghuaAuthClient(httpClient: transport, sessionStore: store);
    await auth.restore();

    await expectLater(
      LearnCourseService(auth).fetchSemester('2026-2027-1'),
      throwsA(isA<StateError>()),
    );
  });
}

const _session = AuthSession(
  userId: '2024012050',
  fingerprint: 'test-fingerprint',
  cookies: {'wengine_vpn_ticket': 'vpn-ticket'},
  scopedCookies: [
    AuthCookie(
      name: 'wengine_vpn_ticket',
      value: 'vpn-ticket',
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

final class _LearnHttpClient extends http.BaseClient {
  _LearnHttpClient({
    this.omitPageCsrf = false,
    this.currentUser = '2024012050',
  });

  final bool omitPageCsrf;
  final String currentUser;
  http.BaseRequest? courseRequest;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    late final String body;
    final headers = <String, String>{
      'content-type': 'text/html; charset=utf-8',
    };
    if (path == '/wengine-vpn/cookie') {
      body = 'XSRF-TOKEN=portal-csrf; Path=/;';
    } else if (path.endsWith('onlineAppRedirect')) {
      body = jsonEncode({
        'object': {
          'roamingurl':
              'https://learn.tsinghua.edu.cn/f/wlxt/index/course/student/index',
        },
      });
    } else if (path.endsWith('loadCourseBySemesterId/2026-2027-1/zh')) {
      courseRequest = request;
      body = jsonEncode({
        'currentUser': currentUser,
        'message': 'success',
        'resultList': [
          {'kcm': 'Course A', 'wlkcid': 'course-id'},
        ],
      });
    } else if (path.contains('/f/wlxt/index/course/student/index')) {
      body = omitPageCsrf
          ? '<html>Learn</html>'
          : '<html>_csrf=learn-csrf</html>';
      headers['set-cookie'] =
          'JSESSIONID=learn-session; Path=/; Secure, '
          'XSRF-TOKEN=learn-csrf; Path=/; Secure, '
          '!Proxy!PHPSESSID=proxy-php; Path=/; Secure';
    } else {
      throw StateError('Unexpected test path: $path');
    }
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      200,
      headers: headers,
      request: request,
    );
  }
}
