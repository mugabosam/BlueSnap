/// BlueSnap foreground service.
///
/// Keeps the process alive with a persistent notification so Nearby
/// advertising/discovery — and therefore message delivery — continues while the
/// app is backgrounded. Without this, Android suspends the app and peers can't
/// reach you unless the chat is open on-screen.
///
/// NOTE: the actual radio work runs in the main isolate (NearbyService); this
/// service exists to stop Android from killing that isolate in the background.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Entry point the plugin spawns for the background task isolate.
@pragma('vm:entry-point')
void bluesnapForegroundCallback() {
  FlutterForegroundTask.setTaskHandler(_BlueSnapTaskHandler());
}

class _BlueSnapTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp) async {}
}

class ForegroundService {
  static final ForegroundService _instance = ForegroundService._();
  factory ForegroundService() => _instance;
  ForegroundService._();

  bool _configured = false;

  void _configure() {
    if (_configured) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'bluesnap_service',
        channelName: 'BlueSnap nearby',
        channelDescription: 'Keeps you discoverable and receiving messages.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
    _configured = true;
  }

  /// Start staying reachable in the background. Safe to call more than once.
  Future<void> start() async {
    if (kIsWeb) return;
    try {
      _configure();
      if (await FlutterForegroundTask.isRunningService) return;
      await FlutterForegroundTask.startService(
        notificationTitle: 'BlueSnap is active',
        notificationText: 'Discovering people nearby and receiving messages.',
        callback: bluesnapForegroundCallback,
      );
    } catch (e) {
      debugPrint('[Foreground] start failed: $e');
    }
  }

  Future<void> stop() async {
    if (kIsWeb) return;
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (e) {
      debugPrint('[Foreground] stop failed: $e');
    }
  }
}
