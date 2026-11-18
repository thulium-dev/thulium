import 'package:test/test.dart';
import 'package:thulium_auth/thulium_auth.dart';

import 'support/fake_auth_http_client.dart';

void main() {
  test(
    'an already trusted device does not prompt or register again without 2FA',
    () async {
      final store = MemoryAuthSessionStore();
      await store.write(
        const AuthSession(
          userId: '1234567890',
          fingerprint: 'stable-device',
          cookies: {},
          trustedBrowser: true,
          fingerGenPrint: 'trusted-device-token',
        ),
      );
      final transport = FakeAuthHttpClient(
        honorTrustedBrowser: true,
        previouslyRegistered: true,
      );
      final auth = TsinghuaAuthClient(
        httpClient: transport,
        sessionStore: store,
        twoFactorTrustHandler: () async {
          fail('No trust prompt is needed for an authenticated device');
        },
      );
      final session = await auth.login(
        userId: '1234567890',
        password: 'password',
        fingerprint: 'stable-device',
      );
      expect(session.fingerGenPrint, 'trusted-device-token');
      expect(
        transport.requests.where(
          (request) => request.url.path.endsWith('/saveFinger'),
        ),
        isEmpty,
      );
    },
  );

  for (final message in ['信任浏览器数量已达上限', 'Trusted browser limit reached']) {
    test(
      'device quota warns once and continues without claiming trust: $message',
      () async {
        final transport = FakeAuthHttpClient(trustRejectionMessage: message);
        final store = MemoryAuthSessionStore();
        await store.write(
          const AuthSession(
            userId: '1234567890',
            fingerprint: 'device',
            cookies: {},
            trustedBrowser: true,
          ),
        );
        var verified = false;
        var choices = 0;
        var limits = 0;
        final auth = TsinghuaAuthClient(
          httpClient: transport,
          sessionStore: store,
          twoFactorMethodHandler: (_) async => TwoFactorMethod.wechat,
          twoFactorCodeHandler: (verify) async {
            while (!await verify('123456')) {}
            verified = true;
          },
          twoFactorTrustHandler: () async {
            expect(verified, isTrue);
            choices++;
            return true;
          },
          twoFactorAuthLimitHandler: () async => limits++,
        );
        final session = await auth.login(
          userId: '1234567890',
          password: 'password',
          fingerprint: 'device',
        );
        expect(choices, 1);
        expect(limits, 1);
        expect(session.trustedBrowser, isFalse);
        expect(session.fingerGenPrint, isNull);
        expect((await store.read())!.trustedBrowser, isFalse);
        expect(
          transport.requests.where(
            (request) => request.url.path.endsWith('/saveFinger'),
          ),
          hasLength(1),
        );
      },
    );
  }

  for (final entry in <String, DeviceTrustFailureReason>{
    '身份异常': DeviceTrustFailureReason.rejected,
    '登录已过期': DeviceTrustFailureReason.sessionRejected,
    'invalid fingerprint': DeviceTrustFailureReason.invalidFingerprint,
    'rate limit exceeded': DeviceTrustFailureReason.accessRestricted,
  }.entries) {
    test(
      'non-quota registration failure is explicit: ${entry.value}',
      () async {
        final store = MemoryAuthSessionStore();
        final trace = <String>[];
        var limits = 0;
        final auth = TsinghuaAuthClient(
          httpClient: FakeAuthHttpClient(
            trustRejectionMessage: '${entry.key} private-token',
          ),
          sessionStore: store,
          trace: trace.add,
          twoFactorMethodHandler: (_) async => TwoFactorMethod.wechat,
          twoFactorCodeHandler: (verify) async {
            while (!await verify('123456')) {}
          },
          twoFactorTrustHandler: () async => true,
          twoFactorAuthLimitHandler: () async => limits++,
        );
        await expectLater(
          auth.login(
            userId: '1234567890',
            password: 'password',
            fingerprint: 'device',
          ),
          throwsA(
            isA<DeviceTrustRegistrationException>().having(
              (error) => error.reason,
              'reason',
              entry.value,
            ),
          ),
        );
        expect(await store.read(), isNull);
        expect(limits, 0);
        expect(
          trace.join('\n'),
          contains('reason=${entry.value.diagnosticCode}'),
        );
        expect(trace.join('\n'), isNot(contains('private-token')));
      },
    );
  }

  for (final transport in [
    FakeAuthHttpClient(malformedTrustResponse: true),
    FakeAuthHttpClient(throwTrustRequest: true),
  ]) {
    test(
      'invalid or failed registration transport does not report successful trust: ${transport.malformedTrustResponse}',
      () async {
        final store = MemoryAuthSessionStore();
        final auth = TsinghuaAuthClient(
          httpClient: transport,
          sessionStore: store,
          twoFactorMethodHandler: (_) async => TwoFactorMethod.wechat,
          twoFactorCodeHandler: (verify) async {
            while (!await verify('123456')) {}
          },
          twoFactorTrustHandler: () async => true,
        );
        await expectLater(
          auth.login(
            userId: '1234567890',
            password: 'password',
            fingerprint: 'device',
          ),
          throwsA(isA<DeviceTrustRegistrationException>()),
        );
        expect(await store.read(), isNull);
      },
    );
  }
}
