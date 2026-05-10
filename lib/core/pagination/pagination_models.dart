import 'package:flutter/foundation.dart';

/// Composite cursor for deterministic ordering
@immutable
class Cursor {
  final DateTime? createdAt;
  final String? id;

  const Cursor({this.createdAt, this.id});

  /// Serialize to API format: "2024-01-15T10:30:00Z_abc123"
  String? toApiString() {
    if (createdAt == null || id == null) return null;
    return '${createdAt!.toIso8601String()}_$id';
  }

  /// Deserialize from API format
  factory Cursor.fromApiString(String? cursor) {
    if (cursor == null || cursor.isEmpty) return Cursor.empty;
    try {
      final parts = cursor.split('_');
      if (parts.length < 2) return Cursor.empty;
      return Cursor(
        createdAt: DateTime.parse(parts[0]),
        id: parts.sublist(1).join('_'), // Handle IDs containing underscores
      );
    } catch (_) {
      return Cursor.empty;
    }
  }

  /// Empty cursor for first page
  static const Cursor empty = Cursor(createdAt: null, id: null);

  bool get isEmpty => createdAt == null || id == null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Cursor &&
          runtimeType == other.runtimeType &&
          createdAt == other.createdAt &&
          id == other.id;

  @override
  int get hashCode => createdAt.hashCode ^ id.hashCode;
}

/// Paginated response wrapper
class PageResponse<T> {
  final List<T> items;
  final Cursor? nextCursor;
  final bool hasMore;

  const PageResponse({
    required this.items,
    this.nextCursor,
    required this.hasMore,
  });

  bool get isEmpty => items.isEmpty;
}
