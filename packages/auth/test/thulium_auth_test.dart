import 'dart:convert';

import 'package:dart_sm/dart_sm.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:thulium_auth/thulium_auth.dart';

void main() {
  test('session serialization does not contain a password field', () {
    const session = AuthSession(
      userId: '1234567890',
      fingerprint: 'device-fingerprint',
      cookies: {'JSESSIONID': 'session-value'},
    );

    final restored = AuthSession.decode(session.encode());

    expect(restored.userId, session.userId);
    expect(restored.fingerprint, session.fingerprint);
    expect(restored.cookies, session.cookies);
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

  test('requests the two-factor code before reading it', () async {
    final client = _FakeAuthClient();
    final events = <String>[];
    final auth = TsinghuaAuthClient(
      httpClient: client,
      twoFactorMethodHandler: (_) async {
        events.add('choose-method');
        return TwoFactorMethod.wechat;
      },
      twoFactorCodeHandler: () async {
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
        return '123456';
      },
    );

    await auth.login(
      userId: '1234567890',
      password: 'password',
      fingerprint: 'fingerprint',
    );

    expect(events, ['choose-method', 'read-code']);
  });
}

final class _FakeAuthClient extends http.BaseClient {
  final requests = <http.BaseRequest>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    final requestBody = request is http.Request ? request.body : '';
    final body = switch (request.url.path) {
      '/login' =>
        '<span id="sm2publicKey">${SM2.generateKeyPair().publicKey}</span>',
      '/do/off/ui/auth/login/check' => '二次认证',
      '/b/doubleAuth/login' when requestBody.contains('FIND_APPROACHES') =>
        '{"result":"success","object":{"hasWeChatBool":true,"phone":null,"hasTotp":false}}',
      '/b/doubleAuth/login' when requestBody.contains('SEND_CODE') =>
        '{"result":"success"}',
      '/b/doubleAuth/login' =>
        '{"result":"success","object":{"redirectUrl":"/two-factor-redirect"}}',
      '/two-factor-redirect' => '<a href="/callback">登录成功。正在重定向到</a>',
      '/callback' => '',
      _ => '{}',
    };
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(body)),
      200,
    );
  }
}
