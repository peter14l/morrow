import '../models/call_entity.dart';
import '../repositories/call_repository.dart';

/// Use case for accepting an incoming call
class AcceptCall {
  final CallRepository _repository;

  AcceptCall(this._repository);

  /// Accept an incoming call
  Future<CallEntity> call({
    required String callId,
    required String userId,
  }) {
    return _repository.acceptCall(
      callId: callId,
      userId: userId,
    );
  }
}
