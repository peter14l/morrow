import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Model representing a logged-in account in the registry
class RegisteredAccount {
  final String userId;
  final String email;
  final String username;
  final String? fullName;
  final String? avatarUrl;
  final Session session;
  final DateTime lastUsed;

  RegisteredAccount({
    required this.userId,
    required this.email,
    required this.username,
    this.fullName,
    this.avatarUrl,
    required this.session,
    required this.lastUsed,
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'email': email,
    'username': username,
    'fullName': fullName,
    'avatarUrl': avatarUrl,
    'session': session.toJson(),
    'lastUsed': lastUsed.toIso8601String(),
  };

  factory RegisteredAccount.fromJson(Map<String, dynamic> json) =>
      RegisteredAccount(
        userId: json['userId'] as String? ?? '',
        email: json['email'] as String? ?? '',
        username: json['username'] as String? ?? 'user',
        fullName: json['fullName'] as String?,
        avatarUrl:
            json['avatar_url'] as String? ?? json['avatarUrl'] as String?,
        session: Session.fromJson(json['session'] ?? {})!,
        lastUsed: json['lastUsed'] != null
            ? DateTime.parse(json['lastUsed'] as String)
            : DateTime.now(),
      );

  RegisteredAccount copyWith({
    String? username,
    String? fullName,
    String? avatarUrl,
    Session? session,
    DateTime? lastUsed,
  }) => RegisteredAccount(
    userId: userId,
    email: email,
    username: username ?? this.username,
    fullName: fullName ?? this.fullName,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    session: session ?? this.session,
    lastUsed: lastUsed ?? this.lastUsed,
  );
}

/// Service to manage the registry of active user sessions on this device
class SessionRegistryService {
  static final SessionRegistryService _instance =
      SessionRegistryService._internal();
  factory SessionRegistryService() => _instance;
  SessionRegistryService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _registryKey = 'oasis_account_registry';

  // Synchronization lock to prevent race conditions during read/write
  Future<void> _lock = Future.value();

  Future<T> _synchronized<T>(Future<T> Function() computation) async {
    final previousLock = _lock;
    final completer = Completer<void>();
    _lock = completer.future;

    try {
      await previousLock;
      return await computation();
    } finally {
      completer.complete();
    }
  }

  /// Get all registered accounts
  Future<List<RegisteredAccount>> getAllAccounts() async {
    return _synchronized(() async {
      try {
        debugPrint('[SessionRegistry] Reading registry from storage...');
        final data = await _storage.read(key: _registryKey);

        if (data == null) {
          debugPrint('[SessionRegistry] No registry data found');
          return [];
        }

        // Guard against corrupted files (e.g. file filled with zeros/nulls)
        if (data.trim().isEmpty ||
            data.runes.every((r) => r == 0) ||
            data.runes.every((r) => r == 48)) {
          debugPrint(
            '[SessionRegistry] Detected corrupted data (zeros or empty), ignoring.',
          );
          return [];
        }

        final List<dynamic> decoded = jsonDecode(data);
        debugPrint('[SessionRegistry] Decoding ${decoded.length} accounts');

        final List<RegisteredAccount> accounts = [];
        for (var i = 0; i < decoded.length; i++) {
          try {
            final item = decoded[i];
            if (item is Map<String, dynamic>) {
              accounts.add(RegisteredAccount.fromJson(item));
            }
          } catch (e) {
            debugPrint(
              '[SessionRegistry] ERROR parsing account at index $i: $e',
            );
            // We skip this one but keep others
          }
        }

        debugPrint(
          '[SessionRegistry] Successfully loaded ${accounts.length} accounts',
        );
        return accounts;
      } catch (e) {
        debugPrint(
          '[SessionRegistry] CRITICAL ERROR reading/parsing registry: $e',
        );
        return [];
      }
    });
  }

  /// Add or update an account in the registry
  Future<void> saveAccount(RegisteredAccount account) async {
    await _synchronized(() async {
      final accounts = await _getAllAccountsNoLock();
      final index = accounts.indexWhere((a) => a.userId == account.userId);

      if (index >= 0) {
        accounts[index] = account;
      } else {
        accounts.add(account);
      }

      await _persist(accounts);
    });
  }

  /// Remove an account from the registry
  Future<void> removeAccount(String userId) async {
    await _synchronized(() async {
      final accounts = await _getAllAccountsNoLock();
      accounts.removeWhere((a) => a.userId == userId);
      await _persist(accounts);
    });
  }

  /// Update just the last used timestamp for an account
  Future<void> markAsUsed(String userId) async {
    await _synchronized(() async {
      final accounts = await _getAllAccountsNoLock();
      final index = accounts.indexWhere((a) => a.userId == userId);
      if (index >= 0) {
        accounts[index] = accounts[index].copyWith(lastUsed: DateTime.now());
        await _persist(accounts);
      }
    });
  }

  /// Clear the entire registry
  Future<void> clearAll() async {
    await _synchronized(() async {
      await _storage.delete(key: _registryKey);
    });
  }

  Future<List<RegisteredAccount>> _getAllAccountsNoLock() async {
    try {
      final data = await _storage.read(key: _registryKey);
      if (data == null) return [];

      if (data.isEmpty ||
          data.runes.every((r) => r == 0) ||
          data.runes.every((r) => r == 48)) {
        return [];
      }

      final List<dynamic> decoded = jsonDecode(data);
      return decoded.map((item) => RegisteredAccount.fromJson(item)).toList();
    } catch (e) {
      debugPrint('[SessionRegistry] ERROR in _getAllAccountsNoLock: $e');
      return [];
    }
  }

  Future<void> _persist(List<RegisteredAccount> accounts) async {
    final data = jsonEncode(accounts.map((a) => a.toJson()).toList());
    await _storage.write(key: _registryKey, value: data);
  }
}
