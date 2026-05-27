import '../models/call_entity.dart';
import '../repositories/call_repository.dart';

/// Use case for initiating a new call
class InitiateCall {
  final CallRepository _repository;

  InitiateCall(this._repository);

  /// Initiate a voice or video call
  Future<CallEntity> call({
    required String conversationId,
    required String callerId,
    required String receiverId,
    required CallType type,
    Map<String, dynamic>? offer,
  }) {
    return _repository.createCall(
      conversationId: conversationId,
      callerId: callerId,
      receiverId: receiverId,
      type: type,
      offer: offer,
    );
  }
}
