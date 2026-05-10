import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:oasis/features/canvas/data/repositories/canvas_repository_impl.dart';
import 'package:oasis/features/canvas/domain/models/canvas_models.dart';
import 'package:oasis/features/canvas/domain/usecases/usecases.dart';
import 'package:oasis/features/canvas/presentation/providers/canvas_state.dart';

/// Provider for Canvas feature using Clean Architecture.
class CanvasProvider extends ChangeNotifier {
  final GetCanvases _getCanvases;
  final CreateCanvas _createCanvas;
  final DeleteCanvas _deleteCanvas;
  final AddCanvasItem _addCanvasItem;
  final GetCanvasTimeline _getCanvasTimeline;
  final CanvasRepositoryImpl _repository;

  CanvasState _state = const CanvasState();
  StreamSubscription<List<CanvasItemEntity>>? _realtimeSubscription;
  StreamSubscription<Map<String, CanvasPresenceEntity>>? _presenceSubscription;

  CanvasProvider({
    GetCanvases? getCanvases,
    CreateCanvas? createCanvas,
    DeleteCanvas? deleteCanvas,
    AddCanvasItem? addCanvasItem,
    GetCanvasTimeline? getCanvasTimeline,
    CanvasRepositoryImpl? repository,
  }) : _repository = repository ?? CanvasRepositoryImpl(),
       _getCanvases =
           getCanvases ?? GetCanvases(repository ?? CanvasRepositoryImpl()),
       _createCanvas =
           createCanvas ?? CreateCanvas(repository ?? CanvasRepositoryImpl()),
       _deleteCanvas =
           deleteCanvas ?? DeleteCanvas(repository ?? CanvasRepositoryImpl()),
       _addCanvasItem =
           addCanvasItem ?? AddCanvasItem(repository ?? CanvasRepositoryImpl()),
       _getCanvasTimeline =
           getCanvasTimeline ??
           GetCanvasTimeline(repository ?? CanvasRepositoryImpl());

  // ─── Getters ──────────────────────────────────────────────────────────────────
  CanvasState get state => _state;
  List<OasisCanvas> get canvases => _state.canvases;
  OasisCanvas? get activeCanvas => _state.activeCanvas;
  List<CanvasItemEntity> get activeItems => _state.activeItems;
  bool get isLoading => _state.isLoading;
  String? get error => _state.error;
  Map<String, CanvasPresenceEntity> get presenceState => _state.presenceState;

  // ─── Canvas list ─────────────────────────────────────────────────────────────

  Future<void> loadCanvases(String userId, {bool forceRefresh = false}) async {
    if (_state.canvases.isNotEmpty && !forceRefresh) return;

    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    try {
      final canvases = await _getCanvases(userId);
      _state = _state.copyWith(canvases: canvases, isLoading: false);
    } catch (e) {
      _state = _state.copyWith(error: e.toString(), isLoading: false);
    }
    notifyListeners();
  }

