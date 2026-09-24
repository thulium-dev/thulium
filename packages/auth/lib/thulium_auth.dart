library;

// Thulium uses uppercase snake case for named constants across Dart and
// Flutter packages. This intentionally overrides the Dart style lint, which
// normally recommends lowerCamelCase for constants.
// ignore_for_file: constant_identifier_names

import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpDate, HttpException;

import 'package:dart_sm/dart_sm.dart';
import 'package:http/http.dart' as http;

// Entry point that starts the WebVPN OAuth flow and redirects to the identity
// provider. Keeping these endpoints in one place makes protocol updates easier
// to review and prevents URL fragments from being duplicated throughout the
// authentication client.
const _WEB_VPN_OAUTH_LOGIN_URL =
    'https://webvpn.tsinghua.edu.cn/login?oauth_login=true';
const _USER_AGENT =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
    'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/79.0.3945.88 '
    'Safari/537.36';
const _ID_HOST_URL = 'https://id.tsinghua.edu.cn';
const _ID_LOGIN_URL = '$_ID_HOST_URL/do/off/ui/auth/login/check';
const _DOUBLE_AUTH_URL = '$_ID_HOST_URL/b/doubleAuth/login';
const _INFO_ROAMING_URL =
    'https://webvpn.tsinghua.edu.cn/https/77726476706e69737468656265737421f9f9479369247b59700f81b9991b2631506205de/b/yyfw/vyyfwxx/info/portal_fg/common/onlineAppRedirect';
const _INFO_ROAMING_ID = '10000ea055dd8d81d09d5a1ba55d39ad';
const _LOGOUT_URL = 'https://webvpn.tsinghua.edu.cn/logout';
const _TWO_FACTOR_SUCCESS = 'success';
const _TWO_FACTOR_FIND_APPROACHES = 'FIND_APPROACHES';
const _TWO_FACTOR_SEND_CODE = 'SEND_CODE';
const _TWO_FACTOR_VERIFY_CODE = 'VERITY_CODE';
const _TWO_FACTOR_VERIFY_TOTP_CODE = 'VERITY_TOTP_CODE';
const _COOKIE_DOMAIN_SUFFIX = 'tsinghua.edu.cn';

/// A cookie together with the scope required to safely restore it.
final class AuthCookie {
  const AuthCookie({
    required this.name,
    required this.value,
    required this.domain,
    required this.path,
    required this.hostOnly,
    required this.secure,
    this.expiresAt,
  });

  final String name;
  final String value;
  final String domain;
  final String path;
  final bool hostOnly;
  final bool secure;
  final DateTime? expiresAt;

  Map<String, Object?> toJson() => {
    'name': name,
    'value': value,
    'domain': domain,
    'path': path,
    'hostOnly': hostOnly,
    'secure': secure,
    'expiresAt': expiresAt?.toUtc().toIso8601String(),
  };

  factory AuthCookie.fromJson(Map<String, dynamic> json) => AuthCookie(
    name: json['name'] as String,
    value: json['value'] as String,
    domain: json['domain'] as String,
    path: json['path'] as String,
    hostOnly: json['hostOnly'] as bool,
    secure: json['secure'] as bool,
    expiresAt: json['expiresAt'] == null
        ? null
        : DateTime.parse(json['expiresAt'] as String).toUtc(),
  );
}

/// A serializable authenticated session. It contains no password.
final class AuthSession {
  const AuthSession({
    required this.userId,
    required this.fingerprint,
    required this.cookies,
    this.scopedCookies = const [],
  });

  /// The numeric Tsinghua account identifier used during sign-in.
  final String userId;

  /// The browser-like fingerprint associated with the authenticated session.
  final String fingerprint;

  /// Cookies returned by WebVPN and the identity provider.
  ///
  /// Cookies are sufficient for session restoration, while the password is
  /// intentionally not represented by this object and can therefore never be
  /// serialized by accident.
  final Map<String, String> cookies;

