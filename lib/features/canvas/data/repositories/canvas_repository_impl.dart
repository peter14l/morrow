import 'package:oasis/features/canvas/data/datasources/canvas_remote_datasource.dart';
import 'package:oasis/features/canvas/domain/models/canvas_models.dart';
import 'package:oasis/features/canvas/domain/repositories/canvas_repository.dart';

/// Implementation of CanvasRepository using remote data source.
class CanvasRepositoryImpl implements CanvasRepository {
  final CanvasRemoteDatasource _remoteDatasource;

  CanvasRepositoryImpl({CanvasRemoteDatasource? remoteDatasource})
    : _remoteDatasource = remoteDatasource ?? CanvasRemoteDatasource();

  @override
  Future<List<OasisCanvas>> getCanvases(String userId) {
    return _remoteDatasource.fetchUserCanvases(userId);
  }

  @override
  Future<OasisCanvas> getCanvas(String canvasId) {
    return _remoteDatasource.getCanvas(canvasId);
  }

  @override
  Future<OasisCanvas> createCanvas({
    required String createdBy,
    required String title,
    required String coverColor,
    List<String> memberIds = const [],
  }) {
    return _remoteDatasource.createCanvas(
      createdBy: createdBy,
      title: title,
      coverColor: coverColor,
      memberIds: memberIds,
    );
  }

  @override
  Future<OasisCanvas> updateCanvas({
    required String canvasId,
    String? title,
    String? coverColor,
  }) {
    return _remoteDatasource.updateCanvas(
      canvasId: canvasId,
      title: title,
      coverColor: coverColor,
    );
  }

  @override
  Future<void> deleteCanvas(String canvasId) {
    return _remoteDatasource.deleteCanvas(canvasId);
  }

  @override
  Future<void> leaveCanvas(String canvasId) {
    return _remoteDatasource.leaveCanvas(canvasId);
  }

  @override
  Future<void> joinCanvas(String canvasId, String userId) {
    return _remoteDatasource.joinCanvas(canvasId, userId);
  }

  @override
  Future<List<CanvasItemEntity>> getCanvasItems(String canvasId) {
    return _remoteDatasource.fetchCanvasItems(canvasId);
  }

  @override
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
  }) {
    return _remoteDatasource.addCanvasItem(
      canvasId: canvasId,
      authorId: authorId,
      type: type,
      content: content,
      xPos: xPos,
      yPos: yPos,
      rotation: rotation,
      scale: scale,
      color: color,
      unlockAt: unlockAt,
      metadata: metadata,
    );
  }

  @override
  Future<void> updateCanvasItemTransform({
    required String itemId,
    required double xPos,
    required double yPos,
    double? rotation,
    double? scale,
    String? lastModifiedBy,
  }) {
    return _remoteDatasource.updateCanvasItemTransform(
      itemId: itemId,
      xPos: xPos,
      yPos: yPos,
      rotation: rotation,
      scale: scale,
      lastModifiedBy: lastModifiedBy,
    );
  }

  @override
  Future<void> deleteCanvasItem(String itemId) {
    return _remoteDatasource.deleteCanvasItem(itemId);
  }

  @override
  Future<void> toggleCanvasItemReaction({
    required String itemId,
    required String userId,
    required String emoji,
  }) {
    return _remoteDatasource.toggleCanvasItemReaction(
      itemId: itemId,
      userId: userId,
      emoji: emoji,
    );
  }

  @override
  Future<void> updateCanvasItemLock(String itemId, bool isLocked) {
    return _remoteDatasource.updateCanvasItemLock(itemId, isLocked);
  }

  @override
  Future<String> uploadCanvasImage(String canvasId, String filePath) {
    return _remoteDatasource.uploadCanvasImage(canvasId, filePath);
  }

  @override
  Future<String> uploadCanvasAudio(String canvasId, String filePath) {
    return _remoteDatasource.uploadCanvasAudio(canvasId, filePath);
  }

  // Real-time subscriptions
  Stream<List<CanvasItemEntity>> subscribeToCanvas(String canvasId) {
    return _remoteDatasource.subscribeToCanvas(canvasId);
  }

  Stream<Map<String, dynamic>> subscribeToPresence(String canvasId) {
    return _remoteDatasource.subscribeToPresence(canvasId);
  }

  void updatePresence({
    required String canvasId,
    required String userId,
    required double x,
    required double y,
    String? activeItemId,
  }) {
    _remoteDatasource.updatePresence(
      canvasId: canvasId,
      userId: userId,
      x: x,
      y: y,
      activeItemId: activeItemId,
    );
  }

  Future<void> sendPulse(
    String canvasId,
    String userId, {
    double intensity = 1.0,
  }) {
    return _remoteDatasource.sendPulse(canvasId, userId, intensity: intensity);
  }
}
