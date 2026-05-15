import 'package:flutter/foundation.dart';
import 'package:oasis/features/capsules/data/repositories/capsule_repository_impl.dart';
import 'package:oasis/features/capsules/domain/models/time_capsule_entity.dart';
import 'package:oasis/features/capsules/domain/repositories/capsule_repository.dart';
import 'package:oasis/features/capsules/domain/usecases/create_capsule.dart';
import 'package:oasis/features/capsules/domain/usecases/get_capsules.dart';
import 'package:oasis/features/capsules/domain/usecases/open_capsule.dart';
import 'package:oasis/features/capsules/presentation/providers/capstate.dart'
    show CapsuleState;

/// Provider for Capsule feature using Clean Architecture
class CapsuleProvider extends ChangeNotifier {
  final CapsuleRepository _repository = CapsuleRepositoryImpl();

  // Use cases
  final GetCapsules _getCapsules = GetCapsules(CapsuleRepositoryImpl());
  final CreateCapsule _createCapsule = CreateCapsule(CapsuleRepositoryImpl());
  final OpenCapsule _openCapsule = OpenCapsule(CapsuleRepositoryImpl());

  CapsuleState _state = const CapsuleState();

  CapsuleState get state => _state;
  List<TimeCapsule> get capsules => _state.capsules;
  List<TimeCapsule> get unlockedCapsules => _state.unlockedCapsules;
  TimeCapsule? get selectedCapsule => _state.selectedCapsule;
  bool get isLoading => _state.isLoading;
  bool get isCreating => _state.isCreating;
  String? get error => _state.error;

  /// Load all capsules for a user
  Future<void> loadCapsules(String userId) async {
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    try {
      final capsules = await _getCapsules(userId: userId);
      _state = _state.copyWith(capsules: capsules, isLoading: false);
    } catch (e) {
      _state = _state.copyWith(error: e.toString(), isLoading: false);
      debugPrint('Error loading capsules: $e');
    }
    notifyListeners();
  }

  /// Load unlocked capsules only
  Future<void> loadUnlockedCapsules(String userId) async {
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    try {
      final capsules = await _repository.getCapsules(userId: userId);
      final unlocked = capsules.where((c) => !c.isLocked).toList();
      _state = _state.copyWith(unlockedCapsules: unlocked, isLoading: false);
    } catch (e) {
      _state = _state.copyWith(error: e.toString(), isLoading: false);
    }
    notifyListeners();
  }

  /// Create a new capsule
  Future<TimeCapsule?> createCapsule({
    required String userId,
    required String content,
    required DateTime unlockDate,
    String? mediaUrl,
    String mediaType = 'none',
  }) async {
    _state = _state.copyWith(isCreating: true, clearError: true);
    notifyListeners();

    try {
      final capsule = await _createCapsule(
        userId: userId,
        content: content,
        unlockDate: unlockDate,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
      );
      _state = _state.copyWith(
        capsules: [capsule, ..._state.capsules],
        isCreating: false,
      );
      notifyListeners();
      return capsule;
    } catch (e) {
      _state = _state.copyWith(error: e.toString(), isCreating: false);
      debugPrint('Error creating capsule: $e');
      notifyListeners();
      return null;
    }
  }

  /// Open/unlock a capsule
  Future<void> openCapsule(String capsuleId) async {
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    try {
      final opened = await _openCapsule(capsuleId);
      final updatedCapsules = _state.capsules.map((c) {
        return c.id == capsuleId ? opened : c;
      }).toList();
      _state = _state.copyWith(
        capsules: updatedCapsules,
        selectedCapsule: opened,
        isLoading: false,
      );
    } catch (e) {
      _state = _state.copyWith(error: e.toString(), isLoading: false);
    }
    notifyListeners();
  }

  /// Select a capsule for viewing
  void selectCapsule(TimeCapsule capsule) {
    _state = _state.copyWith(selectedCapsule: capsule);
    notifyListeners();
  }

  /// Clear selected capsule
  void clearSelectedCapsule() {
    _state = _state.copyWith(clearSelectedCapsule: true);
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _state = _state.copyWith(clearError: true);
    notifyListeners();
  }
}
