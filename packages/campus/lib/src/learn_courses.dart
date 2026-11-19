part of '../thulium_campus.dart';

const _LEARN_ROAMING_ID = '3E401364BDD7AEA7EBF1EDE3F15ED4B7';
const _LEARN_HOST = 'learn.tsinghua.edu.cn';
const _LEARN_COURSES_PATH =
    '/b/wlxt/kc/v_wlkc_xs_xkb_kcb_extend/student/loadCourseBySemesterId';

/// Opens the learning platform through the information-portal roaming flow.
///
/// The roaming response establishes service-scoped cookies in the shared auth
/// client. Its CSRF token is taken from the returned page or the Learn cookie,
/// never from an unrelated information-portal XSRF-TOKEN cookie.
final class LearnPlatformSession {
  const LearnPlatformSession(this._authClient);

  final TsinghuaAuthClient _authClient;

  Future<String> open() => run((csrf) async => csrf);

  /// A failed Learn session does not establish that the university login died.
  /// Verify the main account, then re-roam Learn and retry the read once.
  Future<T> run<T>(Future<T> Function(String csrf) read) async {
    try {
      return await read(await _open());
    } on _LearnSessionExpired {
      _authClient.trace?.call(
        'Learn session rejected; verifying the main session.',
      );
      if (!await _authClient.validateSession()) {
        throw const PortalSessionRejected();
      }
      _authClient.trace?.call(
        'Main session verified; rebuilding Learn without a password.',
      );
      try {
        return await read(await _open());
      } on _LearnSessionExpired {
        throw StateError(
          'The learning platform session could not be established.',
        );
      }
    }
  }

  Future<String> _open() async {
    var landing = await _authClient.roamToPortalApp(_LEARN_ROAMING_ID);
    if (landing.statusCode == 404) {
      // Older roaming links can still point at the removed /student/index
      // route. Check the current course page to establish readiness.
      landing = await _authClient.getAuthenticated(
        TsinghuaWebVpnRedirect.forTarget(
          Uri.https(_LEARN_HOST, '/f/wlxt/index/course/student/'),
        ),
      );
    }
    final body = landing.body;
    if (_isLearnSignInResponse(
      landing.statusCode,
      landing.request?.url,
      body,
    )) {
      _authClient.traceUnexpectedResponse('learning-landing', landing);
      throw const _LearnSessionExpired();
    }
    if (landing.statusCode < 200 || landing.statusCode >= 300) {
      _authClient.traceUnexpectedResponse('learning-landing', landing);
      throw StateError(
        'The learning platform returned HTTP ${landing.statusCode}.',
      );
    }

    final document = html.parse(body);
    final field = document.querySelector('input[name="_csrf"]');
    final match = RegExp(
      r"""_csrf=([^&"'\s<>]+)|["']?_csrf["']?\s*[:=]\s*["']([^"'\s]+)["']|["']csrfToken["']\s*:\s*["']([^"']+)["']""",
    ).firstMatch(body);
    final pageToken =
        field?.attributes['value'] ??
        match?.group(1) ??
        match?.group(2) ??
        match?.group(3);
    if (pageToken != null && pageToken.isNotEmpty) return pageToken;

    // A successful roaming page can omit the token while setting the cookie.
    // Match only the Learn host; the portal uses the same cookie name.
    final cookies = _authClient.session?.scopedCookies ?? const <AuthCookie>[];
    for (final cookie in cookies.reversed) {
      final domain = cookie.domain.toLowerCase();
      if (cookie.name == 'XSRF-TOKEN' &&
          (_LEARN_HOST == domain || _LEARN_HOST.endsWith('.$domain')) &&
          cookie.value.isNotEmpty) {
        return cookie.value;
      }
    }
    _authClient.traceUnexpectedResponse('learning-landing', landing);
    throw const _LearnSessionExpired();
  }
}

/// Fetches the learning platform's semester course-list response unchanged.
///
/// This low-level API retains all response fields for CLI inspection. The
/// catalog service may cache its result separately from credential values.
final class LearnCourseService {
  const LearnCourseService(this._authClient, {this.now});

  final TsinghuaAuthClient _authClient;
  final DateTime Function()? now;

  Future<Map<String, dynamic>> fetchSemester(String semesterId) async {
    if (!RegExp(r'^\d{4}-\d{4}-[1-3]$').hasMatch(semesterId)) {
      throw ArgumentError.value(
        semesterId,
        'semesterId',
        'Invalid semester ID.',
      );
    }
    final session = _authClient.session;
    if (session == null) {
      throw StateError('Restore an authenticated session first.');
    }
    return LearnPlatformSession(_authClient).run((csrf) async {
      final target =
          Uri.https(_LEARN_HOST, '$_LEARN_COURSES_PATH/$semesterId/zh', {
            'timestamp': '${(now ?? DateTime.now)().millisecondsSinceEpoch}',
            '_csrf': csrf,
          });
      final response = await _authClient.getAuthenticated(
        TsinghuaWebVpnRedirect.forTarget(target),
      );
      if (_isLearnSignInResponse(
        response.statusCode,
        response.request?.url,
        response.body,
      )) {
        _authClient.traceUnexpectedResponse('learning-courses', response);
        throw const _LearnSessionExpired();
      }
      if (response.statusCode != 200) {
        _authClient.traceUnexpectedResponse('learning-courses', response);
        throw StateError(
          'The learning platform returned HTTP ${response.statusCode}.',
        );
      }

      Object? decoded;
      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        _authClient.traceUnexpectedResponse('learning-courses', response);
        throw const FormatException(
          'The learning platform did not return course-list JSON.',
        );
      }
      if (decoded is! Map<String, dynamic> ||
          decoded['message'] != 'success' ||
          decoded['resultList'] is! List ||
          (decoded['resultList'] as List).any((row) => row is! Map)) {
        _authClient.traceUnexpectedResponse('learning-courses', response);
        throw StateError(
          'The learning platform returned an unexpected course list.',
        );
      }
      if (decoded['currentUser'] != session.userId) {
        throw StateError('The learning platform returned a different account.');
      }
      return decoded;
    });
  }
}

final class _LearnSessionExpired implements Exception {
  const _LearnSessionExpired();
}

bool _isLearnSignInResponse(int statusCode, Uri? uri, String body) {
  if (statusCode == 401 ||
      uri?.host == 'id.tsinghua.edu.cn' ||
      (uri?.host == TsinghuaWebVpnRedirect.WEBVPN_HOST &&
          uri?.path == '/login') ||
      uri?.path.endsWith('/f/login') == true) {
    return true;
  }
  // Course JSON and gateway scripts can quote authentication markup without
  // being a login page. A bare 403 is a service/permission failure, not logout.
  try {
    jsonDecode(body);
    return false;
  } on FormatException {
    // Inspect actual HTML controls rather than document text or script strings.
  }
  final document = html.parse(body);
  for (final node in document.querySelectorAll(
    'script, style, template, noscript',
  )) {
    node.remove();
  }
  if (document.querySelector('#sm2publicKey, input[name="i_pass"]') != null) {
    return true;
  }
  return document
          .querySelectorAll('form')
          .any(
            (form) =>
                form.attributes['action']?.contains(
                  'j_spring_security_check',
                ) ==
                true,
          ) ||
      document.querySelectorAll('a, form').any((node) {
        final target =
            node.attributes['href'] ?? node.attributes['action'] ?? '';
        return target.contains('/f/login') ||
            target.contains('/do/off/ui/auth/login/') ||
            target.contains('oauth.tsinghua.edu.cn/thu-oauth/auth');
      });
}
