library;

export 'tsinghua_webvpn_redirect.dart';

// Thulium uses uppercase snake case for named constants across Dart and
// Flutter packages. This intentionally overrides the Dart style lint, which
// normally recommends lowerCamelCase for constants.
// ignore_for_file: constant_identifier_names

import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpDate, HttpException;

import 'package:dart_sm/dart_sm.dart';
import 'package:fast_gbk/fast_gbk.dart' as gbk_codec;
import 'package:http/http.dart' as http;

import 'src/response_diagnostics.dart';
import 'tsinghua_webvpn_redirect.dart';

// Entry point that starts the WebVPN OAuth flow and redirects to the identity
// provider. Keeping these endpoints in one place makes protocol updates easier
// to review and prevents URL fragments from being duplicated throughout the
// authentication client.
const _WEB_VPN_OAUTH_LOGIN_URL =
    '${TsinghuaWebVpnRedirect.WEBVPN_BASE_URL}/login?oauth_login=true';
const _USER_AGENT =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
    'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/79.0.3945.88 '
    'Safari/537.36';
const _ID_HOST_URL = 'https://id.tsinghua.edu.cn';
const _ID_LOGIN_FORM_URL = '$_ID_HOST_URL/do/off/ui/auth/login/form/';
const _ID_LOGIN_URL = '$_ID_HOST_URL/do/off/ui/auth/login/check';
const _OAUTH_REDIRECT_HOST = 'oauth.tsinghua.edu.cn';
const _DOUBLE_AUTH_URL = '$_ID_HOST_URL/b/doubleAuth/login';
const _SAVE_FINGER_URL = '$_ID_HOST_URL/b/doubleAuth/personal/saveFinger';
const _INFO_ROAMING_URL =
    '${TsinghuaWebVpnRedirect.WEBVPN_BASE_URL}'
    '${TsinghuaWebVpnRedirect.INFO_PORTAL_REDIRECT_PATH}'
    'b/yyfw/vyyfwxx/info/portal_fg/common/onlineAppRedirect';
const _INFO_ROAMING_ID = '10000ea055dd8d81d09d5a1ba55d39ad';
const _INFO_CSRF_COOKIE_URL =
    '${TsinghuaWebVpnRedirect.WEBVPN_BASE_URL}'
    '/wengine-vpn/cookie?method=get&host=info.tsinghua.edu.cn&scheme=https'
    '&path=/f/info/gxfw_fg/common/index';
const _INFO_USER_DATA_URL =
    '${TsinghuaWebVpnRedirect.WEBVPN_BASE_URL}'
    '${TsinghuaWebVpnRedirect.INFO_PORTAL_REDIRECT_PATH}'
    'b/info/gxfw_fg/common/grjbxx';
const _LOGOUT_URL = '${TsinghuaWebVpnRedirect.WEBVPN_BASE_URL}/logout';
const _TWO_FACTOR_SUCCESS = 'success';
const _TWO_FACTOR_FIND_APPROACHES = 'FIND_APPROACHES';
const _TWO_FACTOR_SEND_CODE = 'SEND_CODE';
const _TWO_FACTOR_VERIFY_CODE = 'VERITY_CODE';
const _TWO_FACTOR_VERIFY_TOTP_CODE = 'VERITY_TOTP_CODE';
const _COOKIE_DOMAIN_SUFFIX = 'tsinghua.edu.cn';
const _WEBVPN_INFRASTRUCTURE_COOKIE_NAMES = <String>{
  'wengine_vpn_ticket',
  'heartbeat',
  'refresh',
};
const _CSRF_FETCH_ATTEMPTS = 2;
const _CSRF_RETRY_DELAY = Duration(milliseconds: 200);

/// The WebVPN cookie endpoint did not supply a usable portal CSRF token.
/// This does not by itself prove that the saved identity session has expired.
final class PortalCsrfUnavailable implements Exception {
  const PortalCsrfUnavailable(this.message);

  final String message;

  @override
  String toString() => 'PortalCsrfUnavailable: $message';
}

