part of '../thulium_campus.dart';

/// Metadata for one Learn material. Times are absolute UTC instants.
final class LearnMaterial {
  factory LearnMaterial.fromResponse(Map<String, dynamic> row) {
    for (final key in ['kjxxid', 'wlkcid', 'bt', 'wjid']) {
      if (row[key] is! String || (row[key] as String).trim().isEmpty) {
        throw const FormatException(
          'Learn returned invalid material metadata.',
        );
      }
    }
    return LearnMaterial._(row);
  }

  LearnMaterial._(Map<String, dynamic> row)
    : id = row['kjxxid'] as String,
      courseId = row['wlkcid'] as String,
      title = row['bt'] as String,
      fileId = row['wjid'] as String,
      fileType = _materialText(row['wjlx']),
      displaySize = _materialText(row['fileSize']),
      sizeBytes = _materialCount(row['wjdx']),
      uploadedAt = _materialUploadTime(row['scsj']),
      availableAt = _materialEpoch(row['sxsj']),
      isNew = switch (row['isNew']) {
        1 || '1' || true => true,
        0 || '0' || false => false,
        _ => null,
      },
      description = _materialText(row['ms']),
      categoryId = _materialText(row['kjflid']),
      viewCount = _materialCount(row['llcs']),
      downloadCount = _materialCount(row['xzcs']),
      rawResponse = Map.unmodifiable(row);

  final String id;
  final String courseId;
  final String title;
  final String fileId;
  final String fileType;
  final String displaySize;
  final int? sizeBytes;
  final DateTime? uploadedAt;
  final DateTime? availableAt;
  final bool? isNew;
  final String description;
  final String categoryId;
  final int? viewCount;
  final int? downloadCount;

  /// Keeps unverified fields available without assigning guessed semantics.
  /// In particular, OneTHU maps sfqd to "important", while the captured
  /// response does not establish that meaning; do not call it attendance.
  final Map<String, dynamic> rawResponse;
}

/// A bounded material list, not an authoritative total for the course.
final class LearnCourseMaterials {
  LearnCourseMaterials({
    required this.course,
    required List<LearnMaterial> materials,
    required this.requestedLimit,
  }) : materials = List.unmodifiable(materials);

  final LearnCourse course;
  final List<LearnMaterial> materials;
  final int requestedLimit;
  bool get mayBeTruncated => materials.length >= requestedLimit;
}

/// Lists material metadata through the captured Learn student endpoint.
final class LearnMaterialService {
  const LearnMaterialService(this._authClient);
  final TsinghuaAuthClient _authClient;

  /// OneTHU uses 200 here. This endpoint has no offset or total count in the
  /// supplied response, so preserve the limit and never claim a complete list.
  Future<List<LearnCourseMaterials>> fetchCourses(
    LearnCourseCatalog catalog, {
    String? courseId,
    int size = 200,
  }) async {
    if (size <= 0) throw ArgumentError.value(size, 'size', 'Must be positive.');
    if (_authClient.session?.userId != catalog.userId) {
      throw StateError('Restore the course catalog account first.');
    }
    final courses = catalog.courses
        .where((course) => courseId == null || course.id == courseId)
        .toList();
    if (courseId != null && courses.isEmpty) {
      throw ArgumentError.value(
        courseId,
        'courseId',
        'Course is not in this semester catalog.',
      );
    }
    if (courses.any((course) => course.id.isEmpty)) {
      throw const FormatException('A course has no learning platform ID.');
    }
    if (courses.isEmpty) return const [];
    final csrf = await LearnPlatformSession(_authClient).open();
    final result = <LearnCourseMaterials>[];
    // One shared roaming session; sequential requests preserve existing Learn
    // authentication behavior and avoid sending a burst for the whole semester.
    for (final course in courses) {
      result.add(
        LearnCourseMaterials(
          course: course,
          requestedLimit: size,
          materials: await _fetch(course.id, size, csrf),
        ),
      );
    }
    return List.unmodifiable(result);
  }

  /// Downloads all pages of the PDF representation.
  Future<List<int>> downloadPdf({
    required String fileId,
    required String courseId,
  }) => _downloadPdf(fileId: fileId, courseId: courseId, pageType: 'all');

  /// Downloads the cover preview for use by clients such as the app.
  Future<List<int>> downloadPdfCover({
    required String fileId,
    required String courseId,
  }) => _downloadPdf(fileId: fileId, courseId: courseId, pageType: 'first');

