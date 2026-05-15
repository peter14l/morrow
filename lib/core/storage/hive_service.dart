import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_io/io.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Box names enum for type safety
class HiveBoxes {
  static const String messages = 'messages_cache';
  static const String feeds = 'feeds_cache';
  static const String profiles = 'profiles_cache';
  static const String settings = 'settings_cache';
  static const String metadata = 'metadata_cache';
}

class HiveService {
  static Future<void> initialize() async {
    if (kIsWeb) {
      await Hive.initFlutter();
    } else {
      // Use Application Support directory instead of Documents on Desktop/Mobile
      // to avoid permission issues (like Controlled Folder Access on Windows)
      final appDir = await getApplicationSupportDirectory();
      final hivePath = p.join(appDir.path, 'hive');

      // Ensure the directory exists
      final dir = Directory(hivePath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      await Hive.initFlutter(hivePath);
    }

    // Open boxes
    await Hive.openBox(HiveBoxes.messages);
    await Hive.openBox(HiveBoxes.feeds);
    await Hive.openBox(HiveBoxes.profiles);
    await Hive.openBox(HiveBoxes.settings);
    await Hive.openBox(HiveBoxes.metadata);
  }

  static Future<void> close() async {
    await Hive.close();
  }

  /// Clear all caches (e.g. on logout)
  static Future<void> clearAll() async {
    await Hive.box(HiveBoxes.messages).clear();
    await Hive.box(HiveBoxes.feeds).clear();
    await Hive.box(HiveBoxes.profiles).clear();
    await Hive.box(HiveBoxes.settings).clear();
    await Hive.box(HiveBoxes.metadata).clear();
  }
}
