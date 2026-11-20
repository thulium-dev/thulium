import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

/// A course document together with the page this account last read.
final class CourseDocument {
  const CourseDocument(this.bytes, {this.page});

  final List<int> bytes;

  /// One-based page restored from the local reading cache, when known.
  final int? page;
}

/// Persistent, account-isolated store for downloaded course documents and the
/// page each account last read.
///
/// Documents can be several megabytes, so they live on disk rather than in the
/// platform keychain. Entries are evicted by total size and least-recent use;
/// signing out intentionally keeps other accounts' files untouched.
final class CourseDocumentCache {
  CourseDocumentCache({
    Directory? root,
    this.maxBytes = 256 * 1024 * 1024,
    DateTime Function()? clock,
  }) : _explicitRoot = root,
       _clock = clock ?? DateTime.now;

  final Directory? _explicitRoot;

  /// The instance used by the app when no test root is supplied.
  static final shared = CourseDocumentCache();

  final DateTime Function() _clock;

  /// Upper bound for documents stored on this device.
  final int maxBytes;

  static final _segmentPattern = RegExp(r'^[A-Za-z0-9_.-]{1,128}$');

  Directory? _resolvedRoot;
  bool _rootResolved = false;

  Future<Directory?> _root() async {
    if (_rootResolved) return _resolvedRoot;
    _rootResolved = true;
    final explicit = _explicitRoot;
    if (explicit != null) {
      _resolvedRoot = explicit;
      return explicit;
    }
    if (kIsWeb) return null;
    try {
      final support = await getApplicationSupportDirectory();
      _resolvedRoot = Directory('${support.path}/course-documents');
    } on Object {
      // A missing platform directory only disables caching, never the reader.
      _resolvedRoot = null;
    }
    return _resolvedRoot;
  }

  String? _key(String account, String courseId, String fileId) {
    if (!_segmentPattern.hasMatch(account) ||
        !_segmentPattern.hasMatch(courseId) ||
        !_segmentPattern.hasMatch(fileId)) {
      return null;
    }
    return '${courseId}__$fileId';
  }

  Future<File?> _documentFile(
    String account,
    String courseId,
    String fileId,
  ) async {
    final root = await _root();
    final key = _key(account, courseId, fileId);
    if (root == null || key == null) return null;
    return File('${root.path}/$account/$key.pdf');
  }

  Future<File?> _metaFile(
    String account,
    String courseId,
    String fileId,
  ) async {
    final root = await _root();
    final key = _key(account, courseId, fileId);
    if (root == null || key == null) return null;
    return File('${root.path}/$account/$key.json');
  }

  /// Reads a cached document and its page, or null when absent or unreadable.
  Future<CourseDocument?> read({
    required String account,
    required String courseId,
    required String fileId,
  }) async {
    final file = await _documentFile(account, courseId, fileId);
    if (file == null) return null;
    try {
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;
      final page = await readPage(
        account: account,
        courseId: courseId,
        fileId: fileId,
      );
      // Reading is the counter used by least-recently-used eviction.
      await _touchMeta(account, courseId, fileId, bytes.length);
      return CourseDocument(bytes, page: page);
    } on Object {
      return null;
    }
  }

  /// Stores a document without changing the saved page.
  Future<void> write({
    required String account,
    required String courseId,
    required String fileId,
    required List<int> bytes,
  }) async {
    final file = await _documentFile(account, courseId, fileId);
    if (file == null || bytes.isEmpty) return;
    try {
      await file.parent.create(recursive: true);
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsBytes(bytes, flush: true);
      if (await file.exists()) await file.delete();
      await temporary.rename(file.path);
      await _touchMeta(account, courseId, fileId, bytes.length);
      await _evict(file.parent.parent);
    } on Object {
      // A failed cache write must not fail the document request.
    }
  }

  /// Reads the saved one-based page for a document, when present and valid.
  Future<int?> readPage({
    required String account,
    required String courseId,
    required String fileId,
  }) async {
    final meta = await _readMeta(account, courseId, fileId);
    final page = meta?['page'];
    return page is int && page > 0 ? page : null;
  }

