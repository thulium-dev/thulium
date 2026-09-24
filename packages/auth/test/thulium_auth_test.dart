import 'dart:convert';

import 'package:dart_sm/dart_sm.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:thulium_auth/thulium_auth.dart';

void main() {
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
      final identityLogin = client.requests.singleWhere(
        (request) => request.url.path == '/do/off/ui/auth/login/check',
      );
      expect(identityLogin.headers['Cookie'], isNot(contains('JSESSIONID=')));
      expect(identityLogin.headers['Cookie'], isNot(contains('SESSION=')));
      expect(identityLogin.headers['Cookie'], contains('SHARED=shared-value'));
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
      final webVpnRoaming = client.requests.singleWhere(
        (request) => request.url.path.contains('/https/'),
      );
      expect(
        webVpnRoaming.headers['Cookie'],
        contains('JSESSIONID=webvpn-session'),
      );
      expect(
        webVpnRoaming.headers['Cookie'],
        isNot(contains('identity-session')),
      );
      expect(
        webVpnRoaming.headers['Cookie'],
        contains('PATH_ONLY=portal-value'),
      );
      expect(
        auth.session!.scopedCookies.where(
          (cookie) => cookie.name == 'JSESSIONID',
        ),
        hasLength(2),
      );
    },
  );
}

final class _FakeAuthClient extends http.BaseClient {
  final requests = <http.BaseRequest>[];
  var _verificationAttempts = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    final requestBody = request is http.Request ? request.body : '';
    final body = switch (request.url.path) {
      '/login' => '',
      '/login-form' =>
        '<span id="sm2publicKey">${SM2.generateKeyPair().publicKey}</span>',
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
      '/two-factor-redirect' => '<a href="/callback">登录成功。正在重定向到</a>',
      '/callback' => '',
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