  /// Full cookie scope used for host-safe request headers after restoration.
  ///
  /// [cookies] remains as a compatibility view for callers that only need the
  /// cookie names and values. New sessions must use this scoped representation
  /// when restoring authenticated requests.
  final List<AuthCookie> scopedCookies;

  /// Converts the session to a JSON-compatible map for secure persistence.
  Map<String, Object> toJson() => {
    'userId': userId,
    'fingerprint': fingerprint,
    'cookies': cookies,
    'scopedCookies': scopedCookies.map((cookie) => cookie.toJson()).toList(),
  };

  /// Reconstructs a session previously produced by [toJson].
  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
    userId: json['userId'] as String,
    fingerprint: json['fingerprint'] as String,
    cookies: Map<String, String>.from(json['cookies'] as Map),
    scopedCookies: (json['scopedCookies'] as List? ?? const [])
        .map(
          (cookie) =>
              AuthCookie.fromJson(Map<String, dynamic>.from(cookie as Map)),
        )
        .toList(growable: false),
  );

  /// Encodes this session as a single string for key-value secure stores.
  String encode() => jsonEncode(toJson());

  /// Decodes a session string created by [encode].
  factory AuthSession.decode(String value) =>
      AuthSession.fromJson(jsonDecode(value) as Map<String, dynamic>);
}

/// Stores cookies as distinct name/domain/path entries rather than globally.
final class _CookieJar {
  final List<AuthCookie> _cookies = <AuthCookie>[];

  List<AuthCookie> get cookies {
    _removeExpired();
    return List<AuthCookie>.unmodifiable(_cookies);
  }

  void clear() => _cookies.clear();

  void restore(Iterable<AuthCookie> cookies) {
    _cookies
      ..clear()
      ..addAll(cookies);
    _removeExpired();
  }

  void capture(Uri origin, String? setCookieHeader) {
    if (setCookieHeader == null) return;

    // Some HTTP adapters combine repeated Set-Cookie headers. The comma in an
    // Expires date is not followed by a cookie-pair, so this splits only at
    // cookie boundaries while retaining the date value.
    final headers = setCookieHeader.split(RegExp(r',(?=\s*[^;,=]+=)'));
    for (final header in headers) {
      _captureOne(origin, header.trim());
    }
    _removeExpired();
  }

  String headerFor(Uri uri) {
    _removeExpired();
    final matching = _matching(uri);
    return matching
        .map((cookie) => '${cookie.name}=${cookie.value}')
        .join('; ');
  }

  Iterable<String> namesFor(Uri uri) =>
      _matching(uri).map((cookie) => cookie.name);

  Map<String, String> get legacyValues {
    _removeExpired();
    return {for (final cookie in _cookies) cookie.name: cookie.value};
  }

  List<AuthCookie> _matching(Uri uri) {
    _removeExpired();
    return _cookies.where((cookie) => _matches(cookie, uri)).toList()
      ..sort((left, right) => right.path.length.compareTo(left.path.length));
  }

  void _captureOne(Uri origin, String header) {
    final attributes = header.split(';');
    if (attributes.isEmpty) return;
    final pairSeparator = attributes.first.indexOf('=');
    if (pairSeparator <= 0) return;

    final name = attributes.first.substring(0, pairSeparator).trim();
    final value = attributes.first.substring(pairSeparator + 1).trim();
    if (name.isEmpty) return;

    final originHost = origin.host.toLowerCase();
    var domain = originHost;
    var hostOnly = true;
    var path = _defaultPath(origin.path);
    var secure = false;
    DateTime? expiresAt;
    int? maxAge;

    for (final attribute in attributes.skip(1)) {
      final separator = attribute.indexOf('=');
      final key =
          (separator < 0 ? attribute : attribute.substring(0, separator))
              .trim()
              .toLowerCase();
      final value = separator < 0
          ? ''
          : attribute.substring(separator + 1).trim();
      switch (key) {
        case 'domain':
          final candidate = value.toLowerCase().replaceFirst(
            RegExp(r'^\.'),
            '',
          );
          if (candidate.isEmpty ||
              !_domainMatches(originHost, candidate) ||
              !_isAllowedDomainScope(candidate)) {
            return;
          }
          domain = candidate;
          hostOnly = false;
        case 'path':
          if (value.startsWith('/')) path = value;
        case 'secure':
          secure = true;
        case 'max-age':
          maxAge = int.tryParse(value);
        case 'expires':
          try {
            expiresAt = HttpDate.parse(value).toUtc();
          } on HttpException {
            // Ignore malformed dates and retain a valid Max-Age if present.
          }
      }
    }

    if (maxAge != null) {
      if (maxAge <= 0) {
        _remove(name, domain, path);
        return;
      }
      expiresAt = DateTime.now().toUtc().add(Duration(seconds: maxAge));
    }

    _remove(name, domain, path);
    _cookies.add(
      AuthCookie(
        name: name,
        value: value,
        domain: domain,
        path: path,
        hostOnly: hostOnly,
        secure: secure,
        expiresAt: expiresAt,
      ),
    );
  }