  Future<List<int>> _downloadPdf({
    required String fileId,
    required String courseId,
    required String pageType,
  }) async {
    final idPattern = RegExp(r'^[A-Za-z0-9_-]+$');
    if (!idPattern.hasMatch(fileId) || !idPattern.hasMatch(courseId)) {
      throw ArgumentError(
        'File and course IDs must contain only letters, numbers, underscores or hyphens.',
      );
    }
    await LearnPlatformSession(_authClient).open();
    final target = Uri(
      scheme: 'https',
      host: _LEARN_HOST,
      pathSegments: [
        'f',
        'wlxt',
        'kc',
        'wj_wjb',
        'student',
        'downloadPdfStream',
        pageType,
        fileId,
        courseId,
        'mk_kcwj',
      ],
    );
    final referer = Uri.https(
      _LEARN_HOST,
      '/f/wlxt/kc/wj_wjb/student/beforePlay',
      {
        'sfgk': '0',
        'wjid': fileId,
        'mk': 'mk_kcwj',
        'pageType': pageType,
        'browser': '-1',
      },
    );
    final response = await _authClient.getAuthenticatedBytes(
      TsinghuaWebVpnRedirect.forTarget(target),
      referer: TsinghuaWebVpnRedirect.forTarget(referer),
    );
    final bytes = response.bodyBytes;
    final signature = latin1.decode(bytes.take(1024).toList());
    final contentType = response.headers['content-type']?.toLowerCase() ?? '';
    final isPdf =
        RegExp(r'%PDF-[12]\.\d').hasMatch(signature) &&
        !contentType.startsWith('text/html') &&
        !contentType.contains('json');
    final preview = utf8.decode(
      bytes.take(4096).toList(),
      allowMalformed: true,
    );
    if (_isLearnSignInResponse(
      response.statusCode,
      response.request?.url,
      isPdf ? '' : preview,
    )) {
      // Do not log response previews here: a successful binary response may
      // contain private course content rather than an authentication page.
      throw const PortalSessionRejected();
    }
    if (response.statusCode != 200) {
      throw StateError(
        'Material download failed: HTTP ${response.statusCode}.',
      );
    }
    if (!isPdf) {
      throw const FormatException(
        'Learn did not return a PDF. The file may not support PDF preview or the session may have expired.',
      );
    }
    return bytes;
  }

  Future<List<LearnMaterial>> _fetch(
    String courseId,
    int size,
    String csrf,
  ) async {
    final target = Uri.https(
      _LEARN_HOST,
      '/b/wlxt/kj/wlkc_kjxxb/student/kjxxbByWlkcidAndSizeForStudent',
      {'wlkcid': courseId, 'size': '$size', '_csrf': csrf},
    );
    final response = await _authClient.getAuthenticated(
      TsinghuaWebVpnRedirect.forTarget(target),
    );
    if (_isLearnSignInResponse(
      response.statusCode,
      response.request?.url,
      response.body,
    )) {
      _authClient.traceUnexpectedResponse('learning-materials', response);
      throw const PortalSessionRejected();
    }
    if (response.statusCode != 200) {
      throw StateError(
        'Materials request failed for $courseId: HTTP ${response.statusCode}.',
      );
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const FormatException('Learn did not return material-list JSON.');
    }
    if (decoded is! Map ||
        decoded['result'] != 'success' ||
        decoded['object'] is! List) {
      throw const FormatException('Learn returned an invalid material list.');
    }
    final rows = decoded['object'] as List;
    final ids = <String>{};
    final materials = <LearnMaterial>[];
    for (final row in rows) {
      if (row is! Map<String, dynamic> || row['wlkcid'] != courseId) {
        throw const FormatException(
          'Learn returned materials for another course.',
        );
      }
      final material = LearnMaterial.fromResponse(row);
      if (!ids.add(material.id)) {
        throw const FormatException('Learn returned duplicate material IDs.');
      }
      materials.add(material);
    }
    return materials;
  }
}

String _materialText(Object? value) => value is String ? value : '';

int? _materialCount(Object? value) {
  final count = value is int
      ? value
      : value is String
      ? int.tryParse(value)
      : null;
  return count != null && count >= 0 ? count : null;
}

DateTime? _materialUploadTime(Object? value) {
  if (value is! String ||
      !RegExp(
        r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}(:\d{2})?$',
      ).hasMatch(value.trim())) {
    return null;
  }
  // scsj is a Beijing wall-clock string, not a time in the device's timezone.
  return DateTime.tryParse(
    '${value.trim().replaceFirst(' ', 'T')}+08:00',
  )?.toUtc();
}

DateTime? _materialEpoch(Object? value) {
  final millis = _materialCount(value);
  if (millis == null || millis <= 0 || millis > 8640000000000000) return null;
  return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
}
