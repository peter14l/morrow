import 'package:flutter/foundation.dart';
import 'package:oasis/core/storage/prefs_storage.dart';
import 'package:oasis/features/couples/data/partner_repository.dart';

class PartnerProvider extends ChangeNotifier {
  // -------------------------------------------------------------------------
  // Dependencies
  // -------------------------------------------------------------------------
  final PartnerRepository _repository;
  final PrefsStorage _prefs;

  // -------------------------------------------------------------------------
  // State
  // -------------------------------------------------------------------------
  PartnerProfile? _currentPartner;
  List<PartnerInvite> _pendingInvites = [];
  bool _isLoading = false;
  bool _isSending = false;
  String? _error;
  String? _sentInviteReceiverId;
  bool _partnerNotifyEnabled = true;

  // -------------------------------------------------------------------------
  // Constructor
  // -------------------------------------------------------------------------
  PartnerProvider()
      : _repository = PartnerRepository(),
        _prefs = PrefsStorage() {
    _loadNotifyPref();
    load();
  }

  // -------------------------------------------------------------------------
  // Getters
  // -------------------------------------------------------------------------
  PartnerProfile? get currentPartner => _currentPartner;
  List<PartnerInvite> get pendingInvites => List.unmodifiable(_pendingInvites);
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get error => _error;
  String? get sentInviteReceiverId => _sentInviteReceiverId;
  bool get partnerNotifyEnabled => _partnerNotifyEnabled;

  // -------------------------------------------------------------------------
  // load
  // -------------------------------------------------------------------------
  /// Loads partner, pending invites, and sent invite concurrently.
  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _repository.getCurrentPartner(),
        _repository.getPendingInvites(),
        _repository.getSentPendingInvite(),
      ]);

      _currentPartner = results[0] as PartnerProfile?;
      _pendingInvites = results[1] as List<PartnerInvite>;
      _sentInviteReceiverId = results[2] as String?;
    } catch (e, st) {
      debugPrint('[PartnerProvider.load] error: $e\n$st');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // -------------------------------------------------------------------------
  // sendInvite
  // -------------------------------------------------------------------------
  Future<bool> sendInvite(String userId) async {
    _isSending = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _repository.sendInvite(userId);
      if (success) {
        _sentInviteReceiverId = userId;
      }
      return success;
    } catch (e, st) {
      debugPrint('[PartnerProvider.sendInvite] error: $e\n$st');
      _error = e.toString();
      return false;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  // -------------------------------------------------------------------------
  // acceptInvite
  // -------------------------------------------------------------------------
  Future<bool> acceptInvite(String inviteId, String senderId) async {
    try {
      final success = await _repository.acceptInvite(inviteId, senderId);
      if (success) await load();
      return success;
    } catch (e, st) {
      debugPrint('[PartnerProvider.acceptInvite] error: $e\n$st');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // -------------------------------------------------------------------------
  // declineInvite
  // -------------------------------------------------------------------------
  Future<bool> declineInvite(String inviteId) async {
    try {
      final success = await _repository.declineInvite(inviteId);
      if (success) await load();
      return success;
    } catch (e, st) {
      debugPrint('[PartnerProvider.declineInvite] error: $e\n$st');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // -------------------------------------------------------------------------
  // dissolvePartnership
  // -------------------------------------------------------------------------
  Future<bool> dissolvePartnership() async {
    try {
      final success = await _repository.dissolvePartnership();
      if (success) await load();
      return success;
    } catch (e, st) {
      debugPrint('[PartnerProvider.dissolvePartnership] error: $e\n$st');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // -------------------------------------------------------------------------
  // setPartnerNotify
  // -------------------------------------------------------------------------
  void setPartnerNotify(bool value) async {
    _partnerNotifyEnabled = value;
    notifyListeners();
    await _prefs.writeBool('partner_notify_enabled', value);
  }

  // -------------------------------------------------------------------------
  // _loadNotifyPref
  // -------------------------------------------------------------------------
  void _loadNotifyPref() {
    _partnerNotifyEnabled = _prefs.readBool('partner_notify_enabled') ?? true;
  }

  // -------------------------------------------------------------------------
  // clearError
  // -------------------------------------------------------------------------
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