  bool _matches(AuthCookie cookie, Uri uri) {
    final host = uri.host.toLowerCase();
    if (cookie.hostOnly
        ? host != cookie.domain
        : !_domainMatches(host, cookie.domain)) {
      return false;
    }
    if (cookie.secure && uri.scheme != 'https') return false;

    final requestPath = uri.path.isEmpty ? '/' : uri.path;
    if (requestPath == cookie.path) return true;
    if (!requestPath.startsWith(cookie.path)) return false;
    return cookie.path.endsWith('/') ||
        requestPath.codeUnitAt(cookie.path.length) == 0x2f;
  }

  void _removeExpired() {
    final now = DateTime.now().toUtc();
    _cookies.removeWhere(
      (cookie) => cookie.expiresAt != null && !cookie.expiresAt!.isAfter(now),
    );
  }

  void _remove(String name, String domain, String path) {
    _cookies.removeWhere(
      (cookie) =>
          cookie.name == name && cookie.domain == domain && cookie.path == path,
    );
  }

  static String _defaultPath(String requestPath) {
    if (!requestPath.startsWith('/') || requestPath.lastIndexOf('/') <= 0) {
      return '/';
    }
    return requestPath.substring(0, requestPath.lastIndexOf('/'));
  }

  static bool _domainMatches(String host, String domain) =>
      host == domain || host.endsWith('.$domain');

  static bool _isAllowedDomainScope(String domain) =>
      domain == _COOKIE_DOMAIN_SUFFIX ||
      domain.endsWith('.$_COOKIE_DOMAIN_SUFFIX');
}

/// Storage abstraction implemented by a platform-specific secure store.
abstract interface class AuthSessionStore {
  /// Reads the last persisted session, if one exists.
  Future<AuthSession?> read();

  /// Persists a session without persisting the user's password.
  Future<void> write(AuthSession session);

  /// Removes the persisted session.
  Future<void> clear();
}

/// A no-op in-memory store useful for CLI sessions and tests.
final class MemoryAuthSessionStore implements AuthSessionStore {
  AuthSession? _session;

  @override
  Future<AuthSession?> read() async => _session;

  @override
  Future<void> write(AuthSession session) async => _session = session;

  @override
  Future<void> clear() async => _session = null;
}

enum TwoFactorMethod { wechat, mobile, totp }

/// Describes the second-factor methods currently available for an account.
final class TwoFactorOptions {
  const TwoFactorOptions({
    required this.hasWeChat,
    required this.phone,
    required this.hasTotp,
  });

  /// Whether the account can approve a login through WeChat.
  final bool hasWeChat;

  /// The masked phone number available for SMS verification, if any.
  final String? phone;

  /// Whether the account has a time-based one-time password configured.
  final bool hasTotp;
}

/// Lets a client choose one of the methods returned by the identity provider.
typedef TwoFactorMethodHandler =
    Future<TwoFactorMethod> Function(TwoFactorOptions options);

