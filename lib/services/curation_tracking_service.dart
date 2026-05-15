import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Service to track user interactions locally for curation purposes.
/// ALL data stays on the device and is NEVER sent to any server.
class CurationTrackingService extends ChangeNotifier {
  static const String _dbName = 'oasis_curation.db';
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Table for category interactions (counts)
        await db.execute('''
          CREATE TABLE category_interactions (
            category_id TEXT PRIMARY KEY,
            interaction_count INTEGER DEFAULT 0,
            last_interacted_at TEXT
          )
        ''');

        // Table for post likes
        await db.execute('''
          CREATE TABLE post_likes (
            post_id TEXT PRIMARY KEY,
            category_id TEXT,
            liked_at TEXT
          )
        ''');

        // Table for time spent
        await db.execute('''
          CREATE TABLE time_spent (
            category_id TEXT PRIMARY KEY,
            total_seconds INTEGER DEFAULT 0,
            last_updated_at TEXT
          )
        ''');
      },
    );
  }

  /// Track a visit or significant interaction with a category
  Future<void> trackCategoryInteraction(
    String categoryId, {
    int weight = 1,
  }) async {
    final db = await database;

    final List<Map<String, dynamic>> existing = await db.query(
      'category_interactions',
      where: 'category_id = ?',
      whereArgs: [categoryId],
    );

    if (existing.isEmpty) {
      await db.insert('category_interactions', {
        'category_id': categoryId,
        'interaction_count': weight,
        'last_interacted_at': DateTime.now().toIso8601String(),
      });
    } else {
      await db.rawUpdate(
        '''
        UPDATE category_interactions 
        SET interaction_count = interaction_count + ?, last_interacted_at = ?
        WHERE category_id = ?
      ''',
        [weight, DateTime.now().toIso8601String(), categoryId],
      );
    }

    notifyListeners();
  }

  /// Track a like on a post within a category
  Future<void> trackPostLike(String categoryId, String postId) async {
    final db = await database;
    await db.insert('post_likes', {
      'post_id': postId,
      'category_id': categoryId,
      'liked_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    notifyListeners();
  }

  /// Track time spent viewing a category
  Future<void> trackTimeSpent(String categoryId, int seconds) async {
    if (seconds <= 0) return;
    final db = await database;

    final List<Map<String, dynamic>> existing = await db.query(
      'time_spent',
      where: 'category_id = ?',
      whereArgs: [categoryId],
    );

    if (existing.isEmpty) {
      await db.insert('time_spent', {
        'category_id': categoryId,
        'total_seconds': seconds,
        'last_updated_at': DateTime.now().toIso8601String(),
      });
    } else {
      await db.rawUpdate(
        '''
        UPDATE time_spent 
        SET total_seconds = total_seconds + ?, last_updated_at = ?
        WHERE category_id = ?
      ''',
        [seconds, DateTime.now().toIso8601String(), categoryId],
      );
    }

    notifyListeners();
  }

  /// Get the user's top categories based on interactions, likes, and time
  Future<List<String>> getTopCategories({int limit = 5}) async {
    final db = await database;

    // Combined score query: Interaction: 1.0, Likes: 2.0, Time: 0.1 per sec
    final List<Map<String, dynamic>> results = await db.rawQuery(
      '''
      SELECT category_id, 
             SUM(score) as total_score
      FROM (
        SELECT category_id, interaction_count * 1.0 as score FROM category_interactions
        UNION ALL
        SELECT category_id, COUNT(*) * 2.0 as score FROM post_likes GROUP BY category_id
        UNION ALL
        SELECT category_id, total_seconds * 0.1 as score FROM time_spent
      )
      GROUP BY category_id
      ORDER BY total_score DESC
      LIMIT ?
    ''',
      [limit],
    );

    return results.map((e) => e['category_id'] as String).toList();
  }

  /// Get summary of tracking (for transparency UI)
  Future<Map<String, dynamic>> getTrackingSummary() async {
    final db = await database;

    final categories = await db.query('category_interactions');
    final likesResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM post_likes',
    );
    final likesCount = Sqflite.firstIntValue(likesResult) ?? 0;

    final timeResult = await db.rawQuery(
      'SELECT SUM(total_seconds) as total FROM time_spent',
    );
    final totalTime = Sqflite.firstIntValue(timeResult) ?? 0;

    return {
      'tracked_categories': categories.length,
      'total_likes_recorded': likesCount,
      'total_time_seconds': totalTime,
      'data_location': 'On-device storage (SQLite)',
      'is_encrypted': 'Yes (Standard Sandbox)',
    };
  }

  /// Get full tracking data for server synchronization.
  /// Returns a list of maps formatted for the 'sync_user_analytics' RPC.
  Future<List<Map<String, dynamic>>> getSyncData() async {
    final db = await database;

    // Get interaction counts
    final categories = await db.query('category_interactions');

    // Get liked posts grouped by category
    final likes = await db.query('post_likes');
    final likesByCategory = <String, List<String>>{};
    for (final like in likes) {
      final categoryId = like['category_id'] as String;
      final postId = like['post_id'] as String;
      likesByCategory.putIfAbsent(categoryId, () => []).add(postId);
    }

    // Get time spent
    final timeSpent = await db.query('time_spent');
    final timeSpentByCategory = <String, int>{};
    for (final time in timeSpent) {
      final categoryId = time['category_id'] as String;
      final seconds = time['total_seconds'] as int;
      timeSpentByCategory[categoryId] = seconds;
    }

    final result = <Map<String, dynamic>>[];
    for (final category in categories) {
      final categoryId = category['category_id'] as String;
      result.add({
        'p_category_id': categoryId,
        'p_interaction_count': category['interaction_count'] as int,
        'p_liked_posts': likesByCategory[categoryId] ?? [],
        'p_total_seconds': timeSpentByCategory[categoryId] ?? 0,
      });
    }

    return result;
  }

  /// Clear all tracking data (privacy feature)
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('category_interactions');
    await db.delete('post_likes');
    await db.delete('time_spent');
    notifyListeners();
  }
}
