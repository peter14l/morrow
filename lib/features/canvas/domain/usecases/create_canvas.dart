import 'package:oasis/features/canvas/domain/repositories/canvas_repository.dart';
import 'package:oasis/features/canvas/domain/models/canvas_models.dart';

/// Use case to create a new canvas.
class CreateCanvas {
  final CanvasRepository _repository;

  CreateCanvas(this._repository);

  Future<OasisCanvas> call({
    required String createdBy,
    required String title,
    required String coverColor,
    List<String> memberIds = const [],
  }) {
    return _repository.createCanvas(
      createdBy: createdBy,
      title: title,
      coverColor: coverColor,
      memberIds: memberIds,
    );
  }
}
