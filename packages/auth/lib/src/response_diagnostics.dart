// Response diagnostics minimize accidental disclosure. They never include
// query strings, request headers, raw HTML attributes, or full bodies. Users
// should still review previews before sharing logs externally.
// ignore_for_file: constant_identifier_names

const _MAX_INSPECTED_BODY_LENGTH = 8192;
const _MAX_PREVIEW_LENGTH = 220;

String describeUnexpectedResponse({
  required String stage,
  required int statusCode,
  required Uri uri,
  required Map<String, String> headers,
  required String body,
}) {
  final rawContentType =
      headers['content-type']?.split(';').first.trim() ?? '-';
  final contentType = RegExp(r'^[\w.+-]+/[\w.+-]+$').hasMatch(rawContentType)
      ? rawContentType
      : '-';
  final trimmed = body.trimLeft();
  final kind = trimmed.isEmpty
      ? 'empty'
      : trimmed.startsWith('<')
      ? 'html'
      : trimmed.startsWith('{')
      ? 'json'
      : trimmed.startsWith('[')
      ? 'array'
      : RegExp(r'^[A-Za-z_$][\w$]*\s*\(').hasMatch(trimmed)
      ? 'jsonp'
      : 'text';
  final markers = <String>[
    if (body.contains('__vpn_hostname_data') &&
        body.contains('__vpn_app_hostname_data'))
      'webvpn-bootstrap',
    if (body.contains('sm2publicKey') || body.contains('/do/off/ui/auth/login'))
      'identity-login',
    if (body.contains('jsp.timeout') || body.contains('登录超时'))
      'session-timeout',
  ];
  final safePath = uri.path
      .replaceAll(
        RegExp(r';jsessionid=[^/;]+', caseSensitive: false),
        ';jsessionid=[redacted]',
      )
      .replaceAll(RegExp(r'/[A-Za-z0-9_-]{48,}(?=/|$)'), '/[redacted]');
  final preview = _safeBodyPreview(body);
  return 'Unexpected response stage=$stage status=$statusCode '
      'host=${uri.host} path=$safePath contentType=$contentType '
      'bodyType=$kind bodyLength=${body.length} '
      'markers=${markers.isEmpty ? '-' : markers.join(',')} '
      'preview="$preview"';
}

String _safeBodyPreview(String body) {
  if (body.trim().isEmpty) return '<empty>';
  var sample = body.length > _MAX_INSPECTED_BODY_LENGTH
      ? body.substring(0, _MAX_INSPECTED_BODY_LENGTH)
      : body;

  // Script, style, and tag attributes often carry service tickets and hidden
  // form values. Keep only visible text when the response is HTML.
  if (sample.trimLeft().startsWith('<')) {
    sample = sample
        .replaceAll(
          RegExp(r'<(script|style)\b[^>]*>[\s\S]*?</\1>', caseSensitive: false),
          ' ',
        )
        .replaceAll(RegExp(r'<[^>]*>'), ' ');
  }

  // Redact named credentials, opaque identifiers, and student/phone numbers
  // even in non-HTML error responses. This is a diagnostic hint, not a dump.
  sample = sample
      .replaceAllMapped(
        RegExp(
          r'''([\w-]*(?:pass|secret|token|ticket|session|cookie|csrf|code|fingerprint)[\w-]*\s*["']?\s*[:=]\s*["']?)[^\s"';,<>]+''',
          caseSensitive: false,
        ),
        (match) => '${match.group(1)}[redacted]',
      )
      .replaceAll(RegExp(r'[A-Za-z0-9_+/=-]{16,}'), '[redacted]')
      .replaceAll(RegExp(r'\d{6,}'), '[redacted]')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (sample.length > _MAX_PREVIEW_LENGTH) {
    return '${sample.substring(0, _MAX_PREVIEW_LENGTH)}…';
  }
  return sample;
}
