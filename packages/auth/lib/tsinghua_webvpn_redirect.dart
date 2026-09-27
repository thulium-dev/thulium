// Thulium uses uppercase snake case for named constants across Dart and
// Flutter packages. This intentionally overrides the Dart style lint.
// ignore_for_file: constant_identifier_names

/// Centralized WebVPN redirect paths and service mappings used by Thulium.
///
/// The route identifiers come from the WebVPN resource list. Keeping them in
/// one place makes service URLs easier to audit and update when Tsinghua
/// changes its published redirects.
abstract final class TsinghuaWebVpnRedirect {
  static const WEBVPN_HOST = 'webvpn.tsinghua.edu.cn';
  static const WEBVPN_BASE_URL = 'https://$WEBVPN_HOST';
  static const ACADEMIC_CALENDAR_HOST = 'zhjw.cic.tsinghua.edu.cn';
  static const ACADEMIC_CALENDAR_BASE_URL = 'http://$ACADEMIC_CALENDAR_HOST';

  static const INFO_PORTAL_IDENTIFIER =
      '77726476706e69737468656265737421f9f9479369247b59700f81b9991b2631506205de';
  static const COURSE_SELECTION_IDENTIFIER =
      '77726476706e69737468656265737421eaff4b8b3f3b2653770bc7b88b5c2d320506b1aec738590a49ba';
  static const COURSE_REGISTRATION_IDENTIFIER =
      '77726476706e69737468656265737421eaff4b8b3f3b7147300b80afd641303c5604246e26445320beb0ce87';
  static const OLD_INFO_PORTAL_IDENTIFIER =
      '77726476706e69737468656265737421fffb45952936671e6a1b80a29f5d3634e5cdcd7ed98227';
  static const HR_SERVICE_HALL_IDENTIFIER =
      '77726476706e69737468656265737421f8e50f8834396657761d88e29d51367bb531';
  static const SSLVPN_DOWNLOAD_IDENTIFIER =
      '77726476706e69737468656265737421f4f24f8569247b59700f81b9991b263147c0eb57';
  static const CAMPUS_NETWORK_IDENTIFIER =
      '77726476706e69737468656265737421e5e4448e223726446d0187ab9040227b54b6c80fcd73';
  static const BASTION_1_IDENTIFIER =
      '77726476706e69737468656265737421a1a117d27661391e2c59c7fec00f72662b4189';

  // These two routes predate the supplied resource list and are retained for
  // existing learning-platform and academic-calendar API requests.
  static const LEARNING_PLATFORM_IDENTIFIER =
      '77726476706e69737468656265737421fcf2408e297e7c4377068ea48d546d30ca8cc97bcc';
  static const ACADEMIC_CALENDAR_IDENTIFIER =
      '77726476706e69737468656265737421eaff4b8b69336153301c9aa596522b20bc86e6e559a9b290';

  static const INFO_PORTAL_REDIRECT_PATH = '/https/$INFO_PORTAL_IDENTIFIER/';
  static const COURSE_SELECTION_REDIRECT_PATH =
      '/http/$COURSE_SELECTION_IDENTIFIER/xklogin.do';
  static const COURSE_REGISTRATION_REDIRECT_PATH =
      '/https/$COURSE_REGISTRATION_IDENTIFIER/xklogin.do';
  static const OLD_INFO_PORTAL_REDIRECT_PATH =
      '/http/$OLD_INFO_PORTAL_IDENTIFIER/';
  static const HR_SERVICE_HALL_REDIRECT_PATH =
      '/https/$HR_SERVICE_HALL_IDENTIFIER/';
  static const SSLVPN_DOWNLOAD_REDIRECT_PATH =
      '/https/$SSLVPN_DOWNLOAD_IDENTIFIER/';
  static const CAMPUS_NETWORK_REDIRECT_PATH =
      '/https/$CAMPUS_NETWORK_IDENTIFIER/';
  static const BASTION_1_REDIRECT_PATH = '/ssh/$BASTION_1_IDENTIFIER/';
  static const LEARNING_PLATFORM_REDIRECT_PATH =
      '/https/$LEARNING_PLATFORM_IDENTIFIER/';
  static const ACADEMIC_CALENDAR_REDIRECT_PATH =
      '/http/$ACADEMIC_CALENDAR_IDENTIFIER/';

