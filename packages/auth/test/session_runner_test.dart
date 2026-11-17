import 'dart:async';
import 'dart:convert';

import 'package:dart_sm/dart_sm.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:thulium_auth/thulium_auth.dart';

final _resource = Uri.parse('https://info.tsinghua.edu.cn/resource');
const _session = AuthSession(
  userId: '1234567890',
  fingerprint: 'stable-device',
  cookies: {},
  fingerGenPrint: 'trusted-device',
  scopedCookies: [
    AuthCookie(
      name: 'JSESSIONID',
      value: 'old',
      domain: 'info.tsinghua.edu.cn',
      path: '/',
      hostOnly: true,
      secure: true,
    ),
  ],
);

void main() {
  test(
    'service-specific authentication errors can recover through the same queue',
    () async {
      final store = _Store();
      final transport = _Transport();
      var attempts = 0;
      final expired = StateError('wrapped session error');
      final result = await _runner(store, transport).run(
        shouldReconnect: (error) => identical(error, expired),
        request: (client, isRetry) async {
          attempts++;
          if (!isRetry) throw expired;
          return _load(client, isRetry);
        },
      );
      expect(result, 'content');
      expect(attempts, 2);
      expect(transport.logins, 1);
    },
  );

  test(
    'concurrent callers reuse one credential login and the latest cookies',
    () async {
      final store = _Store();
      final transport = _Transport()..releaseFirst = Completer<void>();
      final runner = _runner(store, transport);
      final first = runner.run(request: _load);
      await transport.firstResource.future;
      final second = _runner(store, transport).run(request: _load);
      await Future<void>.delayed(Duration.zero);
      expect(transport.resourceCookies, hasLength(1));
      transport.releaseFirst!.complete();
      expect(await Future.wait([first, second]), ['content', 'content']);
      expect(transport.logins, 1);
      expect(transport.resourceCookies, hasLength(3));
      expect(transport.resourceCookies.last, contains('ROTATED=fresh'));
      expect(transport.identityForms, hasLength(2));
      for (final form in transport.identityForms) {
        expect(form['fingerPrint'], 'stable-device');
        expect(form['fingerGenPrint'], 'trusted-device');
      }
      expect(store.saved!.fingerGenPrint, 'trusted-device');
      expect(store.credentials!.password, 'saved-password');
    },
  );

  test('a rejected retry does not cause a second credential login', () async {
    final store = _Store();
    final transport = _Transport()..rejectRetry = true;
    await expectLater(
      _runner(store, transport).run(request: _load),
      throwsA(isA<PortalSessionRejected>()),
    );
    expect(transport.logins, 1);
    expect(transport.resourceCookies, hasLength(2));
  });

  test('network and malformed-content errors do not trigger a login', () async {
    for (final error in [
      TimeoutException('offline'),
      const FormatException('bad JSON'),
    ]) {
      final store = _Store();
      final transport = _Transport();
      await expectLater(
        _runner(
          store,
          transport,
        ).run<void>(request: (_, _) async => throw error),
        throwsA(same(error)),
      );
      expect(transport.logins, 0);
      expect(store.saved, same(_session));
      expect(store.credentialReads, 0);
    }
  });

  test('missing or other-account credentials never trigger a login', () async {
    for (final credentials in [
      null,
      const AuthCredentials(userId: 'other', password: 'other'),
    ]) {
      final store = _Store()..credentials = credentials;
      final transport = _Transport();
      await expectLater(
        _runner(store, transport).run(request: _load),
        throwsA(isA<PortalSessionRejected>()),
      );
      expect(transport.logins, 0);
    }
  });

  test('queued operations cannot act on a different account', () async {
    final store = _Store();
    var requested = false;
    await expectLater(
      _runner(store, _Transport()).run<void>(
        expectedUserId: 'other-account',
        request: (_, _) async {
          requested = true;
        },
      ),
      throwsA(isA<PortalSessionRejected>()),
    );
    expect(requested, isFalse);
  });

  test(
    'interactive verification preserves credentials and releases the queue',
    () async {
      final store = _Store();
      final transport = _Transport()..needsVerification = true;
      await expectLater(
        _runner(store, transport).run(request: _load),
        throwsA(isA<TwoFactorInteractionRequired>()),
      );
      expect(store.saved, isNotNull);
      expect(store.credentials!.password, 'saved-password');
      expect(
        await _runner(store, transport).run(request: (_, _) async => 'cached'),
        'cached',
      );
    },
  );

  test(
    'logout waits for an active request and prevents queued session resurrection',
    () async {
      final store = _Store();
      final transport = _Transport()..releaseFirst = Completer<void>();
      final first = _runner(store, transport).run(request: _load);
      await transport.firstResource.future;
      final logout = AuthSessionRunner.exclusive(store, () async {
        await store.clear();
        await store.clearCredentials();
      });
      final afterLogout = expectLater(
        _runner(store, transport).run(request: _load),
        throwsA(isA<PortalSessionRejected>()),
      );
      transport.releaseFirst!.complete();
      await first;
      await logout;
      await afterLogout;
      expect(store.saved, isNull);
      expect(store.credentials, isNull);
      expect(transport.logins, 1);
    },
  );
}

