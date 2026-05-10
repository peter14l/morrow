import 'package:hive_flutter/hive_flutter.dart';
import 'hive_service.dart';

/// Generic cache service with TTL support
class CacheService<T> {
  final String boxName;

  CacheService(this.boxName);

  Box<dynamic> get _box => Hive.box(boxName);

  /// Store item with optional TTL (in hours)
  Future<void> put(String key, T value, {int? ttlHours}) async {
    await _box.put(key, value);
    if (ttlHours != null) {
      final expiry = DateTime.now().add(Duration(hours: ttlHours));
      await _box.put('${key}_ttl', expiry.toIso8601String());
    }
  }

  /// Get item, returns null if expired or not found
  T? get(String key) {
    final ttlStr = _box.get('${key}_ttl') as String?;
    if (ttlStr != null) {
      final ttl = DateTime.parse(ttlStr);
      if (DateTime.now().isAfter(ttl)) {
        _box.delete(key);
        _box.delete('${key}_ttl');
        return null;
      }
    }
    return _box.get(key) as T?;
  }

  /// Get all items
  List<T> getAll() {
    return _box.values.whereType<T>().toList();
  }

  Future<void> delete(String key) async {
    await _box.delete(key);
    await _box.delete('${key}_ttl');
  }

  Future<void> clear() async {
    await _box.clear();
  }
}
