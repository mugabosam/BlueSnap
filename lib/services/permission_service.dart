/// BlueSnap Permission Service
/// Handles runtime permissions for Bluetooth, location, and media
library;

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._();
  factory PermissionService() => _instance;
  PermissionService._();

  /// Request all permissions needed for Bluetooth scanning and advertising
  Future<bool> requestBluetoothPermissions() async {
    // Request location first (required for Bluetooth scanning on Android)
    final locationStatus = await Permission.location.request();
    final locationWhenInUseStatus = await Permission.locationWhenInUse.request();
    
    // On Android 12+ (API 31+), need these new permissions
    final permissions = <Permission>[
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.nearbyWifiDevices,
    ];

    final statuses = await permissions.request();

    // Check if all critical permissions granted
    final bluetoothScanGranted = statuses[Permission.bluetoothScan]?.isGranted ?? false;
    final bluetoothAdvertiseGranted = statuses[Permission.bluetoothAdvertise]?.isGranted ?? false;
    final bluetoothConnectGranted = statuses[Permission.bluetoothConnect]?.isGranted ?? false;
    final locationGranted = locationStatus.isGranted || locationWhenInUseStatus.isGranted;

    debugPrint('[Permissions] Bluetooth Scan: $bluetoothScanGranted');
    debugPrint('[Permissions] Bluetooth Advertise: $bluetoothAdvertiseGranted');
    debugPrint('[Permissions] Bluetooth Connect: $bluetoothConnectGranted');
    debugPrint('[Permissions] Location (any): $locationGranted');

    return bluetoothScanGranted && 
           bluetoothAdvertiseGranted && 
           bluetoothConnectGranted && 
           locationGranted;
  }

  /// Check if Bluetooth permissions are already granted
  Future<bool> hasBluetoothPermissions() async {
    final bluetoothScan = await Permission.bluetoothScan.isGranted;
    final bluetoothAdvertise = await Permission.bluetoothAdvertise.isGranted;
    final bluetoothConnect = await Permission.bluetoothConnect.isGranted;
    final location = await Permission.location.isGranted;
    final locationWhenInUse = await Permission.locationWhenInUse.isGranted;

    return bluetoothScan && 
           bluetoothAdvertise && 
           bluetoothConnect && 
           (location || locationWhenInUse);
  }

  /// Request camera permission for stories/posts
  Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// Request media permissions for file sharing
  Future<bool> requestMediaPermissions() async {
    final permissions = <Permission>[
      Permission.photos,
      Permission.videos,
    ];

    final statuses = await permissions.request();
    return statuses.values.every((status) => status.isGranted);
  }

  /// Open app settings if permissions permanently denied
  Future<void> openAppSettings() async {
    await openAppSettings();
  }

  /// Get detailed permission status for UI display
  Future<Map<String, bool>> getPermissionStatus() async {
    return {
      'bluetoothScan': await Permission.bluetoothScan.isGranted,
      'bluetoothAdvertise': await Permission.bluetoothAdvertise.isGranted,
      'bluetoothConnect': await Permission.bluetoothConnect.isGranted,
      'location': await Permission.locationWhenInUse.isGranted,
      'camera': await Permission.camera.isGranted,
      'photos': await Permission.photos.isGranted,
    };
  }

  /// Get detailed permission status for diagnostics
  Future<Map<String, bool>> checkDetailedPermissions() async {
    return {
      'Bluetooth Scan': await Permission.bluetoothScan.isGranted,
      'Bluetooth Advertise': await Permission.bluetoothAdvertise.isGranted,
      'Bluetooth Connect': await Permission.bluetoothConnect.isGranted,
      'Location (When In Use)': await Permission.locationWhenInUse.isGranted,
      'Location (Always)': await Permission.locationAlways.isGranted,
      'Location': await Permission.location.isGranted,
      'Nearby WiFi Devices': await Permission.nearbyWifiDevices.isGranted,
    };
  }
}
