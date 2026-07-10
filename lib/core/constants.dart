/// BlueSnap core constants
library;

import 'package:flutter/material.dart';

// ── App Info ──────────────────────────────────────────────
class AppConstants {
  static const String appName = 'BlueSnap';
  static const String appVersion = '1.0.0';
  static const String appTagline = 'Connect locally. Zero internet.';

  // BLE Service UUIDs (custom for BlueSnap protocol)
  static const String bleServiceUuid = '0000bsna-0000-1000-8000-00805f9b34fb';
  static const String bleCharMessageUuid = '0000bsm1-0000-1000-8000-00805f9b34fb';
  static const String bleCharPresenceUuid = '0000bsp1-0000-1000-8000-00805f9b34fb';
  static const String bleCharFileUuid = '0000bsf1-0000-1000-8000-00805f9b34fb';

  // Bluetooth
  static const int bleScanDurationSeconds = 10;
  static const int bleAdvertiseIntervalMs = 500;
  static const int maxBluetoothRange = 100; // meters
  static const int meshMaxHops = 5;
  static const int chunkSizeBytes = 65536; // 64KB chunks for file transfer

  // Media
  static const int maxImageWidth = 1080;
  static const int imageQuality = 75;
  static const int maxVideoSeconds = 60;
  static const int maxFileSizeMb = 20;
  static const int thumbnailSize = 200;

  // Stories
  static const int storyExpiryHours = 24;
  static const int snapExpirySeconds = 10;

  // Discovery
  static const int radarRefreshMs = 3000;
  static const int nearbyTimeoutSeconds = 30;

  // Database
  static const String dbUsers = 'users';
  static const String dbConversations = 'conversations';
  static const String dbMessages = 'messages';
  static const String dbPosts = 'posts';
  static const String dbStories = 'stories';
  static const String dbNearbyDevices = 'nearby_devices';
  static const String dbSettings = 'settings';
}

// ── Avatar Colors ────────────────────────────────────────
class AvatarColors {
  static const List<Color> palette = [
    Color(0xFF6C5CE7),
    Color(0xFFFF6B6B),
    Color(0xFF00D2D3),
    Color(0xFFFF9F43),
    Color(0xFF54A0FF),
    Color(0xFF5F27CD),
    Color(0xFFEE5A24),
    Color(0xFF01A3A4),
    Color(0xFFF368E0),
    Color(0xFF10AC84),
    Color(0xFFFF6348),
    Color(0xFF2E86DE),
  ];

  static Color fromIndex(int index) => palette[index % palette.length];
  static Color fromName(String name) => fromIndex(name.hashCode);
}
