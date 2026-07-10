/// BlueSnap — Bluetooth-first local social app
/// Main entry point with permission handling
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'core/theme.dart';
import 'data/database/database_service.dart';
import 'services/bluetooth_service.dart';
import 'services/crypto_service.dart';
import 'services/message_queue_service.dart';
import 'services/notification_service.dart';
import 'services/foreground_service.dart';
import 'services/auth_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/lock_screen.dart';
import 'screens/auth/set_pin_screen.dart';
import 'app_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Status bar style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: BlueSnapTheme.bgSecondary,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  // Request permissions. The Bluetooth/Nearby permissions aren't implemented
  // on web (and camera/mic trigger blocking browser prompts), so skip there —
  // otherwise the request throws and runApp() is never reached.
  if (!kIsWeb) {
    await _requestPermissions();
  }

  // Initialize database
  final db = DatabaseService();
  await db.init();

  // Initialize encryption identity (must be ready before any messaging)
  await CryptoService().init();

  // Drop store-and-forward messages that have outlived their 7-day TTL
  await MessageQueueService().purgeExpired();

  // NOTE: The feed is now real — posts propagate device-to-device. We no longer
  // seed fabricated demo content; an empty feed honestly reflects "no posts from
  // people you've connected with yet."

  // Initialize Bluetooth service. The Nearby Connections plugin is Android-only,
  // so skip transport init on web — the UI still runs for testing.
  if (!kIsWeb) {
    await NotificationService().init();
    final bt = BluetoothService();
    await bt.init();
  }

  // Existing profiles created before the app-lock feature won't have a PIN yet.
  // Such users must be sent to create one, not to a lock screen they can never
  // satisfy.
  final hasUser = db.hasCurrentUser;
  final needsPinSetup = hasUser && !(await AuthService().hasPin());

  runApp(
    ProviderScope(
      child: BlueSnapApp(hasUser: hasUser, needsPinSetup: needsPinSetup),
    ),
  );
}

/// Request the permissions needed for discovery, messaging and media.
///
/// Order matters on Android: request foreground location *before* (and never
/// alongside) background location — asking for `locationAlways` first triggers
/// the scary "Allow all the time" dialog and is usually auto-denied. The
/// Android 12+ Bluetooth/Nearby permissions replace the location requirement
/// on newer devices, so we request the right set and degrade gracefully.
Future<void> _requestPermissions() async {
  // 1. Bluetooth + Nearby (Android 12+ runtime permissions).
  final results = await [
    Permission.bluetoothScan,
    Permission.bluetoothAdvertise,
    Permission.bluetoothConnect,
    Permission.nearbyWifiDevices,
  ].request();

  // 2. Foreground location — still required for BLE scanning on Android <= 11.
  final whenInUse = await Permission.locationWhenInUse.request();

  // 3. Media, requested only when the user first needs them ideally, but
  //    granting up front keeps the camera/voice flows simple for now.
  await Permission.microphone.request();
  await Permission.camera.request();

  final btScanOk = results[Permission.bluetoothScan]?.isGranted ?? false;
  final nearbyOk = results[Permission.nearbyWifiDevices]?.isGranted ?? false;
  if (!btScanOk && !nearbyOk && !whenInUse.isGranted) {
    debugPrint(
        '[Permissions] WARNING: no scan-capable permission granted — discovery will not work.');
  }
}

class BlueSnapApp extends StatefulWidget {
  final bool hasUser;

  /// True when a profile exists but no app-lock PIN has been set yet — i.e. a
  /// user upgrading from a build that predates the lock. They set a PIN once,
  /// then proceed straight into the app.
  final bool needsPinSetup;

  const BlueSnapApp({
    super.key,
    required this.hasUser,
    this.needsPinSetup = false,
  });

  @override
  State<BlueSnapApp> createState() => _BlueSnapAppState();
}

class _BlueSnapAppState extends State<BlueSnapApp> {
  // States: needs onboarding (no profile), needs PIN setup (profile but no PIN),
  // locked (has PIN, not yet unlocked this session), and unlocked (in the app).
  late bool _hasUser;
  late bool _needsPinSetup;
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    _hasUser = widget.hasUser;
    _needsPinSetup = widget.needsPinSetup;
  }

  void _completeAuth() {
    // Onboarding finished (profile + PIN created) → enter the app unlocked.
    setState(() {
      _hasUser = true;
      _unlocked = true;
    });
    _onUnlocked();
  }

  void _onUnlocked() {
    // Stay reachable in the background once the user is in.
    if (!kIsWeb) ForegroundService().start();
  }

  @override
  Widget build(BuildContext context) {
    final Widget home;
    if (!_hasUser) {
      home = LoginScreen(onComplete: _completeAuth);
    } else if (_needsPinSetup && !_unlocked) {
      // Upgrading user with no PIN yet — let them create one, then enter.
      home = SetPinScreen(onComplete: () {
        setState(() {
          _needsPinSetup = false;
          _unlocked = true;
        });
        _onUnlocked();
      });
    } else if (!_unlocked) {
      home = LockScreen(onUnlocked: () {
        setState(() => _unlocked = true);
        _onUnlocked();
      });
    } else {
      home = const AppShell();
    }
    return MaterialApp(
      title: 'BlueSnap',
      debugShowCheckedModeBanner: false,
      theme: BlueSnapTheme.theme,
      home: home,
    );
  }
}