/// Lets a client collect codes and keep its input surface open until verified.
typedef TwoFactorCodeVerifier = Future<bool> Function(String code);
typedef TwoFactorCodeHandler =
    Future<void> Function(TwoFactorCodeVerifier verifyCode);

/// Receives safe authentication diagnostics without credential values.
typedef AuthTraceHandler = void Function(String message);

/// Implements the shared Tsinghua WebVPN and identity login flow.
final class TsinghuaAuthClient {
  TsinghuaAuthClient({
    http.Client? httpClient,
    AuthSessionStore? sessionStore,
    this.twoFactorMethodHandler,
    this.twoFactorCodeHandler,
    this.trace,
  }) : _http = httpClient ?? http.Client(),
       // Preserve the public `sessionStore:` injection API. Initializing this
       // private field directly would expose an inaccessible named parameter.
       // ignore: prefer_initializing_formals
       _sessionStore = sessionStore;

  /// The HTTP client is injectable so callers can configure proxies, testing
  /// transports, or platform-specific networking behavior.
  final http.Client _http;

  /// The optional platform-specific store used for session restoration.
  final AuthSessionStore? _sessionStore;

  /// Called to choose a second-factor method before a code is sent.
  final TwoFactorMethodHandler? twoFactorMethodHandler;

  /// Called only after the selected second-factor code has been requested.
  final TwoFactorCodeHandler? twoFactorCodeHandler;

  /// Optional diagnostic callback. Messages contain no passwords, codes, or
  /// cookie values and are disabled by default.
  final AuthTraceHandler? trace;

  /// Cookies stay scoped to their originating host/path throughout the flow.
  final _CookieJar _cookieJar = _CookieJar();

  AuthSession? get session => _session;
  AuthSession? _session;

  /// Restores the last session without asking for the password.
  Future<AuthSession?> restore() async {
    final restored = await _sessionStore?.read();
    if (restored == null) return null;

    // Older sessions stored only cookie names and values, losing the origin
    // host and path. Reusing those unscoped values would disclose credentials
    // across Tsinghua services, so require one fresh sign-in after upgrading.
    if (restored.cookies.isNotEmpty && restored.scopedCookies.isEmpty) {
      await _sessionStore?.clear();
      _session = null;
      _cookieJar.clear();
      return null;
    }

    _session = restored;
    _cookieJar.restore(restored.scopedCookies);
    return restored;
  }

  /// Logs in and persists only the resulting session cookies.
  Future<AuthSession> login({
    required String userId,
    required String password,
    required String fingerprint,
  }) async {
    if (!RegExp(r'^\d+$').hasMatch(userId)) {
      throw const FormatException('The user ID must contain only digits.');
    }
    _cookieJar.clear();

    final loginPage = await _request(Uri.parse(_WEB_VPN_OAUTH_LOGIN_URL));
    final publicKey = _extract(
      loginPage.body,
      'id="sm2publicKey"[^>]*>([^<]+)',
    );
    if (publicKey == null || publicKey.isEmpty) {
      throw StateError('The identity login public key was not found.');
    }

    var response = await _request(
      Uri.parse(_ID_LOGIN_URL),
      method: 'POST',
      form: {
        'i_user': userId,
        'i_pass': '04${SM2.encrypt(password, publicKey)}',
        'fingerPrint': fingerprint,
        'fingerGenPrint': '',
        'i_captcha': '',
      },
    );

    if (response.body.contains('二次认证')) {
      response = await _completeTwoFactor();
    }
    _ensureIdentityLoginSucceeded(response.body);
    await _finishIdentityRedirect(response.body);
    await _roamToInformationPortal();

    final result = AuthSession(
      userId: userId,
      fingerprint: fingerprint,
      cookies: Map<String, String>.unmodifiable(_cookieJar.legacyValues),
      scopedCookies: _cookieJar.cookies,
    );
    _session = result;
    await _sessionStore?.write(result);
    return result;
  }

  Future<void> logout() async {
    try {
      await _request(Uri.parse(_LOGOUT_URL));
    } finally {
      _cookieJar.clear();
      _session = null;
      await _sessionStore?.clear();
    }
  }

