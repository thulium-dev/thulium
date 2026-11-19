import 'dart:io';

import 'package:test/test.dart';
import 'package:thulium_cli/material_download_file.dart';

void main() {
  late Directory directory;
  setUp(
    () async => directory = await Directory.systemTemp.createTemp(
      'thulium-download-test-',
    ),
  );
  tearDown(() async => directory.delete(recursive: true));

  test(
    'saves exact bytes, creates parent directories and removes temporary data',
    () async {
      final bytes = List.generate(256, (index) => index);
      final path = '${directory.path}/nested/material.pdf';
      final result = await saveMaterialDownload(bytes, outputPath: path);
      expect(await result.readAsBytes(), bytes);
      expect(await result.parent.list().map((entry) => entry.path).toList(), [
        result.path,
      ]);
    },
  );

  test(
    'preserves existing data unless overwrite is explicitly requested',
    () async {
      final file = await File(
        '${directory.path}/material.pdf',
      ).writeAsString('existing data');
      await expectLater(
        saveMaterialDownload([1, 2, 3], outputPath: file.path),
        throwsA(isA<FileSystemException>()),
      );
      expect(await file.readAsString(), 'existing data');
      await saveMaterialDownload(
        [1, 2, 3],
        outputPath: file.path,
        overwrite: true,
      );
      expect(await file.readAsBytes(), [1, 2, 3]);
      expect(await directory.list().length, 1);
    },
  );

  test(
    'empty downloads and invalid destinations do not leave output or temporary files',
    () async {
      await expectLater(
        saveMaterialDownload([], outputPath: '${directory.path}/empty.pdf'),
        throwsArgumentError,
      );
      final target = await Directory('${directory.path}/folder').create();
      await expectLater(
        saveMaterialDownload([1, 2], outputPath: target.path, overwrite: true),
        throwsA(isA<FileSystemException>()),
      );
      expect(await target.exists(), isTrue);
      expect(await directory.list().map((entry) => entry.path).toList(), [
        target.path,
      ]);
    },
  );
}
