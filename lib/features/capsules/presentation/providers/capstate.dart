import 'package:oasis/features/capsules/domain/models/time_capsule_entity.dart';

/// Immutable state for Capsule feature
class CapsuleState {
  final List<TimeCapsule> capsules;
  final List<TimeCapsule> unlockedCapsules;
  final TimeCapsule? selectedCapsule;
  final bool isLoading;
  final bool isCreating;
  final String? error;

  const CapsuleState({
    this.capsules = const [],
    this.unlockedCapsules = const [],
    this.selectedCapsule,
    this.isLoading = false,
    this.isCreating = false,
    this.error,
  });

  CapsuleState copyWith({
    List<TimeCapsule>? capsules,
    List<TimeCapsule>? unlockedCapsules,
    TimeCapsule? selectedCapsule,
    bool? isLoading,
    bool? isCreating,
    String? error,
    bool clearSelectedCapsule = false,
    bool clearError = false,
  }) {
    return CapsuleState(
      capsules: capsules ?? this.capsules,
      unlockedCapsules: unlockedCapsules ?? this.unlockedCapsules,
      selectedCapsule: clearSelectedCapsule
          ? null
          : (selectedCapsule ?? this.selectedCapsule),
      isLoading: isLoading ?? this.isLoading,
      isCreating: isCreating ?? this.isCreating,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