  Future<_Response> _completeTwoFactor() async {
    final methodHandler = twoFactorMethodHandler;
    final codeHandler = twoFactorCodeHandler;
    if (methodHandler == null || codeHandler == null) {
      throw StateError('Two-factor authentication is required.');
    }

    // The first request only describes the methods available for this account.
    // `thu-info` checks the result field before reading object; doing the same
    // prevents an unsuccessful response from becoming a misleading cast error.
    final approachesResponse = await _request(
      Uri.parse(_DOUBLE_AUTH_URL),
      method: 'POST',
      form: {'action': _TWO_FACTOR_FIND_APPROACHES},
    );
    final approaches = _decodeJsonObject(approachesResponse.body);
    _ensureTwoFactorSuccess(approaches, 'find available methods');
    final object = approaches['object'];
    if (object is! Map) {
      throw StateError(
        'The identity provider did not return two-factor methods.',
      );
    }
    final method = await methodHandler(
      TwoFactorOptions(
        hasWeChat: object['hasWeChatBool'] == true,
        phone: object['phone'] as String?,
        hasTotp: object['hasTotp'] == true,
      ),
    );
    trace?.call(
      '2FA methods: wechat=${object['hasWeChatBool'] == true}, '
      'mobile=${object['phone'] != null}, totp=${object['hasTotp'] == true}',
    );

    // Sending a code is a separate operation. It must succeed before the CLI
    // asks the user for a code; otherwise the user could enter a valid code
    // that was never requested by the server.
    final sendCode = _decodeJsonObject(
      (await _request(
        Uri.parse(_DOUBLE_AUTH_URL),
        method: 'POST',
        form: {'action': _TWO_FACTOR_SEND_CODE, 'type': method.name},
      )).body,
    );
    _ensureTwoFactorSuccess(sendCode, 'send the verification code');
    trace?.call('2FA verification code request succeeded.');

    // Let the input surface stay open while the user corrects the code. The
    // verifier rejects empty values locally and reports an unsuccessful
    // provider response as false; transport and decoding errors still throw.
    Map<String, dynamic>? verified;
    await codeHandler((code) async {
      if (code.trim().isEmpty) return false;

      final response = _decodeJsonObject(
        (await _request(
          Uri.parse(_DOUBLE_AUTH_URL),
          method: 'POST',
          form: {
            'action': method == TwoFactorMethod.totp
                ? _TWO_FACTOR_VERIFY_TOTP_CODE
                : _TWO_FACTOR_VERIFY_CODE,
            'vericode': code,
          },
        )).body,
      );
      if (response['result'] == _TWO_FACTOR_SUCCESS) {
        verified = response;
        trace?.call('2FA code verification succeeded.');
        return true;
      }

      // Only a well-formed server rejection reaches this branch. A caller can
      // keep its input surface open without treating network failures as a
      // rejected code.
      trace?.call('2FA code verification was rejected; requesting another.');
      return false;
    });
    if (verified == null) {
      throw StateError('Two-factor code entry ended before verification.');
    }
    final verifiedResponse = verified!;

    // The successful verification response places redirectUrl inside object,
    // as in the thu-info implementation. Keep the top-level fallback for
    // compatible identity-service deployments.
    final verifiedObject = verifiedResponse['object'];
    final redirect = verifiedObject is Map
        ? verifiedObject['redirectUrl'] as String?
        : verifiedResponse['redirectUrl'] as String?;
    if (redirect == null || redirect.isEmpty) {
      throw StateError(
        'The identity provider did not return a two-factor redirect.',
      );
    }
    final redirectUri = Uri.parse(redirect);
    return await _request(
      redirectUri.hasScheme
          ? redirectUri
          : Uri.parse(_ID_HOST_URL).resolveUri(redirectUri),
    );
  }

