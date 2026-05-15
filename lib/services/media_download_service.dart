import 'package:universal_io/io.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:gal/gal.dart';
import 'package:oasis/core/network/supabase_client.dart';

import 'package:oasis/core/config/feature_flags.dart';
import 'package:url_launcher/url_launcher.dart';

class MediaDownloadService {
  final Dio _dio = Dio();

  /// Download an image and save to gallery
  Future<bool> downloadImage(
    String url,
    BuildContext context, {
    bool isOwnContent = false,
  }) async {
    try {
      if (kIsWeb) {
        // For web, just launch the URL to trigger browser download
        return await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
      }

      // Request storage permission (Mobile only)
      if (FeatureFlags.isMobile) {
        if (!await _requestPermission()) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Storage permission denied'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return false;
        }
      }

      // Show downloading snackbar
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 16),
                Text('Downloading image...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final fileName = 'oasis_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '${tempDir.path}/$fileName';

      // Download file
      await _dio.download(url, filePath);

      // Save to gallery
      await Gal.putImage(filePath);

      // Clean up temp file
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

      return true;
    } catch (e) {
      debugPrint('Error downloading image: $e');
      rethrow;
    }
  }

  /// Download a video and save to gallery
  Future<bool> downloadVideo(
    String url,
    BuildContext context, {
    bool isOwnContent = false,
  }) async {
    try {
      // Request storage permission
      if (!await _requestPermission()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Storage permission denied'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }

      // Show downloading snackbar
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 16),
                Text('Downloading video...'),
              ],
            ),
            duration: Duration(seconds: 60),
          ),
        );
      }

      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final fileName = 'oasis_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final filePath = '${tempDir.path}/$fileName';

      // Download file
      await _dio.download(url, filePath);

      // Save to gallery
      await Gal.putVideo(filePath);

      // Clean up temp file
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

      return true;
    } catch (e) {
      debugPrint('Error downloading video: $e');
      rethrow;
    }
  }

  /// Download a document and save to Downloads folder
  Future<bool> downloadDocument(
    String url,
    String fileName,
    BuildContext context, {
    bool isOwnContent = false,
  }) async {
    try {
      // Request storage permission
      if (!await _requestPermission()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Storage permission denied'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }

      // Show downloading snackbar
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 16),
                Text('Downloading $fileName...'),
              ],
            ),
            duration: const Duration(seconds: 30),
          ),
        );
      }

      // Get downloads directory
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download/Oasis');
      } else if (Platform.isIOS) {
        downloadsDir = await getApplicationDocumentsDirectory();
      } else {
        downloadsDir = await getDownloadsDirectory();
      }

      if (downloadsDir == null) {
        throw Exception('Could not access downloads directory');
      }

      // Create Oasis folder if it doesn't exist
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      final filePath = '${downloadsDir.path}/$fileName';

      // Download file
      await _dio.download(url, filePath);

      return true;
    } catch (e) {
      debugPrint('Error downloading document: $e');
      rethrow;
    }
  }

  /// Request storage permission
  Future<bool> _requestPermission() async {
    if (Platform.isAndroid) {
      // For Android 13+ (API 33+), we need different permissions
      if (await Permission.photos.isGranted ||
          await Permission.storage.isGranted) {
        return true;
      }

      // Request permission
      final photoStatus = await Permission.photos.request();
      final storageStatus = await Permission.storage.request();

      return photoStatus.isGranted || storageStatus.isGranted;
    } else if (Platform.isIOS) {
      final status = await Permission.photos.request();
      return status.isGranted;
    }

    // For other platforms (Windows, etc.), assume permission is granted
    return true;
  }
}
