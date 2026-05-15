import 'package:universal_io/io.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:oasis/core/config/r2_config.dart';
import 'package:oasis/core/network/supabase_client.dart';
import 'package:oasis/services/subscription_service.dart';
import 'package:oasis/services/s3_storage_service.dart';
import 'package:oasis/services/media_cache_service.dart';
import 'package:oasis/features/messages/data/encryption_service.dart';

class MediaUploadResult {
  final String remoteUrl;
  final String localPath;
  final String fileId;
  final String iv;
  final Map<String, String> encryptedKeys;

  MediaUploadResult({
    required this.remoteUrl,
    required this.localPath,
    required this.fileId,
    required this.iv,
    required this.encryptedKeys,
  });
}

/// Service for managing secure media attachments in chat.
class ChatMediaService {
  final SupabaseClient _supabase;
  final SubscriptionService _subscriptionService;
  final S3StorageService _s3StorageService = S3StorageService();
  final MediaCacheService _mediaCacheService = MediaCacheService();
  final EncryptionService _encryptionService = EncryptionService();
  final _uuid = const Uuid();

  ChatMediaService({
    SupabaseClient? client,
    SubscriptionService? subscriptionService,
  }) : _supabase = client ?? SupabaseService().client,
       _subscriptionService = subscriptionService ?? SubscriptionService();

  /// Uploads media to Cloudflare R2 unencrypted (for backgrounds, etc.).
  Future<String> uploadChatMedia(
    String filePath, {
    String folder = 'images',
    Uint8List? encryptedBytes,
    String? fileExtension,
    Function(double)? onProgress,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');

      final file = File(filePath);
      if (!await file.exists()) throw Exception('File not found');

      final fileExt = fileExtension ?? filePath.split('.').last;
      final uniqueFileId =
          '${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4()}.$fileExt';
      final storagePath = '$userId/$uniqueFileId';

      final remoteUrl = await _s3StorageService.uploadFile(
        bucket: R2Config.r2BucketName,
        fileId: storagePath,
        type: folder,
        file: encryptedBytes == null ? file : null,
        bytes: encryptedBytes,
        contentType: encryptedBytes != null
            ? 'application/octet-stream'
            : 'application/$fileExt',
        onProgress: onProgress,
      );

      // Return the public access URL instead of the S3 endpoint
      // We must include the folder prefix as the edge function puts files in folder/userId/uniqueFileId
      return '${R2Config.r2PublicBaseUrl}/$folder/$storagePath';
    } catch (e) {
      debugPrint('[ChatMediaService] Upload Error: $e');
      rethrow;
    }
  }

  /// Uploads media to Cloudflare R2 with E2EE and local caching.
  Future<MediaUploadResult> uploadAndEncryptMedia({
    required String filePath,
    required String type, // 'images', 'videos', 'documents', 'recordings'
    required List<String> recipientPublicKeysPem,
    List<String>? recipientUserIds,
    String? recipientUserId,
    Function(double)? onProgress,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');

      final file = File(filePath);
      if (!await file.exists()) throw Exception('File not found');

      final totalSize = await file.length();

      // Check for 2GB limit for Free users
      if (!_subscriptionService.isPro) {
        const twoGBInBytes = 2 * 1024 * 1024 * 1024;
        if (totalSize > twoGBInBytes) {
          throw Exception('Files larger than 2GB require Oasis Pro.');
        }
      }

      // 1. Encrypt File
      final encryptionResult = await _encryptionService.encryptMediaFile(
        file: file,
        recipientPublicKeysPem: recipientPublicKeysPem,
        recipientUserIds: recipientUserIds,
        recipientUserId: recipientUserId,
      );
      final Uint8List encryptedBytes = encryptionResult['encryptedBytes'];
      final String iv = encryptionResult['iv'];
      final Map<String, String> encryptedKeys =
          encryptionResult['encryptedKeys'];

      // 2. Upload to Cloudflare R2
      final fileExt = filePath.split('.').last;
      // Enforce path: <type>/<user_id>/<file_id>
      final uniqueFileId =
          '${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4()}.$fileExt';
      final storagePath = '$userId/$uniqueFileId';

      final remoteUrl = await _s3StorageService.uploadFile(
        bucket: R2Config.r2BucketName,
        fileId: storagePath,
        type: type,
        bytes: encryptedBytes,
        contentType: 'application/octet-stream', // Encrypted bytes are opaque
        onProgress: onProgress,
      );

      // 3. Cache locally
      final localPath = await _mediaCacheService.saveToCache(
        await file.readAsBytes(), // Save original decrypted bytes locally
        uniqueFileId,
        type,
        remoteUrl,
      );

      return MediaUploadResult(
        remoteUrl: remoteUrl,
        localPath: localPath,
        fileId: storagePath,
        iv: iv,
        encryptedKeys: encryptedKeys,
      );
    } catch (e) {
      debugPrint('[ChatMediaService] Secure Upload Error: $e');
      rethrow;
    }
  }

  /// Downloads and decrypts media from Cloudflare R2.
  Future<String> downloadAndDecryptMedia({
    required String remoteUrl,
    required String type,
    required String fileId,
    required String iv,
    required Map<String, dynamic> encryptedKeys,
    String? senderId,
  }) async {
    try {
      // 1. Download encrypted bytes
      final encryptedBytes = await _s3StorageService.downloadFile(
        bucket: R2Config.r2BucketName,
        fileId: fileId,
        type: type,
      );

      // 2. Decrypt
      final decryptedBytes = await _encryptionService.decryptMediaFile(
        encryptedBytes: encryptedBytes,
        ivBase64: iv,
        encryptedKeys: encryptedKeys,
        senderId: senderId,
      );

      if (decryptedBytes == null) throw Exception('Decryption failed');

      // 3. Save to cache
      // fileId is "userId/filename.ext", we only want the filename for local cache
      final fileName = fileId.split('/').last;
      return await _mediaCacheService.saveToCache(
        decryptedBytes,
        fileName,
        type,
        remoteUrl,
      );
    } catch (e) {
      debugPrint('[ChatMediaService] Download/Decrypt Error: $e');
      rethrow;
    }
  }

  /// Deletes media from a given remote URL.
  Future<void> deleteMediaFromUrl(String url) async {
    try {
      if (!url.startsWith('http')) return;

      // Extract the file path component from the URL to determine type and fileId.
      // E.g., https://.../images/user-uuid/filename.ext?token=...
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;

      if (pathSegments.length >= 3) {
        // Assuming path is like /images/<userId>/<fileName>
        final type = pathSegments[pathSegments.length - 3];
        final userId = pathSegments[pathSegments.length - 2];
        final fileName = pathSegments.length > 0 ? pathSegments.last : '';

        final fileId = '$userId/$fileName';

        await _s3StorageService.deleteFile(
          bucket: R2Config.r2BucketName,
          fileId: fileId,
          type: type,
        );
      }
    } catch (e) {
      debugPrint('[ChatMediaService] Delete Error: $e');
    }
  }
}