  static const _HOST_IDENTIFIERS = <String, String>{
    'info': INFO_PORTAL_IDENTIFIER,
    'zhjwxk.cic': COURSE_SELECTION_IDENTIFIER,
    'zhjwxkyw.cic': COURSE_REGISTRATION_IDENTIFIER,
    'oldinfo': OLD_INFO_PORTAL_IDENTIFIER,
    'hr': HR_SERVICE_HALL_IDENTIFIER,
    'deny': SSLVPN_DOWNLOAD_IDENTIFIER,
    'usereg': CAMPUS_NETWORK_IDENTIFIER,
    'learn': LEARNING_PLATFORM_IDENTIFIER,
    'zhjw.cic': ACADEMIC_CALENDAR_IDENTIFIER,
  };

  /// Converts a supported Tsinghua service URL into its WebVPN proxy URL.
  ///
  /// The target's scheme, non-default port, path, query, and fragment are
  /// preserved according to WebVPN's redirect URL format. Unsupported hosts
  /// and non-HTTP schemes are rejected rather than receiving a guessed route.
  static Uri forTarget(Uri target) {
    if (target.scheme != 'http' && target.scheme != 'https') {
      throw ArgumentError.value(
        target,
        'target',
        'Only HTTP and HTTPS Tsinghua service URLs can be proxied.',
      );
    }

    final host = target.host.toLowerCase();
    final alias = host.endsWith('.tsinghua.edu.cn')
        ? host.substring(0, host.length - '.tsinghua.edu.cn'.length)
        : host;
    final identifier = _HOST_IDENTIFIERS[alias];
    if (identifier == null) {
      throw ArgumentError.value(
        target,
        'target',
        'No WebVPN route is configured for ${target.host}.',
      );
    }

    final defaultPort = target.scheme == 'https' ? 443 : 80;
    final protocol = target.port == defaultPort || target.port == 0
        ? target.scheme
        : '${target.scheme}-${target.port}';
    final targetPath = target.path.startsWith('/')
        ? target.path
        : '/${target.path}';
    final path = '/$protocol/$identifier$targetPath';
    final proxy = Uri.https(
      WEBVPN_HOST,
      path,
      target.queryParameters.isEmpty ? null : target.queryParameters,
    );
    return target.hasFragment
        ? proxy.replace(fragment: target.fragment)
        : proxy;
  }

  /// Recovers the original service URL represented by a WebVPN proxy URL.
  ///
  /// WebVPN responses can contain service cookies while their visible request
  /// URL belongs to the proxy host. Returning the original URL lets the auth
  /// client keep those cookies scoped to the service that issued them.
  static Uri? originalTarget(Uri proxy) {
    if (proxy.host.toLowerCase() != WEBVPN_HOST) return null;

    final match = RegExp(
      r'^/(https?)(?:-(\d+))?/([A-Fa-f0-9]+)/?(.*)$',
    ).firstMatch(proxy.path);
    if (match == null) return null;

    final scheme = match.group(1)!;
    final port = int.tryParse(match.group(2) ?? '');
    final identifier = match.group(3)!.toLowerCase();
    String? host;
    for (final entry in _HOST_IDENTIFIERS.entries) {
      if (entry.value.toLowerCase() == identifier) {
        host = '${entry.key}.tsinghua.edu.cn';
        break;
      }
    }
    if (host == null) return null;

    final targetPath = match.group(4)!;
    return Uri(
      scheme: scheme,
      host: host,
      port: port,
      path: targetPath.isEmpty ? '/' : '/$targetPath',
      query: proxy.hasQuery ? proxy.query : null,
      fragment: proxy.hasFragment ? proxy.fragment : null,
    );
  }
}
