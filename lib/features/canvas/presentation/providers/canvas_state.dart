import 'package:oasis/features/canvas/domain/models/canvas_models.dart';

/// Immutable state class for Canvas feature.
class CanvasState {
  final List<OasisCanvas> canvases;
  final OasisCanvas? activeCanvas;
  final List<CanvasItemEntity> activeItems;
  final bool isLoading;
  final String? error;
  final Map<String, CanvasPresenceEntity> presenceState;

  const CanvasState({
    this.canvases = const [],
    this.activeCanvas,
    this.activeItems = const [],
    this.isLoading = false,
    this.error,
    this.presenceState = const {},
  });

  CanvasState copyWith({
    List<OasisCanvas>? canvases,
    OasisCanvas? activeCanvas,
    bool clearActiveCanvas = false,
    List<CanvasItemEntity>? activeItems,
    bool? isLoading,
    String? error,
    bool clearError = false,
    Map<String, CanvasPresenceEntity>? presenceState,
  }) {
    return CanvasState(
      canvases: canvases ?? this.canvases,
      activeCanvas:
          clearActiveCanvas ? null : (activeCanvas ?? this.activeCanvas),
      activeItems: activeItems ?? this.activeItems,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      presenceState: presenceState ?? this.presenceState,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CanvasState &&
        other.isLoading == isLoading &&
        other.error == error &&
        other.activeCanvas == activeCanvas;
  }

  @override
  int get hashCode => Object.hash(isLoading, error, activeCanvas);
}