  Future<OasisCanvas?> createCanvas({
    required String createdBy,
    required String title,
    required String coverColor,
    List<String> memberIds = const [],
    bool isPro = false,
  }) async {
    if (!isPro && _state.canvases.length >= 2) {
      _state = _state.copyWith(error: 'FREE_LIMIT_REACHED');
      notifyListeners();
      return null;
    }

    try {
      final canvas = await _createCanvas(
        createdBy: createdBy,
        title: title,
        coverColor: coverColor,
        memberIds: memberIds,
      );
      _state = _state.copyWith(canvases: [canvas, ..._state.canvases]);
      notifyListeners();
      return canvas;
    } catch (e) {
      _state = _state.copyWith(error: e.toString());
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteCanvas(String canvasId) async {
    try {
      await _deleteCanvas(canvasId);
      _state = _state.copyWith(
        canvases: _state.canvases.where((c) => c.id != canvasId).toList(),
        activeCanvas:
            _state.activeCanvas?.id == canvasId ? null : _state.activeCanvas,
        clearActiveCanvas: _state.activeCanvas?.id == canvasId,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _state = _state.copyWith(error: e.toString());
      notifyListeners();
      return false;
    }
  }

  Future<bool> leaveCanvas(String canvasId) async {
    try {
      await _repository.leaveCanvas(canvasId);
      _state = _state.copyWith(
        canvases: _state.canvases.where((c) => c.id != canvasId).toList(),
      );
      notifyListeners();
      return true;
    } catch (e) {
      _state = _state.copyWith(error: e.toString());
      notifyListeners();
      return false;
    }
  }

  Future<void> joinCanvas(String canvasId, String userId) async {
    try {
      await _repository.joinCanvas(canvasId, userId);
      await loadCanvases(userId, forceRefresh: true);
    } catch (e) {
      _state = _state.copyWith(error: e.toString());
      notifyListeners();
    }
  }

  // ─── Active canvas ────────────────────────────────────────────────────────────

  Future<void> openCanvas(String canvasId) async {
    _state = _state.copyWith(isLoading: true);
    notifyListeners();

    // Find the canvas in the list
    try {
      final canvas = _state.canvases.firstWhere((c) => c.id == canvasId);
      _state = _state.copyWith(activeCanvas: canvas);
    } catch (_) {
      try {
        final canvas = await _repository.getCanvas(canvasId);
        _state = _state.copyWith(activeCanvas: canvas);
      } catch (e) {
        _state = _state.copyWith(error: e.toString(), isLoading: false);
        notifyListeners();
        return;
      }
    }

    try {
      final items = await _getCanvasTimeline(canvasId);
      _state = _state.copyWith(activeItems: items, isLoading: false);
    } catch (e) {
      _state = _state.copyWith(error: e.toString(), isLoading: false);
    }

    notifyListeners();

    // Start realtime subscription
    _realtimeSubscription?.cancel();
    _realtimeSubscription = _repository.subscribeToCanvas(canvasId).listen((
      items,
    ) {
      _state = _state.copyWith(activeItems: items);
      notifyListeners();
    });

    _presenceSubscription?.cancel();
    _presenceSubscription = _repository
        .subscribeToPresence(canvasId)
        .map((state) => state.map((key, value) => MapEntry(
              key,
              CanvasPresenceEntity.fromJson(key, value as Map<String, dynamic>),
            )))
        .listen((typedState) {
      _state = _state.copyWith(presenceState: typedState);
      notifyListeners();
    });
  }

  void updatePresence(
    String userId,
    double x,
    double y, {
    String? activeItemId,
  }) {
    if (_state.activeCanvas == null) return;
    _repository.updatePresence(
      canvasId: _state.activeCanvas!.id,
      userId: userId,
      x: x,
      y: y,
      activeItemId: activeItemId,
    );
  }

  void closeCanvas() {
    _realtimeSubscription?.cancel();
    _presenceSubscription?.cancel();
    _state = _state.copyWith(
      clearActiveCanvas: true,
      activeItems: [],
      presenceState: {},
    );
    notifyListeners();
  }

  // ─── Items ────────────────────────────────────────────────────────────────────

  Future<void> addItem({
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
  }) async {
    if (_state.activeCanvas == null) return;
    try {
      final item = await _addCanvasItem(
        canvasId: _state.activeCanvas!.id,
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
      _state = _state.copyWith(activeItems: [..._state.activeItems, item]);
      notifyListeners();
    } catch (e) {
      _state = _state.copyWith(error: e.toString());
      notifyListeners();
    }
  }

  Future<void> moveItem({
    required String itemId,
    required double xPos,
    required double yPos,
    double? rotation,
    double? scale,
    String? lastModifiedBy,
  }) async {
    if (_state.activeCanvas == null) return;

    // Check if locked
    final item = _state.activeItems.firstWhere((i) => i.id == itemId);
    if (item.isLocked && item.authorId != lastModifiedBy) return;

    // Optimistic local update
    _state = _state.copyWith(
      activeItems:
          _state.activeItems.map((i) {
            if (i.id == itemId) {
              return i.copyWith(
                xPos: xPos,
                yPos: yPos,
                rotation: rotation ?? i.rotation,
                scale: scale ?? i.scale,
                lastModifiedBy: lastModifiedBy,
              );
            }
            return i;
          }).toList(),
    );
    notifyListeners();

    try {
      await _repository.updateCanvasItemTransform(
        itemId: itemId,
        xPos: xPos,
        yPos: yPos,
        rotation: rotation,
        scale: scale,
        lastModifiedBy: lastModifiedBy,
      );
    } catch (e) {
      _state = _state.copyWith(error: e.toString());
      notifyListeners();
    }
  }

  Future<void> toggleReaction(
    String itemId,
    String userId,
    String emoji,
  ) async {
    try {
      // Optimistic update
      _state = _state.copyWith(
        activeItems:
            _state.activeItems.map((item) {
              if (item.id == itemId) {
                final reactions = Map<String, List<String>>.from(
                  item.reactions,
                );
                final List<String> users =
                    reactions[emoji] != null
                        ? List<String>.from(reactions[emoji]!)
                        : <String>[];
                if (users.contains(userId)) {
                  users.remove(userId);
                } else {
                  users.add(userId);
                }
                if (users.isEmpty) {
                  reactions.remove(emoji);
                } else {
                  reactions[emoji] = users;
                }
                return item.copyWith(reactions: reactions);
              }
              return item;
            }).toList(),
      );
      notifyListeners();

      await _repository.toggleCanvasItemReaction(
        itemId: itemId,
        userId: userId,
        emoji: emoji,
      );
    } catch (e) {
      _state = _state.copyWith(error: e.toString());
      notifyListeners();
    }
  }

  Future<void> setItemLock(String itemId, bool isLocked) async {
    try {
      _state = _state.copyWith(
        activeItems:
            _state.activeItems.map((item) {
              if (item.id == itemId) {
                return item.copyWith(isLocked: isLocked);
              }
              return item;
            }).toList(),
      );
      notifyListeners();

      await _repository.updateCanvasItemLock(itemId, isLocked);
    } catch (e) {
      _state = _state.copyWith(error: e.toString());
      notifyListeners();
    }
  }

  Future<void> deleteItem(String itemId) async {
    _state = _state.copyWith(
      activeItems: _state.activeItems.where((i) => i.id != itemId).toList(),
    );
    notifyListeners();
    try {
      await _repository.deleteCanvasItem(itemId);
    } catch (e) {
      _state = _state.copyWith(error: e.toString());
      notifyListeners();
    }
  }

  void clearError() {
    _state = _state.copyWith(clearError: true);
    notifyListeners();
  }

  void clear() {
    _realtimeSubscription?.cancel();
    _presenceSubscription?.cancel();
    _state = const CanvasState();
    notifyListeners();
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    _presenceSubscription?.cancel();
    super.dispose();
  }
}
