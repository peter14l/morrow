library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ATL-free Windows implementation of FlutterSecureStorage
class FlutterSecureStorageWindows extends FlutterSecureStoragePlatform {
  static void registerWith() {
    FlutterSecureStoragePlatform.instance = FlutterSecureStorageWindows();
  }

  static const String _storagePrefix = 'flutter_secure_storage_';
  
  // Improved deterministic key derivation for Windows Beta
  encrypt.Key _deriveKey() {
    // Combine project name with a machine-specific seed if available, 
    // fallback to a robust constant for consistent access.
    final machineSeed = Platform.environment['COMPUTERNAME'] ?? 'oasis_fallback_machine_id';
    final bytes = utf8.encode('oasis_v1_beta_secure_salt_$machineSeed');
    final digest = sha256.convert(bytes);
    return encrypt.Key(Uint8List.fromList(digest.bytes));
  }

  encrypt.IV _deriveIV(String key) {
    // IV should be deterministic per key for SharedPreferences storage
    final bytes = utf8.encode('oasis_iv_seed_$key');
    final digest = sha256.convert(bytes);
    return encrypt.IV(Uint8List.fromList(digest.bytes.sublist(0, 16)));
  }

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('$_storagePrefix$key');
  }

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_storagePrefix$key');
  }

  @override
  Future<void> deleteAll({
    required Map<String, String> options,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_storagePrefix));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final rawValue = prefs.getString('$_storagePrefix$key');

    if (rawValue == null) return null;
    // Guard against corrupted files (e.g. file filled with null bytes or zeros)
    if (rawValue.isEmpty || 
        rawValue.runes.every((r) => r == 0) || 
        rawValue.runes.every((r) => r == 48)) { // 48 is ASCII '0'
      return null;
    }

    try {
      final encrypter = encrypt.Encrypter(encrypt.AES(_deriveKey()));
      final decrypted = encrypter.decrypt(
        encrypt.Encrypted.fromBase64(rawValue),
        iv: _deriveIV(key),
      );
      
      // If decrypted content is also just zeros/nulls, ignore it
      if (decrypted.runes.every((r) => r == 0)) return null;
      
      return decrypted;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys().where((k) => k.startsWith(_storagePrefix));
    final result = <String, String>{};

    for (final storageKey in allKeys) {
      final key = storageKey.replaceFirst(_storagePrefix, '');
      final value = await read(key: key, options: options);
      if (value != null) {
        result[key] = value;
      }
    }
    return result;
  }

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final encrypter = encrypt.Encrypter(encrypt.AES(_deriveKey()));
    final encrypted = encrypter.encrypt(value, iv: _deriveIV(key));
    await prefs.setString('$_storagePrefix$key', encrypted.base64);
  }
}