AuthSessionRunner _runner(_Store store, _Transport transport) =>
    AuthSessionRunner(
      store,
      createClient: () => TsinghuaAuthClient(
        httpClient: transport,
        sessionStore: store,
        credentialStore: store,
      ),
    );

Future<String> _load(TsinghuaAuthClient client, bool isRetry) async {
  final response = await client.getAuthenticated(_resource);
  if (response.statusCode == 401) throw const PortalSessionRejected();
  return response.body;
}

class _Store implements AuthSessionStore, AuthCredentialStore {
  AuthSession? saved = _session;
  AuthCredentials? credentials = const AuthCredentials(
    userId: '1234567890',
    password: 'saved-password',
  );
  int credentialReads = 0;
  @override
  Future<AuthSession?> read() async => saved;
  @override
  Future<void> write(AuthSession session) async => saved = session;
  @override
  Future<void> clear() async => saved = null;
  @override
  Future<AuthCredentials?> readCredentials() async {
    credentialReads++;
    return credentials;
  }

  @override
  Future<void> writeCredentials(AuthCredentials value) async =>
      credentials = value;
  @override
  Future<void> clearCredentials() async => credentials = null;
}

class _Transport extends http.BaseClient {
  final firstResource = Completer<void>();
  Completer<void>? releaseFirst;
  final resourceCookies = <String>[];
  final identityForms = <Map<String, String>>[];
  final publicKey = SM2.generateKeyPair().publicKey;
  int logins = 0;
  bool rejectRetry = false;
  bool needsVerification = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    String body = '';
    var status = 200;
    final headers = <String, String>{};
    switch (request.url.path) {
      case '/resource':
        final cookies = request.headers['Cookie'] ?? '';
        resourceCookies.add(cookies);
        if (!firstResource.isCompleted) {
          firstResource.complete();
          await releaseFirst?.future;
        }
        if (cookies.contains('JSESSIONID=new') && !rejectRetry) {
          body = 'content';
          headers['set-cookie'] = 'ROTATED=fresh; Path=/; Secure';
        } else {
          status = 401;
        }
      case '/login':
        logins++;
        body = '<span id="sm2publicKey">$publicKey</span>';
      case final path when path.startsWith('/do/off/ui/auth/login/form/'):
        body = '<span id="sm2publicKey">$publicKey</span>';
      case '/do/off/ui/auth/login/check':
        identityForms.add(Uri.splitQueryString((request as http.Request).body));
        body = needsVerification
            ? '二次认证'
            : '<a href="https://id.tsinghua.edu.cn/callback">登录成功。正在重定向到</a>';
      case '/wengine-vpn/cookie':
        body = 'XSRF-TOKEN=new-csrf; JSESSIONID=new;';
      case final path when path.endsWith('/b/info/gxfw_fg/common/grjbxx'):
        body = '{"result":"success","object":{"ryh":"1234567890"}}';
    }
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      status,
      request: request,
      headers: headers,
    );
  }
}
