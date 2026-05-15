import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

class PermissionUtils {
  /// Request camera permission
  static Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// Request gallery/photos permission
  static Future<bool> requestGalleryPermission() async {
    final status = await Permission.photos.request();
    if (status.isGranted) return true;

    // For Android, try storage permission
    final storageStatus = await Permission.storage.request();
    return storageStatus.isGranted;
  }

  /// Request microphone permission
  static Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Request location permission
  static Future<bool> requestLocationPermission() async {
    final status = await Permission.locationWhenInUse.request();
    return status.isGranted;
  }

  /// Request storage permission
  static Future<bool> requestStoragePermission() async {
    final status = await Permission.storage.request();
    return status.isGranted;
  }

  /// Check if camera permission is granted
  static Future<bool> isCameraPermissionGranted() async {
    return await Permission.camera.isGranted;
  }

  /// Check if gallery permission is granted
  static Future<bool> isGalleryPermissionGranted() async {
    final photosGranted = await Permission.photos.isGranted;
    final storageGranted = await Permission.storage.isGranted;
    return photosGranted || storageGranted;
  }

  /// Check if microphone permission is granted
  static Future<bool> isMicrophonePermissionGranted() async {
    return await Permission.microphone.isGranted;
  }

  /// Check if location permission is granted
  static Future<bool> isLocationPermissionGranted() async {
    return await Permission.locationWhenInUse.isGranted;
  }

  /// Open app settings
  static Future<void> openAppSettings() async {
    await openAppSettings();
  }

  /// Show permission denied dialog
  static void showPermissionDeniedDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  /// Request permission with user-friendly error handling
  static Future<bool> requestPermissionWithDialog(
    BuildContext context, {
    required Permission permission,
    required String permissionName,
    required String reason,
  }) async {
    final status = await permission.request();

    if (status.isGranted) {
      return true;
    } else if (status.isPermanentlyDenied) {
      if (context.mounted) {
        showPermissionDeniedDialog(
          context,
          title: '$permissionName Permission Required',
          message:
              'This app needs $permissionName permission to $reason. Please enable it in settings.',
        );
      }
      return false;
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$permissionName permission denied'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () {
                requestPermissionWithDialog(
                  context,
                  permission: permission,
                  permissionName: permissionName,
                  reason: reason,
                );
              },
            ),
          ),
        );
      }
      return false;
    }
  }

  /// Request camera with dialog
  static Future<bool> requestCameraWithDialog(BuildContext context) async {
    return requestPermissionWithDialog(
      context,
      permission: Permission.camera,
      permissionName: 'Camera',
      reason: 'take photos',
    );
  }

  /// Request gallery with dialog
  static Future<bool> requestGalleryWithDialog(BuildContext context) async {
    return requestPermissionWithDialog(
      context,
      permission: Permission.photos,
      permissionName: 'Gallery',
      reason: 'select photos',
    );
  }

  /// Request microphone with dialog
  static Future<bool> requestMicrophoneWithDialog(BuildContext context) async {
    return requestPermissionWithDialog(
      context,
      permission: Permission.microphone,
      permissionName: 'Microphone',
      reason: 'record voice messages',
    );
  }

  /// Request location with dialog
  static Future<bool> requestLocationWithDialog(BuildContext context) async {
    return requestPermissionWithDialog(
      context,
      permission: Permission.locationWhenInUse,
      permissionName: 'Location',
      reason: 'share your location',
    );
  }
}