  /// Saves the reading position even when the document itself is not cached.
  Future<void> writePage({
    required String account,
    required String courseId,
    required String fileId,
    required int page,
  }) async {
    if (page < 1) return;
    await _writeMeta(account, courseId, fileId, page: page);
  }

  /// Removes every cached document. Signing out deliberately does not call
  /// this, so each account keeps its own offline copies across sessions.
  Future<void> clear({String? account}) async {
    final root = await _root();
    if (root == null) return;
    try {
      if (account == null) {
        if (await root.exists()) await root.delete(recursive: true);
        return;
      }
      if (!_segmentPattern.hasMatch(account)) return;
      final directory = Directory('${root.path}/$account');
      if (await directory.exists()) await directory.delete(recursive: true);
    } on Object {
      // Best-effort cleanup.
    }
  }

  Future<Map<String, Object?>?> _readMeta(
    String account,
    String courseId,
    String fileId,
  ) async {
    final meta = await _metaFile(account, courseId, fileId);
    if (meta == null) return null;
    try {
      if (!await meta.exists()) return null;
      final decoded = jsonDecode(await meta.readAsString());
      return decoded is Map<String, Object?> ? decoded : null;
    } on Object {
      return null;
    }
  }

  Future<void> _writeMeta(
    String account,
    String courseId,
    String fileId, {
    required int page,
  }) async {
    final meta = await _metaFile(account, courseId, fileId);
    if (meta == null) return;
    try {
      final existing = await _readMeta(account, courseId, fileId) ?? const {};
      final document = await _documentFile(account, courseId, fileId);
      final bytes = document != null && await document.exists()
          ? await document.length()
          : 0;
      await meta.parent.create(recursive: true);
      await meta.writeAsString(
        jsonEncode({
          ...existing,
          'page': page,
          'bytes': bytes,
          'lastUsedAt': _clock().toUtc().toIso8601String(),
        }),
        flush: true,
      );
    } on Object {
      // Reading progress is advisory; a failed write only loses it.
    }
  }

  Future<void> _touchMeta(
    String account,
    String courseId,
    String fileId,
    int bytes,
  ) async {
    final meta = await _metaFile(account, courseId, fileId);
    if (meta == null) return;
    try {
      final existing = await _readMeta(account, courseId, fileId) ?? const {};
      await meta.parent.create(recursive: true);
      await meta.writeAsString(
        jsonEncode({
          ...existing,
          'bytes': bytes,
          'lastUsedAt': _clock().toUtc().toIso8601String(),
        }),
        flush: true,
      );
    } on Object {
      // Metadata is only used for eviction and page restore.
    }
  }

  /// Evicts the least recently used documents until the total fits [maxBytes].
  Future<void> _evict(Directory root) async {
    try {
      if (!await root.exists()) return;
      final entries = <({File file, File meta, int bytes, DateTime used})>[];
      await for (final account in root.list(followLinks: false)) {
        if (account is! Directory) continue;
        await for (final entity in account.list(followLinks: false)) {
          if (entity is! File || !entity.path.endsWith('.pdf')) continue;
          final meta = File(
            '${entity.path.substring(0, entity.path.length - 4)}.json',
          );
          var bytes = await entity.length();
          var used = await entity.lastModified();
          try {
            if (await meta.exists()) {
              final decoded = jsonDecode(await meta.readAsString());
              if (decoded is Map) {
                final stored = decoded['bytes'];
                if (stored is int && stored >= 0) bytes = stored;
                final stamp = DateTime.tryParse(
                  '${decoded['lastUsedAt'] ?? ''}',
                );
                if (stamp != null) used = stamp;
              }
            }
          } on Object {
            // Fall back to file metadata for a malformed sidecar.
          }
          entries.add((file: entity, meta: meta, bytes: bytes, used: used));
        }
      }
      var total = entries.fold<int>(0, (sum, entry) => sum + entry.bytes);
      if (total <= maxBytes) return;
      entries.sort((a, b) => a.used.compareTo(b.used));
      for (final entry in entries) {
        if (total <= maxBytes) break;
        try {
          if (await entry.file.exists()) await entry.file.delete();
          if (await entry.meta.exists()) await entry.meta.delete();
        } on Object {
          continue;
        }
        total -= entry.bytes;
      }
    } on Object {
      // Eviction is best effort and must never surface to the reader.
    }
  }
}
