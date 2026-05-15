import 'package:oasis/features/canvas/domain/models/canvas_models.dart';

/// Abstract repository interface for Canvas operations.
/// This defines the contract that the data layer must implement.
abstract class CanvasRepository {
  /// Fetch all canvases the user is a member of.
  Future<List<OasisCanvas>> getCanvases(String userId);

  /// Fetch a single canvas by ID.
  Future<OasisCanvas> getCanvas(String canvasId);

  /// Create a new canvas with optional initial members.
  Future<OasisCanvas> createCanvas({
    required String createdBy,
    required String title,
    required String coverColor,
    List<String> memberIds = const [],
  });

  /// Update canvas details (title, cover color).
  Future<OasisCanvas> updateCanvas({
    required String canvasId,
    String? title,
    String? coverColor,
  });

  /// Delete a canvas (only if owner).
  Future<void> deleteCanvas(String canvasId);

  /// Leave a canvas (remove membership).
  Future<void> leaveCanvas(String canvasId);

  /// Join an existing canvas.
  Future<void> joinCanvas(String canvasId, String userId);

  /// Fetch all items for a specific canvas.
  Future<List<CanvasItemEntity>> getCanvasItems(String canvasId);

  /// Add a new item to a canvas.
  Future<CanvasItemEntity> addCanvasItem({
    required String canvasId,
    required String authorId,
    required CanvasItemType type,
    required String content,
    required double xPos,
    required double yPos,
    double rotation = 0.0,
    double scale = 1.0,
    String color = '#252930',
    DateTime? unlockAt,
    Map<String, dynamic> metadata = const {},
  });

  /// Update item position/rotation/scale.
  Future<void> updateCanvasItemTransform({
    required String itemId,
    required double xPos,
    required double yPos,
    double? rotation,
    double? scale,
    String? lastModifiedBy,
  });

  /// Delete an item from the canvas.
  Future<void> deleteCanvasItem(String itemId);

  /// Toggle a reaction on a canvas item.
  Future<void> toggleCanvasItemReaction({
    required String itemId,
    required String userId,
    required String emoji,
  });

  /// Lock or unlock an item.
  Future<void> updateCanvasItemLock(String itemId, bool isLocked);

  /// Upload an image to Supabase Storage for use on the canvas.
  Future<String> uploadCanvasImage(String canvasId, String filePath);

  /// Upload a voice memo to Supabase Storage for use on the canvas.
  Future<String> uploadCanvasAudio(String canvasId, String filePath);
}
