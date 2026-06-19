import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppPaths {
  static Future<String> supportDirectoryPath() async {
    final dir = await getApplicationSupportDirectory();
    return dir.path;
  }

  static Future<String?> downloadsDirectoryPath() async {
    if (kIsWeb) {
      return null;
    }
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, 'downloads');
  }

  static Future<String?> aurexAudioCacheDirectoryPath() async {
    if (kIsWeb) {
      return null;
    }
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, 'aurex_audio_cache');
  }
}
