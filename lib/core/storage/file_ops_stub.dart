Future<bool> fileExists(String path) async => false;

Future<int?> fileLength(String path) async => null;

Future<void> ensureDirectory(String path) async {
  throw UnsupportedError('Local file operations are not supported on web.');
}

Future<void> deleteFileIfExists(String path) async {}

Future<void> deleteDirectoryContents(String path) async {}

Future<void> moveFile(String from, String to) async {
  throw UnsupportedError('Local file operations are not supported on web.');
}
