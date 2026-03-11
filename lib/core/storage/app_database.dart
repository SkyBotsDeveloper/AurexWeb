import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sembast/sembast_io.dart';
import 'package:sembast_web/sembast_web.dart';

import 'app_paths.dart';

class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static Future<AppDatabase> open() async {
    if (kIsWeb) {
      final db = await databaseFactoryWeb.openDatabase('aurex.db');
      return AppDatabase._(db);
    }

    final root = await AppPaths.supportDirectoryPath();
    final dbPath = p.join(root, 'aurex.db');
    final db = await databaseFactoryIo.openDatabase(dbPath);
    return AppDatabase._(db);
  }
}
