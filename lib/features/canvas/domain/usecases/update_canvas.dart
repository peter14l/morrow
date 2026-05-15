import 'package:oasis/features/canvas/domain/repositories/canvas_repository.dart';
import 'package:oasis/features/canvas/domain/models/canvas_models.dart';

/// Use case to update canvas details.
class UpdateCanvas {
  final CanvasRepository _repository;

  UpdateCanvas(this._repository);

  Future<OasisCanvas> call({
    required String canvasId,
    String? title,
    String? coverColor,
  }) {
    return _repository.updateCanvas(
      canvasId: canvasId,
      title: title,
      coverColor: coverColor,
    );
  }
}