/// An authenticated portal endpoint explicitly redirected to sign-in.
final class PortalSessionRejected implements Exception {
  const PortalSessionRejected();
}

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
    this.fingerGenPrint,
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

  /// Opaque trusted-device credential returned by the identity provider.
  /// This value is sensitive and must be persisted only through a secure store.
  final String? fingerGenPrint;

  /// Converts the session to a JSON-compatible map for secure persistence.
  Map<String, Object?> toJson() => {
    'userId': userId,
    'fingerprint': fingerprint,
    'cookies': cookies,
    'scopedCookies': scopedCookies.map((cookie) => cookie.toJson()).toList(),
    if (fingerGenPrint != null) 'fingerGenPrint': fingerGenPrint,
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
    fingerGenPrint: json['fingerGenPrint'] as String?,
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

  void capture(
    Uri origin,
    String? setCookieHeader, {
    bool Function(String name, String header)? shouldCapture,
  }) {
    if (setCookieHeader == null) return;

    // Some HTTP adapters combine repeated Set-Cookie headers. The comma in an
    // Expires date is not followed by a cookie-pair, so this splits only at
    // cookie boundaries while retaining the date value.
    final headers = setCookieHeader.split(RegExp(r',(?=\s*[^;,=]+=)'));
    for (final header in headers) {
      final normalized = header.trim();
      final separator = normalized.indexOf('=');
      if (separator <= 0) continue;
      final name = normalized.substring(0, separator).trim();
      if (shouldCapture == null || shouldCapture(name, normalized)) {
        _captureOne(origin, normalized);
      }
    }
    _removeExpired();
  }

  String headerFor(Uri uri) {
    return cookiesFor(
      uri,
    ).map((cookie) => '${cookie.name}=${cookie.value}').join('; ');
  }

  List<AuthCookie> cookiesFor(Uri uri) {
    _removeExpired();
    return _matching(uri);
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

/// Credentials are stored separately from cookies by a platform secret store.
///
/// A saved password is recoverable by this application so it can authenticate
/// again. The operating system's keyring protects it at rest; this does not
/// eliminate risk from a compromised account or unlocked device.
final class AuthCredentials {
  const AuthCredentials({required this.userId, required this.password});

  final String userId;
  final String password;
}

abstract interface class AuthCredentialStore {
  Future<AuthCredentials?> readCredentials();

  Future<void> writeCredentials(AuthCredentials credentials);

  Future<void> clearCredentials();
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

/// Asks whether the user wants this installation registered as a trusted device.
typedef TwoFactorTrustHandler = Future<bool> Function();

/// Receives safe authentication diagnostics without credential values.
typedef AuthTraceHandler = void Function(String message);

/// Implements the shared Tsinghua WebVPN and identity login flow.
final class TsinghuaAuthClient {
  TsinghuaAuthClient({
    http.Client? httpClient,
    AuthSessionStore? sessionStore,
    this.credentialStore,
    this.twoFactorMethodHandler,
    this.twoFactorCodeHandler,
    this.twoFactorTrustHandler,
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

  /// Optional secret store used for automatic credential-based reauthentication.
  final AuthCredentialStore? credentialStore;

  /// Called to choose a second-factor method before a code is sent.
  final TwoFactorMethodHandler? twoFactorMethodHandler;

  /// Called only after the selected second-factor code has been requested.
  final TwoFactorCodeHandler? twoFactorCodeHandler;

  /// Called after code verification to obtain explicit consent for device trust.
  final TwoFactorTrustHandler? twoFactorTrustHandler;

  /// Optional diagnostic callback. Messages contain no passwords, codes, or
  /// cookie values and are disabled by default.
  final AuthTraceHandler? trace;

  /// Reports a bounded, redacted preview only when a caller rejects a response.
  /// Full response bodies can contain service tickets and must not be logged.
  void traceUnexpectedResponse(String stage, http.Response response) {
    if (trace == null) return;
    try {
      trace!(
        describeUnexpectedResponse(
          stage: stage,
          statusCode: response.statusCode,
          uri: response.request?.url ?? Uri(),
          headers: response.headers,
          body: response.body,
        ),
      );
    } catch (_) {
      // Diagnostic output must never replace the original request failure.
    }
  }

  /// Cookies stay scoped to their originating host/path throughout the flow.
  final _CookieJar _cookieJar = _CookieJar();

  AuthSession? get session => _session;
  AuthSession? _session;
  String? _fingerGenPrint;

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

  /// Verifies restored cookies against the information portal.
  ///
  /// Call this after a protected portal request indicates an authentication
  /// failure, rather than on every application launch. Returns `false` and
  /// clears the persisted session only when the server explicitly rejects it
  /// or reports a different student ID. Network and unexpected-response errors
  /// are thrown so callers can distinguish outages from revoked sessions.
  Future<bool> validateSession() async {
    final session = _session;
    if (session == null) return false;

    final userId = await _fetchInformationPortalUserId();
    if (userId != session.userId) return _clearInvalidSession();
    await _persistSession();
    return true;
  }

  Future<String?> _fetchInformationPortalUserId() async {
    late final String csrf;
    try {
      csrf = await _portalCsrf();
    } on PortalSessionRejected {
      return null;
    }
    final userDataResponse = await _request(
      Uri.parse('$_INFO_USER_DATA_URL?_csrf=${Uri.encodeQueryComponent(csrf)}'),
    );
    if (_isLoginRequired(userDataResponse)) return null;

    Object? decoded;
    try {
      decoded = jsonDecode(userDataResponse.body);
    } on FormatException {
      _traceUnexpectedRawResponse('portal-user-data', userDataResponse);
      rethrow;
    }
    if (decoded is! Map<String, dynamic> || decoded['object'] is! Map) {
      _traceUnexpectedRawResponse('portal-user-data', userDataResponse);
      throw StateError(
        'The information portal user-data endpoint returned an unexpected '
        'JSON envelope (${_describeEnvelope(userDataResponse, decoded)}).',
      );
    }
    final userId = (decoded['object'] as Map)['ryh'];
    if (userId is! String) {
      throw StateError('The information portal omitted the student ID.');
    }
    return userId;
  }

  /// Sends an authenticated GET request while preserving scoped cookies.
  ///
  /// The response's redirect chain is followed manually so Set-Cookie headers
  /// are captured at each hop. Academic-calendar requests use the same WebVPN
  /// route as their roaming login; sending them directly would create a
  /// separate unauthenticated JSESSIONID and land on timeout.jsp. The updated
  /// cookie jar is persisted before this method returns.
  Future<http.Response> getAuthenticated(Uri uri) async {
    if (_session == null) {
      throw StateError(
        'Restore an authenticated session before making requests.',
      );
    }
    if (!_isTsinghuaHost(uri.host)) {
      throw ArgumentError.value(uri, 'uri', 'Only Tsinghua hosts are allowed.');
    }

    final requestUri =
        uri.host.toLowerCase() == TsinghuaWebVpnRedirect.ACADEMIC_CALENDAR_HOST
        ? TsinghuaWebVpnRedirect.forTarget(uri)
        : uri;
    final response = await _request(requestUri);
    await _persistSession();
    return _asTextResponse(response);
  }

  /// Establishes a WebVPN session for a campus service using its roaming ID.
  ///
  /// The returned response is the target service's landing page. Only the
  /// explicitly mapped Tsinghua service hosts are accepted, preventing a
  /// roaming response from directing authenticated cookies to an arbitrary
  /// host.
  Future<http.Response> roamToPortalApp(String roamingId) async {
    if (_session == null) {
      throw StateError('Restore an authenticated session before roaming.');
    }
    if (!RegExp(r'^[A-Fa-f0-9]+$').hasMatch(roamingId)) {
      throw ArgumentError.value(roamingId, 'roamingId');
    }

    final csrfToken = await _portalCsrf();
    final roamingResponse = await _request(
      Uri.parse(_INFO_ROAMING_URL).replace(
        queryParameters: {
          'yyfwid': roamingId,
          '_csrf': csrfToken,
          'machine': 'p',
        },
      ),
    );
    Object? roamingJson;
    try {
      roamingJson = jsonDecode(roamingResponse.body);
    } on FormatException {
      _traceUnexpectedRawResponse('portal-roaming', roamingResponse);
      rethrow;
    }
    if (roamingJson is! Map<String, dynamic> || roamingJson['object'] is! Map) {
      _traceUnexpectedRawResponse('portal-roaming', roamingResponse);
      throw StateError(
        'The information portal roaming endpoint returned an unexpected '
        'JSON envelope (${_describeEnvelope(roamingResponse, roamingJson)}).',
      );
    }
    final rawTarget = (roamingJson['object'] as Map)['roamingurl'];
    if (rawTarget is! String || rawTarget.isEmpty) {
      _traceUnexpectedRawResponse('portal-roaming', roamingResponse);
      throw StateError('The information portal omitted the roaming URL.');
    }

    final target = _webVpnProxyUri(
      Uri.parse(rawTarget.replaceAll('&amp;', '&')),
    );
    final response = await _request(target);
    await _persistSession();
    return _asTextResponse(response);
  }

  http.Response _asTextResponse(_Response response) {
    // The body has already been decoded from the remote charset. Label the
    // re-encoded response as UTF-8 so package:http does not encode it as
    // Latin-1 when a campus page omitted its charset declaration.
    final headers = Map<String, String>.from(response.headers)
      ..remove('content-length');
    final mediaType = headers['content-type']?.split(';').first.trim();
    headers['content-type'] =
        '${mediaType == null || mediaType.isEmpty ? 'text/plain' : mediaType}; '
        'charset=utf-8';
    return http.Response(
      response.body,
      response.statusCode,
      request: http.Request('GET', response.uri),
      headers: headers,
    );
  }

  String _readInformationPortalCsrf(_Response response) {
    // The WebVPN cookie endpoint returns a cookie string in its response body,
    // not in Set-Cookie. OneTHU imports that string into its jar before using
    // the target service. Keep each imported cookie scoped to the service that
    // owns it; WebVPN infrastructure cookies remain with the proxy host.
    final pairs = <String, String>{};
    if (response.statusCode == 200 && !response.body.contains('<')) {
      for (final part in response.body.split(RegExp(r'[;\r\n]'))) {
        final separator = part.indexOf('=');
        if (separator <= 0) continue;
        final name = part.substring(0, separator).trim();
        final value = part.substring(separator + 1).trim();
        if (!RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(name) ||
            const {
              'path',
              'domain',
              'expires',
              'max-age',
              'samesite',
            }.contains(name.toLowerCase())) {
          continue;
        }
        pairs[name] = value;
      }
    }

    final csrf = pairs['XSRF-TOKEN'];
    if (csrf == null || csrf.isEmpty) {
      _traceUnexpectedRawResponse('portal-csrf-cookie', response);
      final kind = response.body.trim().isEmpty
          ? 'empty'
          : response.body.trimLeft().startsWith('<')
          ? 'html'
          : response.body.trimLeft().startsWith('{')
          ? 'json'
          : 'other';
      throw PortalCsrfUnavailable(
        'The information portal did not return a CSRF token '
        '(HTTP ${response.statusCode}, path=${response.uri.path}, '
        'bodyType=$kind, bodyLength=${response.body.length}).',
      );
    }

    final infoOrigin = Uri.parse('https://info.tsinghua.edu.cn/');
    final webVpnOrigin = Uri.parse(TsinghuaWebVpnRedirect.WEBVPN_BASE_URL);
    for (final entry in pairs.entries) {
      final origin = _isWebVpnInfrastructureCookie(entry.key)
          ? webVpnOrigin
          : infoOrigin;
      _cookieJar.capture(origin, '${entry.key}=${entry.value}; Path=/; Secure');
    }
    trace?.call(
      'Information-portal cookie bundle imported: names=${pairs.keys.join(',')}',
    );
    return csrf;
  }

  Future<String> _portalCsrf() async {
    PortalCsrfUnavailable? lastFailure;
    for (var attempt = 0; attempt < _CSRF_FETCH_ATTEMPTS; attempt++) {
      final response = await _request(Uri.parse(_INFO_CSRF_COOKIE_URL));
      if (_isLoginRequired(response)) throw const PortalSessionRejected();
      try {
        return _readInformationPortalCsrf(response);
      } on PortalCsrfUnavailable catch (error) {
        lastFailure = error;
        if (attempt + 1 < _CSRF_FETCH_ATTEMPTS) {
          await Future<void>.delayed(_CSRF_RETRY_DELAY);
        }
      }
    }

    // An empty cookie-dance response can be transient. Reuse a scoped token
    // only after the authenticated user-data endpoint confirms its account.
    final cached = _cachedPortalCsrf();
    if (cached != null && await _probePortalCsrf(cached)) {
      trace?.call('A stored portal CSRF token passed the account probe.');
      return cached;
    }

    await _trySilentPortalReconnect();
    final response = await _request(Uri.parse(_INFO_CSRF_COOKIE_URL));
    if (_isLoginRequired(response)) throw const PortalSessionRejected();
    try {
      final token = _readInformationPortalCsrf(response);
      if (_session == null || await _probePortalCsrf(token)) return token;
      throw const PortalCsrfUnavailable(
        'The reconnected portal token could not be verified for this account.',
      );
    } on PortalCsrfUnavailable catch (error) {
      lastFailure = error;
    }
    final refreshed = _cachedPortalCsrf();
    if (refreshed != null && await _probePortalCsrf(refreshed)) {
      trace?.call('The portal CSRF token remained usable after reconnect.');
      return refreshed;
    }
    throw lastFailure;
  }

  String? _cachedPortalCsrf() {
    final origin = Uri.parse('https://info.tsinghua.edu.cn/');
    for (final cookie in _cookieJar.cookiesFor(origin)) {
      if (cookie.name == 'XSRF-TOKEN' && cookie.value.isNotEmpty) {
        return cookie.value;
      }
    }
    return null;
  }

  Future<bool> _probePortalCsrf(String token) async {
    final userId = _session?.userId;
    if (userId == null) return false;
    try {
      final response = await _request(
        Uri.parse(
          '$_INFO_USER_DATA_URL?_csrf=${Uri.encodeQueryComponent(token)}',
        ),
      );
      if (_isLoginRequired(response)) return false;
      final data = jsonDecode(response.body);
      return data is Map &&
          data['object'] is Map &&
          (data['object'] as Map)['ryh'] == userId;
    } catch (_) {
      // An inconclusive probe cannot turn a cached token into trusted state.
      return false;
    }
  }

  Future<void> _trySilentPortalReconnect() async {
    if (_session == null) return;
    try {
      trace?.call('Trying portal reconnection with the saved SSO cookies.');
      await _request(Uri.parse(_WEB_VPN_OAUTH_LOGIN_URL));
      final portal = await _request(
        Uri.parse('$_ID_LOGIN_FORM_URL$_INFO_ROAMING_ID'),
      );
      if (portal.body.contains('登录成功。正在重定向到')) {
        await _finishIdentityRedirect(portal.body, throughWebVpnOAuth: true);
      }
    } catch (_) {
      // Existing SSO cookies may be expired. The CLI can request credentials
      // interactively, but this shared library must never invent a password.
      trace?.call('Silent portal reconnection did not complete.');
    }
  }

  void _traceUnexpectedRawResponse(String stage, _Response response) {
    if (trace == null) return;
    try {
      trace!(
        describeUnexpectedResponse(
          stage: stage,
          statusCode: response.statusCode,
          uri: response.uri,
          headers: response.headers,
          body: response.body,
        ),
      );
    } catch (_) {
      // Diagnostic output must never replace the original request failure.
    }
  }

  String _describeEnvelope(_Response response, Object? decoded) {
    if (decoded is! Map) {
      return 'HTTP ${response.statusCode}, JSON type '
          '${decoded?.runtimeType ?? 'null'}';
    }
    final keys = decoded.keys
        .map((key) => key.toString())
        .where((key) => RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(key))
        .join(',');
    final result = decoded['result'];
    final safeResult =
        result is String && RegExp(r'^[A-Za-z0-9_.-]{1,32}$').hasMatch(result)
        ? ', result=$result'
        : '';
    final objectType = decoded['object']?.runtimeType ?? 'null';
    return 'HTTP ${response.statusCode}, keys=[$keys]$safeResult, '
        'objectType=$objectType';
  }

  bool _isTsinghuaHost(String host) =>
      host == _COOKIE_DOMAIN_SUFFIX || host.endsWith('.$_COOKIE_DOMAIN_SUFFIX');

  Uri _webVpnProxyUri(Uri target) {
    if (target.host == TsinghuaWebVpnRedirect.WEBVPN_HOST) return target;
    return TsinghuaWebVpnRedirect.forTarget(target);
  }

  Future<void> _persistSession() async {
    final current = _session;
    if (current == null) return;
    final updated = AuthSession(
      userId: current.userId,
      fingerprint: current.fingerprint,
      cookies: Map<String, String>.unmodifiable(_cookieJar.legacyValues),
      scopedCookies: _cookieJar.cookies,
      fingerGenPrint: current.fingerGenPrint,
    );
    _session = updated;
    await _sessionStore?.write(updated);
  }

  bool _isLoginRequired(_Response response) =>
      response.statusCode == 401 ||
      response.statusCode == 403 ||
      response.uri.path.startsWith('/wengine-vpn/failed') ||
      response.uri.host == Uri.parse(_ID_HOST_URL).host ||
      response.body.contains('sm2publicKey');

  Future<bool> _clearInvalidSession() async {
    _cookieJar.clear();
    _session = null;
    _fingerGenPrint = null;
    await _sessionStore?.clear();
    return false;
  }

  /// Logs in and persists cookies plus an optional trusted-device token.
  Future<AuthSession> login({
    required String userId,
    required String password,
    required String fingerprint,
  }) async {
    if (!RegExp(r'^\d+$').hasMatch(userId)) {
      throw const FormatException('The user ID must contain only digits.');
    }

    // Reuse a trusted-device credential only when both its account and stable
    // fingerprint match this login.
    final previousSession = _session ?? await _sessionStore?.read();
    _fingerGenPrint =
        previousSession != null &&
            previousSession.userId == userId &&
            previousSession.fingerprint == fingerprint
        ? previousSession.fingerGenPrint
        : null;
    // The old account must not be used to probe or silently renew the portal
    // while a new credential-based login is establishing its own session.
    _session = null;
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
        'fingerGenPrint': _fingerGenPrint ?? '',
        'i_captcha': '',
      },
    );

    if (response.body.contains('二次认证')) {
      response = await _completeTwoFactor(fingerprint: fingerprint);
    }
    _ensureIdentityLoginSucceeded(response.body);
    await _finishIdentityRedirect(response.body);
    await _roamToInformationPortal(
      userId: userId,
      password: password,
      fingerprint: fingerprint,
    );

    // A CAS success page only proves that the identity provider accepted the
    // credentials. Confirm the subsequent portal ticket was redeemed for this
    // account before saving a session that the app or CLI will later restore.
    if (await _fetchInformationPortalUserId() != userId) {
      throw StateError('The information portal session was not established.');
    }

    final result = AuthSession(
      userId: userId,
      fingerprint: fingerprint,
      cookies: Map<String, String>.unmodifiable(_cookieJar.legacyValues),
      scopedCookies: _cookieJar.cookies,
      fingerGenPrint: _fingerGenPrint,
    );
    _session = result;
    await _sessionStore?.write(result);
    await credentialStore?.writeCredentials(
      AuthCredentials(userId: userId, password: password),
    );
    return result;
  }

  Future<void> logout() async {
    try {
      await _request(Uri.parse(_LOGOUT_URL));
    } finally {
      _cookieJar.clear();
      _session = null;
      _fingerGenPrint = null;
      try {
        await _sessionStore?.clear();
      } finally {
        // A session-store failure must not leave a reusable password behind
        // after the user explicitly requested logout.
        await credentialStore?.clearCredentials();
      }
    }
  }

  Future<_Response> _completeTwoFactor({required String fingerprint}) async {
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

    // Match the upstream trust-device flow: only register after explicit user
    // consent, then retain the returned finger3 for the next CAS service stage.
    if (await (twoFactorTrustHandler?.call() ?? Future<bool>.value(false))) {
      await _saveTrustedDevice(fingerprint);
    }

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

  Future<void> _saveTrustedDevice(String fingerprint) async {
    try {
      final response = _decodeJsonObject(
        (await _request(
          Uri.parse(_SAVE_FINGER_URL),
          method: 'POST',
          form: {
            'fingerprint': fingerprint,
            'deviceName': 'Thulium',
            'radioVal': '是',
          },
        )).body,
      );
      if (response['result'] != _TWO_FACTOR_SUCCESS) {
        trace?.call('Trusted-device registration was not accepted.');
        return;
      }
      final token = response['object'];
      if (token is String && token.isNotEmpty) {
        _fingerGenPrint = token;
        trace?.call('Trusted-device credential received.');
      } else {
        trace?.call('Trusted-device registration returned no credential.');
      }
    } catch (_) {
      // Device trust is optional; its failure must not invalidate successful
      // credential and second-factor verification.
      trace?.call('Trusted-device registration failed; continuing login.');
    }
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

  Future<void> _finishIdentityRedirect(
    String body, {
    bool throughWebVpnOAuth = false,
  }) async {
    // The identity provider returns a page containing several unrelated links
    // when authentication fails. The success marker is checked by
    // [_ensureIdentityLoginSucceeded] before this method is called, so this
    // anchor is now the login callback rather than a help-document link.
    final callback = _extract(body, r'''<a[^>]+href=["']([^"']+)["']''');
    if (callback == null || callback.isEmpty) {
      throw StateError('The identity login redirect was not found.');
    }
    final callbackUri = Uri.parse(callback);
    final target = callbackUri.hasScheme
        ? callbackUri
        : Uri.parse(_ID_HOST_URL).resolveUri(callbackUri);
    final result = await _request(
      throughWebVpnOAuth ? _webVpnOAuthRedirectUri(target) : target,
    );
    if (result.uri.path.startsWith('/wengine-vpn/failed')) {
      throw StateError('The WebVPN service ticket could not be redeemed.');
    }
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

  Future<void> _roamToInformationPortal({
    required String userId,
    required String password,
    required String fingerprint,
  }) async {
    // thu-info signs into the information-portal app through the identity
    // provider after the initial WebVPN login. A generic WebVPN app redirect
    // alone does not establish the per-app identity session required by the
    // profile and app-roaming endpoints.
    final loginPage = await _request(
      Uri.parse('$_ID_LOGIN_FORM_URL$_INFO_ROAMING_ID'),
    );
    final publicKey = _extract(
      loginPage.body,
      'id="sm2publicKey"[^>]*>([^<]+)',
    );
    if (publicKey == null || publicKey.isEmpty) {
      throw StateError(
        'The information-portal identity public key was not found.',
      );
    }

    var response = await _request(
      Uri.parse(_ID_LOGIN_URL),
      method: 'POST',
      form: {
        'i_user': userId,
        'i_pass': '04${SM2.encrypt(password, publicKey)}',
        'fingerPrint': fingerprint,
        'fingerGenPrint': _fingerGenPrint ?? '',
        'i_captcha': '',
      },
    );
    if (response.body.contains('二次认证')) {
      response = await _completeTwoFactor(fingerprint: fingerprint);
    }
    _ensureIdentityLoginSucceeded(response.body);
    await _finishIdentityRedirect(response.body, throughWebVpnOAuth: true);
  }

  Uri _webVpnOAuthRedirectUri(Uri target) {
    if (target.host == _OAUTH_REDIRECT_HOST) return target;
    final port = target.hasPort
        ? target.port
        : target.scheme == 'https'
        ? 443
        : 80;
    final targetPath = StringBuffer(target.path);
    if (target.hasQuery) targetPath.write('?${target.query}');
    if (target.hasFragment) targetPath.write('#${target.fragment}');
    // Match thu-info's getWebVPNUrl: the identity callback path and its query
    // are forwarded as a raw uri parameter to lbredirect. Encoding the whole
    // value as a query component makes WebVPN receive a %2F-encoded path.
    return Uri.parse(
      'https://$_OAUTH_REDIRECT_HOST/lb-auth/lbredirect?'
      'scheme=${target.scheme}&host=${target.host}&port=$port&'
      'uri=$targetPath',
    );
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
        'HTTP $currentMethod ${current.host}${_safeTracePath(current)} '
        'formKeys=${currentForm?.keys.join(',') ?? '-'} '
        'cookieNames=${_cookieNamesForRequest(current).join(',')}',
      );
      final request = http.Request(currentMethod, current)
        // The client handles redirects below so cookies from each intermediate
        // response are captured before the next request is constructed.
        ..followRedirects = false
        ..headers['User-Agent'] = _USER_AGENT
        ..headers['Cookie'] = _cookieHeaderForRequest(current);
      if (currentForm != null) {
        request.headers['Content-Type'] = 'application/x-www-form-urlencoded';
        request.bodyFields = currentForm;
      }
      final response = await _http.send(request);
      final body = _decodeResponseBody(
        await response.stream.toBytes(),
        response.headers['content-type'],
        current,
      );
      _captureResponseCookies(current, response.headers['set-cookie']);
      final location = response.headers['location'];
      trace?.call(
        'HTTP response status=${response.statusCode} '
        'location=${location == null ? '-' : 'present'} '
        'cookieNames=${_cookieNamesForRequest(current).join(',')}',
      );
      if (location == null ||
          response.statusCode < 300 ||
          response.statusCode >= 400) {
        return _Response(response.statusCode, response.headers, body, current);
      }
      final redirected = current.resolveUri(Uri.parse(location));
      // The academic calendar can redirect to an absolute origin URL. Keep
      // that hop in the same WebVPN session as the original calendar request.
      current =
          redirected.host.toLowerCase() ==
              TsinghuaWebVpnRedirect.ACADEMIC_CALENDAR_HOST
          ? TsinghuaWebVpnRedirect.forTarget(redirected)
          : redirected;
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

  String _decodeResponseBody(List<int> bytes, String? contentType, Uri uri) {
    final declaredCharset = RegExp(
      r'''charset\s*=\s*["']?([^;\s"']+)''',
      caseSensitive: false,
    ).firstMatch(contentType ?? '')?.group(1)?.toLowerCase();
    final isGbk = switch (declaredCharset) {
      'gbk' || 'gb2312' || 'gb18030' || 'cp936' => true,
      _ => false,
    };
    if (isGbk) return gbk_codec.gbk.decode(bytes);
    if (declaredCharset == 'iso-8859-1' || declaredCharset == 'latin1') {
      return latin1.decode(bytes);
    }

    try {
      return utf8.decode(bytes);
    } on FormatException {
      // Some older campus pages omit a charset even though the body is GBK.
      // Their redirect links remain ASCII, but decoding as UTF-8 would fail
      // before the authentication flow can follow those links.
      trace?.call(
        'Response is not UTF-8; decoding as GBK for '
        '${uri.host}${_safeTracePath(uri)} '
        '(contentType=${contentType ?? '-'}).',
      );
      return gbk_codec.gbk.decode(bytes);
    }
  }

  String _safeTracePath(Uri uri) => uri.path.replaceAll(
    RegExp(r';jsessionid=[^/;]+', caseSensitive: false),
    ';jsessionid=[redacted]',
  );

  /// Combines proxy cookies with cookies scoped to the encoded service URL.
  /// Service cookies take precedence when names collide.
  String _cookieHeaderForRequest(Uri requestUri) {
    final serviceUri = TsinghuaWebVpnRedirect.originalTarget(requestUri);
    if (serviceUri == null) return _cookieJar.headerFor(requestUri);

    final cookies = <String, AuthCookie>{};
    for (final cookie in _cookieJar.cookiesFor(serviceUri)) {
      cookies[cookie.name] = cookie;
    }
    for (final cookie in _cookieJar.cookiesFor(requestUri)) {
      cookies.putIfAbsent(cookie.name, () => cookie);
    }
    return cookies.values
        .map((cookie) => '${cookie.name}=${cookie.value}')
        .join('; ');
  }

  List<String> _cookieNamesForRequest(Uri requestUri) =>
      _cookieHeaderForRequest(requestUri)
          .split(';')
          .map((cookie) => cookie.trim().split('=').first)
          .where((name) => name.isNotEmpty)
          .toList(growable: false);

  /// Keeps proxied service cookies in the original host's bucket, while
  /// retaining WebVPN infrastructure cookies under the proxy host.
  void _captureResponseCookies(Uri requestUri, String? setCookieHeader) {
    final serviceUri = TsinghuaWebVpnRedirect.originalTarget(requestUri);
    if (serviceUri == null) {
      _cookieJar.capture(requestUri, setCookieHeader);
      return;
    }

    _cookieJar.capture(
      requestUri,
      setCookieHeader,
      shouldCapture: (name, header) {
        final domain = _declaredCookieDomain(header);
        return _isWebVpnInfrastructureCookie(name) ||
            (domain != null && _cookieDomainMatches(requestUri.host, domain));
      },
    );
    _cookieJar.capture(
      serviceUri,
      setCookieHeader,
      shouldCapture: (name, header) {
        if (_isWebVpnInfrastructureCookie(name)) return false;
        final domain = _declaredCookieDomain(header);
        if (domain != null) {
          return _cookieDomainMatches(serviceUri.host, domain);
        }
        return true;
      },
    );
  }

  String? _declaredCookieDomain(String setCookieHeader) {
    for (final attribute in setCookieHeader.split(';').skip(1)) {
      final separator = attribute.indexOf('=');
      if (separator < 0 ||
          attribute.substring(0, separator).trim().toLowerCase() != 'domain') {
        continue;
      }
      return attribute
          .substring(separator + 1)
          .trim()
          .toLowerCase()
          .replaceFirst(RegExp(r'^\.'), '');
    }
    return null;
  }

  bool _cookieDomainMatches(String host, String domain) =>
      host == domain || host.endsWith('.$domain');

  bool _isWebVpnInfrastructureCookie(String name) {
    final normalized = name.toLowerCase();
    return _WEBVPN_INFRASTRUCTURE_COOKIE_NAMES.contains(normalized) ||
        normalized.startsWith('show_');
  }

  String? _extract(String input, String pattern) => RegExp(
    pattern,
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(input)?.group(1);
}

final class _Response {
  const _Response(this.statusCode, this.headers, this.body, this.uri);

  /// HTTP status returned by the identity or WebVPN endpoint.
  final int statusCode;

  /// Response headers, retained for callers and redirect diagnostics.
  final Map<String, String> headers;

  /// Response body used to extract login callbacks and authentication data.
  final String body;

  /// Final URL after manually following redirects.
  final Uri uri;
}
