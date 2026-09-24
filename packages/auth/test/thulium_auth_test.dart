import 'dart:convert';

import 'package:dart_sm/dart_sm.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:thulium_auth/thulium_auth.dart';

void main() {
  group('TsinghuaWebVpnRedirect', () {
    test('uses the published information portal redirect path', () {
      expect(
        TsinghuaWebVpnRedirect.INFO_PORTAL_REDIRECT_PATH,
        '/https/77726476706e69737468656265737421f9f9479369247b59700f81b9991b2631506205de/',
      );
    });

    test('uses the published course selection redirect path', () {
      expect(
        TsinghuaWebVpnRedirect.COURSE_SELECTION_REDIRECT_PATH,
        '/http/77726476706e69737468656265737421eaff4b8b3f3b2653770bc7b88b5c2d320506b1aec738590a49ba/xklogin.do',
      );
    });

    test('builds a proxied URI while preserving target query parameters', () {
      final proxied = TsinghuaWebVpnRedirect.forTarget(
        Uri.parse('http://zhjw.cic.tsinghua.edu.cn/jxmh_out.do?m=bks_jxrl_all'),
      );

      expect(proxied.host, TsinghuaWebVpnRedirect.WEBVPN_HOST);
      expect(
        proxied.path,
        '${TsinghuaWebVpnRedirect.ACADEMIC_CALENDAR_REDIRECT_PATH}'
        'jxmh_out.do',
      );
      expect(proxied.queryParameters['m'], 'bks_jxrl_all');
    });

    test('recovers a service URL from its WebVPN proxy route', () {
      final original = TsinghuaWebVpnRedirect.originalTarget(
        Uri.parse(
          'https://webvpn.tsinghua.edu.cn/http/'
          '${TsinghuaWebVpnRedirect.ACADEMIC_CALENDAR_IDENTIFIER}'
          '/jxmh_out.do?m=bks_jxrl_all',
        ),
      );

      expect(
        original,
        Uri.parse('http://zhjw.cic.tsinghua.edu.cn/jxmh_out.do?m=bks_jxrl_all'),
      );
    });

    test('does not decode unrelated WebVPN paths as service routes', () {
      expect(
        TsinghuaWebVpnRedirect.originalTarget(
          Uri.parse('https://webvpn.tsinghua.edu.cn/wengine-vpn/cookie'),
        ),
        isNull,
      );
    });

    test('rejects unlisted destination hosts', () {
      expect(
        () =>
            TsinghuaWebVpnRedirect.forTarget(Uri.parse('https://example.com/')),
        throwsArgumentError,
      );
    });
  });

  test('session serialization does not contain a password field', () {
    final expiration = DateTime.utc(2030, 1, 1);
    final session = AuthSession(
      userId: '1234567890',
      fingerprint: 'device-fingerprint',
      cookies: {'JSESSIONID': 'session-value'},
      scopedCookies: [
        AuthCookie(
          name: 'JSESSIONID',
          value: 'webvpn-session',
          domain: 'webvpn.tsinghua.edu.cn',
          path: '/',
          hostOnly: true,
          secure: true,
          expiresAt: expiration,
        ),
        AuthCookie(
          name: 'JSESSIONID',
          value: 'identity-session',
          domain: 'id.tsinghua.edu.cn',
          path: '/b',
          hostOnly: true,
          secure: true,
        ),
      ],
    );

    final restored = AuthSession.decode(session.encode());

    expect(restored.userId, session.userId);
    expect(restored.fingerprint, session.fingerprint);
    expect(restored.cookies, session.cookies);
    expect(restored.scopedCookies, hasLength(2));
    expect(restored.scopedCookies.first.domain, 'webvpn.tsinghua.edu.cn');
    expect(restored.scopedCookies.first.expiresAt, expiration);
    expect(restored.scopedCookies.last.path, '/b');
    expect(session.toJson().containsKey('password'), isFalse);
  });

  test('session serialization preserves the trusted-device credential', () {
    const session = AuthSession(
      userId: '1234567890',
      fingerprint: 'device-fingerprint',
      cookies: {},
      fingerGenPrint: 'trusted-device-token',
    );

    final restored = AuthSession.decode(session.encode());

    expect(restored.fingerGenPrint, 'trusted-device-token');
  });

  test('memory store restores and clears a session', () async {
    final store = MemoryAuthSessionStore();
    const session = AuthSession(userId: '1', fingerprint: 'f', cookies: {});

    await store.write(session);
    final restored = await store.read();
    expect(restored?.userId, session.userId);
    expect(restored?.fingerprint, session.fingerprint);

    await store.clear();
    expect(await store.read(), isNull);
  });

  test('clears legacy sessions that lack cookie scope metadata', () async {
    final store = MemoryAuthSessionStore();
    await store.write(
      const AuthSession(
        userId: '1234567890',
        fingerprint: 'legacy-device',
        cookies: {'JSESSIONID': 'unscoped-value'},
      ),
    );

    final auth = TsinghuaAuthClient(sessionStore: store);

    expect(await auth.restore(), isNull);
    expect(await store.read(), isNull);
  });

  test('validates a restored session against the information portal', () async {
    final store = MemoryAuthSessionStore();
    await store.write(_savedSession());
    final client = _SessionValidationClient(studentId: '1234567890');
    final auth = TsinghuaAuthClient(httpClient: client, sessionStore: store);

    expect(await auth.restore(), isNotNull);
    expect(await auth.validateSession(), isTrue);
    expect(await store.read(), isNotNull);
    expect(client.requests, hasLength(2));
    expect(client.requests.last.url.queryParameters['_csrf'], 'csrf-value');
    expect(client.requests.last.headers['Cookie'], 'SESSION=webvpn-session');
  });

  test(
    'clears a restored session rejected by the information portal',
    () async {
      final store = MemoryAuthSessionStore();
      await store.write(_savedSession());
      final client = _SessionValidationClient(studentId: 'different-student');
      final auth = TsinghuaAuthClient(httpClient: client, sessionStore: store);

      await auth.restore();

      expect(await auth.validateSession(), isFalse);
      expect(auth.session, isNull);
      expect(await store.read(), isNull);
    },
  );

  test('restores and sends cookies only to their matching host', () async {
    final store = MemoryAuthSessionStore();
    await store.write(
      const AuthSession(
        userId: '1234567890',
        fingerprint: 'scoped-device',
        cookies: {'JSESSIONID': 'identity-session'},
        scopedCookies: [
          AuthCookie(
            name: 'JSESSIONID',
            value: 'webvpn-session',
            domain: 'webvpn.tsinghua.edu.cn',
            path: '/',
            hostOnly: true,
            secure: true,
          ),
          AuthCookie(
            name: 'JSESSIONID',
            value: 'identity-session',
            domain: 'id.tsinghua.edu.cn',
            path: '/',
            hostOnly: true,
            secure: true,
          ),
        ],
      ),
    );
    final client = _FakeAuthClient();
    final auth = TsinghuaAuthClient(httpClient: client, sessionStore: store);

    expect(await auth.restore(), isNotNull);
    await auth.logout();

    expect(client.requests.single.url.host, 'webvpn.tsinghua.edu.cn');
    expect(
      client.requests.single.headers['Cookie'],
      'JSESSIONID=webvpn-session',
    );
  });

  test(
    'retries a rejected two-factor code without sending another code',
    () async {
      final client = _FakeAuthClient();
      final events = <String>[];
      var rejectedEmptyCode = false;
      var rejectedIncorrectCode = false;
      final auth = TsinghuaAuthClient(
        httpClient: client,
        twoFactorMethodHandler: (_) async {
          events.add('choose-method');
          return TwoFactorMethod.wechat;
        },
        twoFactorCodeHandler: (verifyCode) async {
          events.add('read-code');
          expect(
            client.requests.any(
              (request) =>
                  request is http.Request &&
                  !request.body.contains('FIND_APPROACHES') &&
                  request.body.contains('SEND_CODE'),
            ),
            isTrue,
          );
          rejectedEmptyCode = !await verifyCode('');
          rejectedIncorrectCode = !await verifyCode('incorrect');
          expect(await verifyCode('123456'), isTrue);
        },
        twoFactorTrustHandler: () async => true,
      );

      await auth.login(
        userId: '1234567890',
        password: 'password',
        fingerprint: 'fingerprint',
      );

      expect(events, ['choose-method', 'read-code']);
      expect(rejectedEmptyCode, isTrue);
      expect(rejectedIncorrectCode, isTrue);
      expect(
        client.requests[1].headers['Cookie'],
        contains('SESSION=session-value'),
      );
      expect(
        client.requests[1].headers['Cookie'],
        isNot(contains('PATH_ONLY=')),
      );
      expect(client.requests[1].headers['Cookie'], isNot(contains('EXPIRED=')));
      expect(
        client.requests.every((request) => !request.followRedirects),
        isTrue,
      );
      expect(
        client.requests.where(
          (request) =>
              request is http.Request && request.body.contains('SEND_CODE'),
        ),
        hasLength(1),
      );
      expect(
        client.requests.where(
          (request) =>
              request is http.Request && request.body.contains('VERITY_CODE'),
        ),
        hasLength(2),
      );
      final identityLogins = client.requests
          .where((request) => request.url.path == '/do/off/ui/auth/login/check')
          .toList();
      expect(identityLogins, hasLength(2));
      expect(
        identityLogins.first.headers['Cookie'],
        isNot(contains('JSESSIONID=')),
      );
      expect(
        identityLogins.last.headers['Cookie'],
        contains('JSESSIONID=identity-session'),
      );
      expect(
        (identityLogins.last as http.Request).body,
        contains('fingerGenPrint=trusted-device-token'),
      );
      for (final identityLogin in identityLogins) {
        expect(identityLogin.headers['Cookie'], isNot(contains('SESSION=')));
        expect(
          identityLogin.headers['Cookie'],
          contains('SHARED=shared-value'),
        );
      }
      final identityTwoFactor = client.requests.firstWhere(
        (request) =>
            request.url.host == 'id.tsinghua.edu.cn' &&
            request.url.path == '/b/doubleAuth/login',
      );
      expect(
        identityTwoFactor.headers['Cookie'],
        contains('JSESSIONID=identity-session'),
      );
      expect(
        identityTwoFactor.headers['Cookie'],
        isNot(contains('webvpn-session')),
      );
      final insecureRedirect = client.requests.singleWhere(
        (request) => request.url.path == '/two-factor-redirect',
      );
      expect(insecureRedirect.url.scheme, 'http');
      expect(
        insecureRedirect.headers['Cookie'],
        isNot(contains('JSESSIONID=')),
      );
      expect(insecureRedirect.headers['Cookie'], isNot(contains('SHARED=')));
      final informationAppLoginPage = client.requests.singleWhere(
        (request) =>
            request.url.host == 'id.tsinghua.edu.cn' &&
            request.url.path.endsWith('10000ea055dd8d81d09d5a1ba55d39ad'),
      );
      expect(
        informationAppLoginPage.headers['Cookie'],
        contains('JSESSIONID=identity-session'),
      );
      expect(
        informationAppLoginPage.headers['Cookie'],
        isNot(contains('webvpn-session')),
      );
      expect(
        informationAppLoginPage.headers['Cookie'],
        isNot(contains('PATH_ONLY=portal-value')),
      );
      final informationAppRedirect = client.requests.singleWhere(
        (request) =>
            request.url.host == 'oauth.tsinghua.edu.cn' &&
            request.url.path == '/lb-auth/lbredirect',
      );
      expect(
        informationAppRedirect.url.queryParameters['host'],
        'id.tsinghua.edu.cn',
      );
      expect(
        informationAppRedirect.headers['Cookie'],
        isNot(contains('JSESSIONID=')),
      );
      expect(
        auth.session!.scopedCookies.where(
          (cookie) => cookie.name == 'JSESSIONID',
        ),
        hasLength(2),
      );
    },
  );

  test(
    'registers a trusted device and reuses finger3 during portal roaming',
    () async {
      final client = _FakeAuthClient();
      final store = MemoryAuthSessionStore();
      final auth = TsinghuaAuthClient(
        httpClient: client,
        sessionStore: store,
        twoFactorMethodHandler: (_) async => TwoFactorMethod.mobile,
        twoFactorCodeHandler: (verifyCode) async {
          expect(await verifyCode('incorrect'), isFalse);
          expect(await verifyCode('123456'), isTrue);
        },
        twoFactorTrustHandler: () async => true,
      );

      final session = await auth.login(
        userId: '1234567890',
        password: 'password',
        fingerprint: 'device-fingerprint',
      );

      final trustRequest = client.requests.singleWhere(
        (request) => request.url.path == '/b/doubleAuth/personal/saveFinger',
      );
      final portalLogin =
          client.requests
                  .where(
                    (request) =>
                        request.url.path == '/do/off/ui/auth/login/check',
                  )
                  .last
              as http.Request;
      expect(trustRequest, isA<http.Request>());
      expect(
        (trustRequest as http.Request).body,
        contains('device-fingerprint'),
      );
      expect(portalLogin.body, contains('fingerGenPrint=trusted-device-token'));
      expect(session.fingerGenPrint, 'trusted-device-token');
      expect((await store.read())?.fingerGenPrint, 'trusted-device-token');
    },
  );
}

