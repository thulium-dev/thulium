import 'dart:convert';

import 'package:dart_sm/dart_sm.dart';
import 'package:http/http.dart' as http;

final class FakeAuthHttpClient extends http.BaseClient {
  FakeAuthHttpClient({
    this.failInformationRedirect = false,
    this.expireCookieBeforeLogin = false,
    this.trustWithoutToken = false,
    this.trustedPortalForm = false,
    this.honorTrustedBrowser = false,
    this.denySingleLogin = false,
    this.singleLoginAction = '/do/off/ui/auth/login/checkSingle',
    String registeredFingerprint = 'stable-device',
    bool previouslyRegistered = false,
  }) : _registered = previouslyRegistered,
       // Keep the synthetic server's registration identity configurable.
       // ignore: prefer_initializing_formals
       _registeredFingerprint = registeredFingerprint;

  final bool failInformationRedirect;
  final bool expireCookieBeforeLogin;
  bool _credentialsSubmitted = false;
  bool _registered;
  String _registeredFingerprint;
  final bool trustWithoutToken;
  final bool trustedPortalForm;
  final bool honorTrustedBrowser;
  final bool denySingleLogin;
  final String singleLoginAction;
  final requests = <http.BaseRequest>[];
  var _verificationAttempts = 0;
  int get verificationRequestCount => requests
      .where(
        (request) =>
            request is http.Request &&
            request.url.path == '/b/doubleAuth/login' &&
            request.body.contains('VERITY_CODE'),
      )
      .length;

  var _identityLoginAttempts = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    final requestBody = request is http.Request ? request.body : '';
    if (request.url.path == '/do/off/ui/auth/login/check') {
      _credentialsSubmitted = true;
    }
    if (request.url.path == '/b/doubleAuth/personal/saveFinger') {
      _registered = true;
      _registeredFingerprint = Uri.splitQueryString(
        requestBody,
      )['fingerprint']!;
    }
    final body = switch (request.url.path) {
      '/login' => '',
      '/login-form' =>
        '<span id="sm2publicKey">${SM2.generateKeyPair().publicKey}</span>',
      _
          when trustedPortalForm &&
              request.url.path.startsWith('/do/off/ui/auth/login/form/') =>
        '<form action="$singleLoginAction" method="post">'
            '<input type="hidden" name="fingerPrint" value="">'
            '<input type="hidden" name="i_rememberme" value="on">'
            '<input type="hidden" name="execution" value="one&amp;two">'
            '<input disabled name="disabled-field" value="ignored">'
            '</form>',
      _ when request.url.path.startsWith('/do/off/ui/auth/login/form/') =>
        '<span id="sm2publicKey">${SM2.generateKeyPair().publicKey}</span>',
      '/do/off/ui/auth/login/checkSingle' when denySingleLogin =>
        '<span id="sm2publicKey">${SM2.generateKeyPair().publicKey}</span>',
      '/do/off/ui/auth/login/checkSingle' =>
        '<a href="https://id.tsinghua.edu.cn/callback">登录成功。正在重定向到</a>',
      '/do/off/ui/auth/login/check'
          when honorTrustedBrowser &&
              _registered &&
              Uri.splitQueryString(requestBody)['fingerPrint'] ==
                  _registeredFingerprint =>
        '<a href="https://id.tsinghua.edu.cn/callback">登录成功。正在重定向到</a>',
      '/do/off/ui/auth/login/check' when ++_identityLoginAttempts == 1 =>
        '二次认证',
      '/do/off/ui/auth/login/check'
          when requestBody.contains('fingerGenPrint=trusted-device-token') =>
        '<a href="https://id.tsinghua.edu.cn/f/j_spring_security_thauth_roaming_entry?atOnce=atOnce&&ticket=test-ticket">登录成功。正在重定向到</a>',
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
      '/b/doubleAuth/personal/saveFinger' when trustWithoutToken =>
        '{"result":"success"}',
      '/b/doubleAuth/personal/saveFinger' =>
        '{"result":"success","object":"trusted-device-token"}',
      '/two-factor-redirect' => '<a href="/callback">登录成功。正在重定向到</a>',
      '/callback' => '',
      '/lb-auth/lbredirect' => '',
      '/wengine-vpn/failed' => '<html>WebVPN service failed</html>',
      '/wengine-vpn/cookie'
          when expireCookieBeforeLogin && !_credentialsSubmitted =>
        '<html><span id="sm2publicKey">expired</span></html>',
      '/wengine-vpn/cookie' =>
        'XSRF-TOKEN=csrf-value; JSESSIONID=portal-session;',
      _ when request.url.path.endsWith('/b/info/gxfw_fg/common/grjbxx') =>
        '{"result":"success","object":{"ryh":"1234567890"}}',
      _ => '{}',
    };
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(body)),
      request.url.path == '/login'
          ? 302
          : request.url.path == '/lb-auth/lbredirect' && failInformationRedirect
          ? 307
          : 200,
      headers: switch (request.url.path) {
        '/login' => const {
          'location': '/login-form',
          'set-cookie':
              'JSESSIONID=webvpn-session; Path=/; Secure, PATH_ONLY=portal-value; Path=/https; Secure, EXPIRED=old; Path=/; Expires=Wed, 21 Oct 2015 07:28:00 GMT, SESSION=session-value; Path=/, SHARED=shared-value; Domain=.tsinghua.edu.cn; Path=/; Secure',
        },
        '/do/off/ui/auth/login/check' => const {
          'set-cookie': 'JSESSIONID=identity-session; Path=/; Secure',
        },
        '/lb-auth/lbredirect' when failInformationRedirect => const {
          'location': 'https://webvpn.tsinghua.edu.cn/wengine-vpn/failed',
        },
        _ => const {},
      },
    );
  }
}
