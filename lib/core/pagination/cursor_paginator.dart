import 'package:supabase_flutter/supabase_flutter.dart';
import 'pagination_models.dart';

/// Cursor-based pagination for Supabase
class CursorPaginator {
  final SupabaseClient _client;
  final int defaultLimit;

  CursorPaginator(this._client, {this.defaultLimit = 20});

  /// Fetch a page using cursor
  /// 
  /// Uses a composite cursor (orderColumn, id) for deterministic ordering.
  Future<PageResponse<Map<String, dynamic>>> fetchPage({
    required String table,
    required String orderColumn,
    bool ascending = false,
    Cursor? cursor,
    int? limit,
    Map<String, dynamic>? filters,
  }) async {
    final effectiveLimit = limit ?? defaultLimit;
    
    // We fetch one extra item to determine if there's more
    var query = _client.from(table).select();

    // Apply filters
    if (filters != null) {
      filters.forEach((key, value) {
        query = query.eq(key, value);
      });
    }

    // Apply cursor
    if (cursor != null && !cursor.isEmpty) {
      if (ascending) {
        // (orderColumn > cursor.createdAt) OR (orderColumn == cursor.createdAt AND id > cursor.id)
        query = query.or(
          '$orderColumn.gt.${cursor.createdAt!.toIso8601String()},and($orderColumn.eq.${cursor.createdAt!.toIso8601String()},id.gt.${cursor.id})'
        );
      } else {
        // (orderColumn < cursor.createdAt) OR (orderColumn == cursor.createdAt AND id < cursor.id)
        query = query.or(
          '$orderColumn.lt.${cursor.createdAt!.toIso8601String()},and($orderColumn.eq.${cursor.createdAt!.toIso8601String()},id.lt.${cursor.id})'
        );
      }
    }

    // Apply ordering (always include ID for deterministic ties)
    query = query
        .order(orderColumn, ascending: ascending)
        .order('id', ascending: ascending)
        .limit(effectiveLimit + 1);

    final List<dynamic> response = await query;
    final items = List<Map<String, dynamic>>.from(response);

    final hasMore = items.length > effectiveLimit;
    final pageItems = hasMore ? items.sublist(0, effectiveLimit) : items;

    Cursor? nextCursor;
    if (hasMore && pageItems.isNotEmpty) {
      final lastItem = pageItems.last;
      nextCursor = Cursor(
        createdAt: DateTime.parse(lastItem[orderColumn]),
        id: lastItem['id'].toString(),
      );
    }

    return PageResponse(
      items: pageItems,
      nextCursor: nextCursor,
      hasMore: hasMore,
    );
  }
}
