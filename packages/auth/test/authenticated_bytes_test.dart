import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:thulium_auth/thulium_auth.dart';

void main() {
  test(
    'binary requests preserve every byte and headers across cookie-setting redirects',
    () async {
      final bytes = List.generate(256, (index) => index);
      final requests = <http.Request>[];
      final store = MemoryAuthSessionStore();
      await store.write(
        const AuthSession(
          userId: 'student',
          fingerprint: 'test',
          cookies: {},
          scopedCookies: [
            AuthCookie(
              name: 'JSESSIONID',
              value: 'learn-session',
              domain: 'learn.tsinghua.edu.cn',
              path: '/',
              hostOnly: true,
              secure: true,
            ),
          ],
        ),
      );
      final target = TsinghuaWebVpnRedirect.forTarget(
        Uri.parse('https://learn.tsinghua.edu.cn/file'),
      );
      final referer = target.replace(path: '${target.path}/viewer');
      final transport = MockClient((request) async {
        requests.add(request);
        if (requests.length == 1) {
          return http.Response(
            '',
            302,
            headers: {
              'location': '${target.path}/bytes',
              'set-cookie': 'download-token=test; Path=/; Secure',
            },
            request: request,
          );
        }
        return http.Response.bytes(
          bytes,
          200,
          headers: {'content-type': 'application/pdf', 'content-length': '256'},
          request: request,
        );
      });
      final auth = TsinghuaAuthClient(
        sessionStore: store,
        httpClient: transport,
      );
      await auth.restore();
      final response = await auth.getAuthenticatedBytes(
        target,
        referer: referer,
      );
      expect(response.bodyBytes, bytes);
      expect(response.headers['content-type'], 'application/pdf');
      expect(response.headers['content-length'], '256');
      expect(requests, hasLength(2));
      for (final request in requests) {
        expect(request.headers['referer'], referer.toString());
        expect(request.headers['cookie'], contains('JSESSIONID=learn-session'));
      }
      expect(requests.last.headers['cookie'], contains('download-token=test'));
      expect(
        (await store.read())!.scopedCookies.any(
          (cookie) => cookie.name == 'download-token',
        ),
        isTrue,
      );
    },
  );

  test(
    'binary requests require a session and reject non-Tsinghua targets and referers',
    () async {
      final store = MemoryAuthSessionStore();
      final auth = TsinghuaAuthClient(
        sessionStore: store,
        httpClient: MockClient(
          (_) async => throw StateError('Unexpected network access'),
        ),
      );
      final target = Uri.parse('https://learn.tsinghua.edu.cn/file');
      await expectLater(auth.getAuthenticatedBytes(target), throwsStateError);
      await store.write(
        const AuthSession(userId: 'student', fingerprint: 'test', cookies: {}),
      );
      await auth.restore();
      await expectLater(
        auth.getAuthenticatedBytes(Uri.parse('https://example.com/file')),
        throwsArgumentError,
      );
      await expectLater(
        auth.getAuthenticatedBytes(
          target,
          referer: Uri.parse('https://example.com/'),
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'binary requests reject an unexpected external redirect before following it',
    () async {
      var requests = 0;
      final store = MemoryAuthSessionStore();
      await store.write(
        const AuthSession(userId: 'student', fingerprint: 'test', cookies: {}),
      );
      final auth = TsinghuaAuthClient(
        sessionStore: store,
        httpClient: MockClient((request) async {
          requests++;
          return http.Response(
            '',
            302,
            headers: {'location': 'https://example.com/file'},
            request: request,
          );
        }),
      );
      await auth.restore();
      await expectLater(
        auth.getAuthenticatedBytes(
          Uri.parse('https://learn.tsinghua.edu.cn/file'),
        ),
        throwsStateError,
      );
      expect(requests, 1);
    },
  );
}
