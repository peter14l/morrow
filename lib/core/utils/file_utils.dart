import 'package:universal_io/io.dart';
import 'package:flutter/material.dart';
import 'package:mime/mime.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart' as compress;
import 'package:path/path.dart' as path;

class FileUtils {
  /// Get file extension from filename
  static String getFileExtension(String fileName) {
    return path.extension(fileName).toLowerCase();
  }

  /// Get human-readable file size string
  static String getFileSizeString(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  /// Get icon for file type based on MIME type
  static IconData getFileIcon(String? mimeType) {
    if (mimeType == null) return Icons.insert_drive_file;

    if (mimeType.startsWith('image/')) {
      return Icons.image;
    } else if (mimeType.startsWith('video/')) {
      return Icons.video_file;
    } else if (mimeType.startsWith('audio/')) {
      return Icons.audio_file;
    } else if (mimeType.contains('pdf')) {
      return Icons.picture_as_pdf;
    } else if (mimeType.contains('word') || mimeType.contains('document')) {
      return Icons.description;
    } else if (mimeType.contains('sheet') || mimeType.contains('excel')) {
      return Icons.table_chart;
    } else if (mimeType.contains('presentation') ||
        mimeType.contains('powerpoint')) {
      return Icons.slideshow;
    } else if (mimeType.contains('zip') ||
        mimeType.contains('rar') ||
        mimeType.contains('archive')) {
      return Icons.folder_zip;
    } else if (mimeType.contains('text/')) {
      return Icons.text_snippet;
    } else {
      return Icons.insert_drive_file;
    }
  }

  /// Check if file type is supported
  static Future<bool> isFileTypeSupported(String mimeType) async {
    // Supported document types
    const supportedTypes = [
      'application/pdf',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'application/vnd.ms-excel',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'application/vnd.ms-powerpoint',
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'text/plain',
      'text/csv',
      'application/zip',
      'application/x-rar-compressed',
    ];

    // All images are supported
    if (mimeType.startsWith('image/')) {
      return true;
    }

    return supportedTypes.contains(mimeType);
  }

  /// Get MIME type from file
  static String? getMimeType(String filePath) {
    return lookupMimeType(filePath);
  }

  /// Compress image file
  static Future<File?> compressImage(File imageFile, {int quality = 85}) async {
    try {
      final filePath = imageFile.absolute.path;
      final lastIndex = filePath.lastIndexOf('.');
      final outPath =
          '${filePath.substring(0, lastIndex)}_compressed${filePath.substring(lastIndex)}';

      final result = await compress.FlutterImageCompress.compressAndGetFile(
        filePath,
        outPath,
        quality: quality,
        minWidth: 1920,
        minHeight: 1920,
      );

      if (result == null) return null;
      return File(result.path);
    } catch (e) {
      debugPrint('Error compressing image: $e');
      return null;
    }
  }

  /// Validate file size (returns true if valid)
  static bool validateFileSize(int bytes, {int maxSizeMB = 50}) {
    final maxBytes = maxSizeMB * 1024 * 1024;
    return bytes <= maxBytes;
  }

  /// Validate image size
  static bool validateImageSize(int bytes, {int maxSizeMB = 10}) {
    return validateFileSize(bytes, maxSizeMB: maxSizeMB);
  }

  /// Get file name from path
  static String getFileName(String filePath) {
    return path.basename(filePath);
  }

  /// Get file size
  static Future<int> getFileSize(File file) async {
    return await file.length();
  }

  /// Check if file exists
  static Future<bool> fileExists(String filePath) async {
    return await File(filePath).exists();
  }

  /// Delete file
  static Future<void> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error deleting file: $e');
    }
  }

  /// Get color for file type
  static Color getFileColor(String? mimeType) {
    if (mimeType == null) return Colors.grey;

    if (mimeType.contains('pdf')) {
      return Colors.red;
    } else if (mimeType.contains('word') || mimeType.contains('document')) {
      return Colors.blue;
    } else if (mimeType.contains('sheet') || mimeType.contains('excel')) {
      return Colors.green;
    } else if (mimeType.contains('presentation') ||
        mimeType.contains('powerpoint')) {
      return Colors.orange;
    } else if (mimeType.contains('zip') || mimeType.contains('rar')) {
      return const Color(0xFFF59E0B); // Amber
    } else if (mimeType.startsWith('image/')) {
      return const Color(0xFF2563EB); // Royal Blue
    } else if (mimeType.startsWith('video/')) {
      return const Color(0xFF10B981); // Emerald
    } else if (mimeType.startsWith('audio/')) {
      return Colors.teal;
    } else {
      return Colors.grey;
    }
  }
}