  Map<String, dynamic> _decodeJsonObject(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // Convert malformed server data into a stable authentication error.
    }
    throw StateError('The identity provider returned invalid two-factor data.');
  }

  void _ensureTwoFactorSuccess(
    Map<String, dynamic> response,
    String operation,
  ) {
    if (response['result'] != _TWO_FACTOR_SUCCESS) {
      throw StateError('The identity provider could not $operation.');
    }
  }

  Future<void> _finishIdentityRedirect(String body) async {
    // The identity provider returns a page containing several unrelated links
    // when authentication fails. The success marker is checked by
    // [_ensureIdentityLoginSucceeded] before this method is called, so this
    // anchor is now the login callback rather than a help-document link.
    final callback = _extract(body, r'''<a[^>]+href=["']([^"']+)["']''');
    if (callback == null || callback.isEmpty) {
      throw StateError('The identity login redirect was not found.');
    }
    final callbackUri = Uri.parse(callback);
    await _request(
      callbackUri.hasScheme
          ? callbackUri
          : Uri.parse(_ID_HOST_URL).resolveUri(callbackUri),
    );
  }

  void _ensureIdentityLoginSucceeded(String body) {
    // A failed login page contains links such as
    // `/res/pdf/SMRZ_guide_cn.pdf`. It must be treated as an authentication
    // error instead of being mistaken for the successful redirect anchor.
    if (!body.contains('登录成功。正在重定向到')) {
      throw StateError(
        'The identity provider rejected the credentials or login request.',
      );
    }
  }

  Future<void> _roamToInformationPortal() async {
    final response = await _request(
      Uri.parse('$_INFO_ROAMING_URL?yyfwid=$_INFO_ROAMING_ID&machine=p'),
    );
    final roamingUrl = _extract(
      response.body,
      r'''roamingurl["']?\s*[:=]\s*["']([^"']+)''',
    );
    if (roamingUrl != null) await _request(Uri.parse(roamingUrl));
  }

  Future<_Response> _request(
    Uri uri, {
    String method = 'GET',
    Map<String, String>? form,
  }) async {
    var current = uri;
    var currentMethod = method;
    var currentForm = form;
    for (var attempt = 0; attempt < 10; attempt++) {
      trace?.call(
        'HTTP $currentMethod ${current.host}${current.path} '
        'formKeys=${currentForm?.keys.join(',') ?? '-'} '
        'cookieNames=${_cookieJar.namesFor(current).join(',')}',
      );
      final request = http.Request(currentMethod, current)
        // The client handles redirects below so cookies from each intermediate
        // response are captured before the next request is constructed.
        ..followRedirects = false
        ..headers['User-Agent'] = _USER_AGENT
        ..headers['Cookie'] = _cookieJar.headerFor(current);
      if (currentForm != null) {
        request.headers['Content-Type'] = 'application/x-www-form-urlencoded';
        request.bodyFields = currentForm;
      }
      final response = await _http.send(request);
      final body = await response.stream.bytesToString();
      _cookieJar.capture(current, response.headers['set-cookie']);
      final location = response.headers['location'];
      trace?.call(
        'HTTP response status=${response.statusCode} '
        'location=${location == null ? '-' : 'present'} '
        'cookieNames=${_cookieJar.namesFor(current).join(',')}',
      );
      if (location == null ||
          response.statusCode < 300 ||
          response.statusCode >= 400) {
        return _Response(response.statusCode, response.headers, body);
      }
      current = current.resolveUri(Uri.parse(location));
      currentMethod =
          response.statusCode == 301 ||
              response.statusCode == 302 ||
              response.statusCode == 303
          ? 'GET'
          : currentMethod;
      currentForm = currentMethod == 'GET' ? null : currentForm;
    }
    throw StateError('Too many redirects during authentication.');
  }

  String? _extract(String input, String pattern) => RegExp(
    pattern,
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(input)?.group(1);
}

final class _Response {
  const _Response(this.statusCode, this.headers, this.body);

  /// HTTP status returned by the identity or WebVPN endpoint.
  final int statusCode;

  /// Response headers, retained for callers and redirect diagnostics.
  final Map<String, String> headers;

  /// Response body used to extract login callbacks and authentication data.
  final String body;
}
