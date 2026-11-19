import 'dart:io';

/// Writes a validated download in the destination directory and renames it
/// into place. Exclusive creation prevents replacing an existing file unless
/// the user explicitly requested overwrite.
Future<File> saveMaterialDownload(
  List<int> bytes, {
  required String outputPath,
  bool overwrite = false,
}) async {
  if (bytes.isEmpty) throw ArgumentError('The download is empty.');
  final output = File(outputPath).absolute;
  if (await FileSystemEntity.type(output.path, followLinks: false) !=
          FileSystemEntityType.notFound &&
      !overwrite) {
    throw FileSystemException(
      'Output already exists. Use --force to replace it.',
      output.path,
    );
  }
  await output.parent.create(recursive: true);
  final temporary = await output.parent.createTemp('.thulium-material-');
  var reserved = false;
  try {
    final partial = await File(
      '${temporary.path}/download.part',
    ).writeAsBytes(bytes, flush: true);
    if (!overwrite) {
      await output.create(exclusive: true);
      reserved = true;
    }
    final saved = await partial.rename(output.path);
    reserved = false;
    return saved;
  } finally {
    if (reserved) await output.delete();
    await temporary.delete(recursive: true);
  }
}
