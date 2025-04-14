import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// A utility class to handle permissions for the app
class PermissionUtil {
  /// Check if the device is running Android 11 (API 30) or higher
  static Future<bool> isAndroid11OrHigher() async {
    if (!Platform.isAndroid) return false;

    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.version.sdkInt >= 30; // Android 11 is API 30
    } catch (e) {
      debugPrint('Error checking Android version: $e');
      return false;
    }
  }

  /// Request storage permissions based on the Android version
  static Future<bool> requestStoragePermissions(BuildContext context) async {
    debugPrint('Checking storage permissions...');

    // For app-specific storage, we don't need special permissions
    // This is the recommended approach for most apps
    debugPrint(
      'Using app-specific storage which doesn\'t require special permissions',
    );
    return true;
  }

  /// Get a writable directory for saving recordings
  static Future<String?> getWritableDirectory() async {
    try {
      // Get the app-specific directory which doesn't require special permissions
      final appDir = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${appDir.path}/recordings');

      // Create the directory if it doesn't exist
      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
      }

      // Test if the directory is writable
      final testFile = File('${recordingsDir.path}/test_write.tmp');
      await testFile.writeAsString('test');
      await testFile.delete();

      debugPrint('Using app-specific directory: ${recordingsDir.path}');
      return recordingsDir.path;
    } catch (e) {
      debugPrint('Error getting writable directory: $e');
      return null;
    }
  }
}
