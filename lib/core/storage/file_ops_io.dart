import 'dart:io';

Future<bool> fileExists(String path) => File(path).exists();

Future<int?> fileLength(String path) async {
  final file = File(path);
  if (!await file.exists()) {
    return null;
  }
  return file.length();
}

Future<List<String>> listFiles(String path) async {
  final directory = Directory(path);
  if (!await directory.exists()) {
    return const [];
  }
  return directory
      .list()
      .where((entry) => entry is File)
      .map((entry) => entry.path)
      .toList();
}

Future<void> ensureDirectory(String path) async {
  await Directory(path).create(recursive: true);
}

Future<void> deleteFileIfExists(String path) async {
  final file = File(path);
  if (await file.exists()) {
    await file.delete();
  }
}

Future<void> deleteDirectoryContents(String path) async {
  final dir = Directory(path);
  if (!await dir.exists()) {
    return;
  }
  await for (final entry in dir.list()) {
    if (entry is File) {
      await entry.delete();
    } else if (entry is Directory) {
      await entry.delete(recursive: true);
    }
  }
}

Future<void> moveFile(String from, String to) async {
  final source = File(from);
  if (!await source.exists()) {
    return;
  }
  final target = File(to);
  if (await target.exists()) {
    await target.delete();
  }
  await source.rename(to);
}
