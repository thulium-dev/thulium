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

  Future<String> open() async {
    final landing = await _authClient.roamToPortalApp(_LEARN_ROAMING_ID);
    final body = landing.body;
    if (landing.statusCode == 401 ||
        landing.statusCode == 403 ||
        body.toLowerCase().contains('sm2publickey')) {
      _authClient.traceUnexpectedResponse('learning-landing', landing);
      throw const PortalSessionRejected();
    }
    if (landing.statusCode < 200 || landing.statusCode >= 300) {
      _authClient.traceUnexpectedResponse('learning-landing', landing);
      throw StateError(
        'The learning platform returned HTTP ${landing.statusCode}.',
      );
    }

    final match = RegExp(
      r"""_csrf=([\w-]+)|name=["']_csrf["'][^>]*value=["']([\w-]+)""",
      caseSensitive: false,
    ).firstMatch(body);
    final pageToken = match?.group(1) ?? match?.group(2);
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
    throw const FormatException(
      'The learning platform did not return a CSRF token.',
    );
  }
}

/// Fetches the learning platform's semester course-list response unchanged.
///
/// This diagnostic API intentionally retains all response fields for CLI
/// inspection. It does not persist the course list or any credential values.
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
    final csrf = await LearnPlatformSession(_authClient).open();
    final target =
        Uri.https(_LEARN_HOST, '$_LEARN_COURSES_PATH/$semesterId/zh', {
          'timestamp': '${(now ?? DateTime.now)().millisecondsSinceEpoch}',
          '_csrf': csrf,
        });
    final response = await _authClient.getAuthenticated(
      TsinghuaWebVpnRedirect.forTarget(target),
    );
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
  }
}
