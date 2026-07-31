import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MediaCacheService {
  static const String _mediaMapPrefix = 'media_path_';

  /// Version counter bumped whenever a media file lands in the cache.
  /// Media bubbles listen to this so they can re-check for a newly available
  /// local file after a background auto-download completes.
  static final ValueNotifier<int> cacheVersion = ValueNotifier<int>(0);

  /// Gets the local path for a remote URL if it exists in cache and on disk.
  Future<String?> getLocalPath(String remoteUrl) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localPath = prefs.getString('$_mediaMapPrefix$remoteUrl');

      if (localPath != null) {
        final file = File(localPath);
        if (await file.exists()) {
          return localPath;
        } else {
          // File was deleted from disk, remove from mapping
          await prefs.remove('$_mediaMapPrefix$remoteUrl');
        }
      }
      return null;
    } catch (e) {
      debugPrint('[MediaCacheService] Error getting local path: $e');
      return null;
    }
  }

  /// Sets the local path for a remote URL.
  Future<void> setLocalPath(String remoteUrl, String localPath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_mediaMapPrefix$remoteUrl', localPath);
    } catch (e) {
      debugPrint('[MediaCacheService] Error setting local path: $e');
    }
  }

  /// Gets the directory for storing oasis media.
  Future<Directory> getMediaDirectory(String type) async {
    final appDir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory('${appDir.path}/oasis/media/$type');
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }
    return mediaDir;
  }

  /// Saves bytes to the local media cache.
  Future<String> saveToCache(
    Uint8List bytes,
    String fileName,
    String type,
    String remoteUrl,
  ) async {
    final dir = await getMediaDirectory(type);
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);

    await setLocalPath(remoteUrl, file.path);
    cacheVersion.value++;
    return file.path;
  }

  /// Clears all media cache.
  Future<void> clearMediaCache() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final mediaDir = Directory('${appDir.path}/oasis/media');
      if (await mediaDir.exists()) {
        await mediaDir.delete(recursive: true);
      }

      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_mediaMapPrefix));
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (e) {
      debugPrint('[MediaCacheService] Error clearing media cache: $e');
    }
  }
}
