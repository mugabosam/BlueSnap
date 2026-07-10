/// BlueSnap local notifications.
///
/// Posts a system notification when a message or media file arrives while the
/// app isn't in the foreground, so users don't have to keep the chat open to
/// know something came in. Muted conversations are respected.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../data/database/database_service.dart';

class NotificationService with WidgetsBindingObserver {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final DatabaseService _db = DatabaseService();

  bool _initialized = false;
  bool _foreground = true; // don't buzz for the chat that's already on-screen

  static const _channelId = 'bluesnap_messages';
  static const _channelName = 'Messages';

  Future<void> init() async {
    if (_initialized) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: androidInit),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    WidgetsBinding.instance.addObserver(this);
    _initialized = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
  }

  /// Show a message/media notification unless the app is foregrounded or the
  /// conversation is muted.
  Future<void> showMessage({
    required String conversationId,
    required String title,
    required String body,
  }) async {
    if (!_initialized) return;
    if (_foreground) return;
    if (_db.isMuted(conversationId)) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'New messages from people nearby',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _plugin.show(
      conversationId.hashCode & 0x7fffffff,
      title,
      body,
      details,
    );
  }
}
