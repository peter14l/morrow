import '../models/call_entity.dart';

/// Abstract repository interface for call operations
abstract class CallRepository {
  /// Create a new call
  Future<CallEntity> createCall({
    required String conversationId,
    required String callerId,
    required String receiverId,
    required CallType type,
  });

  /// Get call by ID
  Future<CallEntity?> getCall(String callId);

  /// Get active calls for user
  Future<List<CallEntity>> getActiveCalls(String userId);

  /// Accept incoming call
  Future<CallEntity> acceptCall({
    required String callId,
    required String userId,
  });

  /// Decline incoming call
  Future<void> declineCall(String callId, String userId);

  /// End a call
  Future<CallEntity> endCall(String callId);

  /// Stream of call updates
  Stream<CallEntity> watchCall(String callId);
}
