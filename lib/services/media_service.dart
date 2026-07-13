/// BlueSnap Media Service — compression pipeline for BT transfer
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:uuid/uuid.dart';
import '../core/constants.dart';

class MediaService {
  static final MediaService _instance = MediaService._();
  factory MediaService() => _instance;
  MediaService._();

  final _uuid = const Uuid();

  /// Compress an image and store it PERMANENTLY (app documents dir) — used for
  /// profile photos, which must survive app restarts and temp-cache clearing.
  /// Returns the stable absolute path, or the source path if compression fails.
  Future<String> persistAvatar(String sourcePath) async {
    final docs = await getApplicationDocumentsDirectory();
    final target = '${docs.path}/avatar_${_uuid.v4().substring(0, 8)}.jpg';
    try {
      final result = await FlutterImageCompress.compressAndGetFile(
        sourcePath, target,
        minWidth: 512, minHeight: 512, quality: 85, format: CompressFormat.jpeg,
      );
      if (result != null) return result.path;
    } catch (_) {/* fall through to a plain copy */}
    try {
      await File(sourcePath).copy(target);
      return target;
    } catch (_) {
      return sourcePath;
    }
  }

  /// Compress an image for Bluetooth transfer.
  /// Reduces a typical 8MB photo → 200-300KB
  Future<File?> compressImage(String sourcePath) async {
    try {
      final dir = await getTemporaryDirectory();
      final target = '${dir.path}/bs_${_uuid.v4().substring(0, 8)}.jpg';
      final result = await FlutterImageCompress.compressAndGetFile(
        sourcePath, target,
        minWidth: AppConstants.maxImageWidth,
        minHeight: AppConstants.maxImageWidth,
        quality: AppConstants.imageQuality,
        format: CompressFormat.jpeg,
      );
      return result != null ? File(result.path) : null;
    } catch (e) {
      return null;
    }
  }

  /// Generate a ~5KB thumbnail for instant preview
  Future<File?> generateThumbnail(String sourcePath) async {
    try {
      final dir = await getTemporaryDirectory();
      final target = '${dir.path}/th_${_uuid.v4().substring(0, 8)}.jpg';
      final result = await FlutterImageCompress.compressAndGetFile(
        sourcePath, target,
        minWidth: AppConstants.thumbnailSize,
        minHeight: AppConstants.thumbnailSize,
        quality: 50,
        format: CompressFormat.jpeg,
      );
      return result != null ? File(result.path) : null;
    } catch (e) {
      return null;
    }
  }

  /// Estimate BT Classic transfer time
  Duration estimateTransferTime(int bytes) {
    const bps = 250000; // ~2 Mbps real-world
    return Duration(milliseconds: ((bytes / bps) * 1000).round());
  }

  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }
}
