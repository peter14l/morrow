import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:oasis/core/network/supabase_client.dart';
import 'package:oasis/core/config/b2_config.dart';

class S3StorageService {
  final Dio _dio = Dio();
  final _supabase = SupabaseService().client;

  /// Gets a pre-signed URL from the Supabase Edge Function
  Future<Map<String, dynamic>> _getPresignedUrl({
    required String bucket,
    required String fileId,
    required String type,
    required String method,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        B2Config.presignedUrlFunctionName,
        body: {
          'bucket': bucket,
          'fileId': fileId,
          'type': type,
          'method': method,
        },
      );

      if (response.status != 200) {
        throw Exception('Failed to get presigned URL: ${response.data}');
      }

      return response.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[S3StorageService] Error getting presigned URL: $e');
      rethrow;
    }
  }

  /// Uploads a file (or bytes) to the specified bucket via a pre-signed URL
  Future<String> uploadFile({
    required String bucket,
    required String fileId,
    required String type,
    File? file,
    Uint8List? bytes,
    String? contentType,
    Function(double)? onProgress,
  }) async {
    try {
      final presignedData = await _getPresignedUrl(
        bucket: bucket,
        fileId: fileId,
        type: type,
        method: 'PUT',
      );

      final String url = presignedData['url'];
      final dynamic data = bytes ?? (file?.openRead());
      if (data == null) throw Exception('No data to upload');

      final int totalSize =
          bytes?.length ?? (file != null ? await file.length() : 0);

      await _dio.put(
        url,
        data: data,
        options: Options(
          headers: {
            if (contentType != null) 'Content-Type': contentType,
            'Content-Length': totalSize.toString(),
          },
        ),
        onSendProgress: (sent, total) {
          if (onProgress != null && totalSize > 0) {
            onProgress(sent / totalSize);
          }
        },
      );

      return url.split('?').first; // Return the base URL without query params
    } catch (e) {
      debugPrint('[S3StorageService] Upload error: $e');
      rethrow;
    }
  }

  /// Downloads a file from the specified bucket via a pre-signed URL
  Future<Uint8List> downloadFile({
    required String bucket,
    required String fileId,
    required String type,
  }) async {
    try {
      final presignedData = await _getPresignedUrl(
        bucket: bucket,
        fileId: fileId,
        type: type,
        method: 'GET',
      );

      final String url = presignedData['url'];
      final response = await _dio.get<Uint8List>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.data == null) throw Exception('Download returned no data');
      return response.data!;
    } catch (e) {
      debugPrint('[S3StorageService] Download error: $e');
      rethrow;
    }
  }

  /// Deletes a file from the specified bucket via a pre-signed URL
  Future<void> deleteFile({
    required String bucket,
    required String fileId,
    required String type,
  }) async {
    try {
      final presignedData = await _getPresignedUrl(
        bucket: bucket,
        fileId: fileId,
        type: type,
        method: 'DELETE',
      );

      final String url = presignedData['url'];
      final response = await _dio.delete(url);

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Delete failed with status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[S3StorageService] Delete error: $e');
      rethrow;
    }
  }
}