AuthSession _savedSession() => const AuthSession(
  userId: '1234567890',
  fingerprint: 'saved-device',
  cookies: {'SESSION': 'webvpn-session'},
  scopedCookies: [
    AuthCookie(
      name: 'SESSION',
      value: 'webvpn-session',
      domain: 'webvpn.tsinghua.edu.cn',
      path: '/',
      hostOnly: true,
      secure: true,
    ),
  ],
);

final class _SessionValidationClient extends http.BaseClient {
  _SessionValidationClient({required this.studentId});

  final String studentId;
  final requests = <http.BaseRequest>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    final body = request.url.path == '/wengine-vpn/cookie'
        ? 'XSRF-TOKEN=csrf-value; Path=/; Secure'
        : jsonEncode({
            'object': {'ryh': studentId},
          });
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(body)),
      200,
      request: request,
    );
  }
}

final class _FakeAuthClient extends http.BaseClient {
  final requests = <http.BaseRequest>[];
  var _verificationAttempts = 0;
  var _identityLoginAttempts = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    final requestBody = request is http.Request ? request.body : '';
    final body = switch (request.url.path) {
      '/login' => '',
      '/login-form' =>
        '<span id="sm2publicKey">${SM2.generateKeyPair().publicKey}</span>',
      _ when request.url.path.startsWith('/do/off/ui/auth/login/form/') =>
        '<span id="sm2publicKey">${SM2.generateKeyPair().publicKey}</span>',
      '/do/off/ui/auth/login/check' when ++_identityLoginAttempts == 1 =>
        '二次认证',
      '/do/off/ui/auth/login/check'
          when requestBody.contains('fingerGenPrint=trusted-device-token') =>
        '<a href="/information-callback">登录成功。正在重定向到</a>',
      '/do/off/ui/auth/login/check' => '二次认证',
      '/b/doubleAuth/login' when requestBody.contains('FIND_APPROACHES') =>
        '{"result":"success","object":{"hasWeChatBool":true,"phone":null,"hasTotp":false}}',
      '/b/doubleAuth/login' when requestBody.contains('SEND_CODE') =>
        '{"result":"success"}',
      '/b/doubleAuth/login'
          when requestBody.contains('VERITY_CODE') &&
              ++_verificationAttempts == 1 =>
        '{"result":"error","msg":"invalid code"}',
      '/b/doubleAuth/login' =>
        '{"result":"success","object":{"redirectUrl":"http://id.tsinghua.edu.cn/two-factor-redirect"}}',
      '/b/doubleAuth/personal/saveFinger' =>
        '{"result":"success","object":"trusted-device-token"}',
      '/two-factor-redirect' => '<a href="/callback">登录成功。正在重定向到</a>',
      '/callback' => '',
      '/lb-auth/lbredirect' => '',
      _ => '{}',
    };
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(body)),
      request.url.path == '/login' ? 302 : 200,
      headers: switch (request.url.path) {
        '/login' => const {
          'location': '/login-form',
          'set-cookie':
              'JSESSIONID=webvpn-session; Path=/; Secure, PATH_ONLY=portal-value; Path=/https; Secure, EXPIRED=old; Path=/; Expires=Wed, 21 Oct 2015 07:28:00 GMT, SESSION=session-value; Path=/, SHARED=shared-value; Domain=.tsinghua.edu.cn; Path=/; Secure',
        },
        '/do/off/ui/auth/login/check' => const {
          'set-cookie': 'JSESSIONID=identity-session; Path=/; Secure',
        },
        _ => const {},
      },
    );
  }
}
