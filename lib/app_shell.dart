/// BlueSnap App Shell — 4-tab navigation (Home, Search, Messages, Profile)
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../core/app_icons.dart';
import '../data/models/models.dart' as models;
import '../data/models/models.dart' show NearbyDevice, Conversation;
import '../providers/providers.dart';
import '../services/bluetooth_service.dart';
import '../services/nearby_service.dart';
import '../screens/home/home_feed_screen.dart';
import '../screens/search/search_screen.dart';
import '../screens/chat/chat_list_screen.dart';
import '../screens/chat/chat_window_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/call/call_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _currentIndex = 0;
  StreamSubscription? _callSignalSub;
  StreamSubscription? _incomingMessageSub;
  StreamSubscription? _pendingConnSub;
  StreamSubscription? _keyMismatchSub;
  StreamSubscription? _mediaSub;
  StreamSubscription? _feedSub;

  @override
  void initState() {
    super.initState();
    final bt = BluetoothService();
    final nearby = NearbyService();

    // Begin discovering people around you as soon as the app opens, so the
    // Home "people near you" row and Explore populate everywhere (offline/P2P).
    WidgetsBinding.instance.addPostFrameCallback((_) => bt.startScan());

    // Incoming connection requests: ask the user before trusting a peer, and
    // show the Nearby auth token so both sides can verify out-of-band.
    _pendingConnSub = nearby.onConnectionPending.listen((req) {
      if (!mounted) return;
      _showConnectionRequest(nearby, req.endpointId, req.name, req.authToken);
    });

    // A peer reconnected with a different key than we pinned — warn loudly.
    _keyMismatchSub = nearby.onKeyMismatch.listen((e) {
      if (!mounted) return;
      _showKeyMismatchWarning(e.name);
    });

    // Listen for incoming call signals
    _callSignalSub = bt.onCallSignalReceived.listen((signal) {
      final type = signal['type'] as String?;
      if (type == 'call_request' && mounted) {
        final peerName = signal['peerName'] as String? ?? 'Unknown';
        final peerId = signal['peerId'] as String? ?? '';
        final callType = (signal['callType'] as String?) == 'video'
            ? CallType.video
            : CallType.audio;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CallScreen(
              peerName: peerName,
              peerColorIndex: peerName.hashCode.abs() % 12,
              callType: callType,
              isIncoming: true,
              peerId: peerId,
            ),
          ),
        );
      }
    });

    // Listen for incoming messages to refresh conversation list
    _incomingMessageSub = bt.onMessageReceived.listen((_) {
      ref.read(conversationsProvider.notifier).refresh();
    });

    // Received media is persisted as a message — keep the chat list fresh.
    _mediaSub = bt.onMediaReceived.listen((_) {
      ref.read(conversationsProvider.notifier).refresh();
    });

    // A post/story propagated from a nearby peer — refresh the feed + stories.
    _feedSub = bt.onFeedUpdated.listen((_) {
      ref.read(postsProvider.notifier).refresh();
      ref.read(storiesProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _callSignalSub?.cancel();
    _incomingMessageSub?.cancel();
    _pendingConnSub?.cancel();
    _keyMismatchSub?.cancel();
    _mediaSub?.cancel();
    _feedSub?.cancel();
    super.dispose();
  }

  // ── Trust prompts ────────────────────────────────────
  Future<void> _showConnectionRequest(
      NearbyService nearby, String endpointId, String name, String authToken) async {
    final accept = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: BlueSnapTheme.bgCard,
        title: const Text('Connection request', style: BlueSnapTheme.headingS),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$name wants to connect.', style: BlueSnapTheme.bodyM),
            const SizedBox(height: 12),
            Text('Verification code', style: BlueSnapTheme.caption),
            const SizedBox(height: 4),
            Text(
              authToken,
              style: const TextStyle(
                fontFamily: BlueSnapTheme.fontFamily,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: BlueSnapTheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text('Only accept if this exact code shows on their screen too.',
                style: BlueSnapTheme.caption),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Reject', style: TextStyle(color: BlueSnapTheme.accentRed)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Accept', style: TextStyle(color: BlueSnapTheme.primary)),
          ),
        ],
      ),
    );
    if (accept == true) {
      nearby.acceptIncomingConnection(endpointId);
    } else {
      await nearby.rejectIncomingConnection(endpointId);
    }
  }

  Future<void> _showKeyMismatchWarning(String name) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: BlueSnapTheme.bgCard,
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: BlueSnapTheme.accentRed),
            SizedBox(width: 8),
            Text('Security warning', style: BlueSnapTheme.headingS),
          ],
        ),
        content: Text(
          "$name is presenting a different security key than before. This can happen if they reinstalled the app — but it can also mean someone is impersonating them. Their messages have been blocked until you re-verify in person.",
          style: BlueSnapTheme.bodyS,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it', style: TextStyle(color: BlueSnapTheme.primary)),
          ),
        ],
      ),
    );
  }

  void _openChat(Conversation conv) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatWindowScreen(
          conversationId: conv.id,
          peerId: conv.peerId,
          peerName: conv.peerName,
          peerColorIndex: conv.peerAvatarColorIndex,
        ),
      ),
    );
  }

  void _openChatFromDevice(NearbyDevice device) async {
    // Auto-connect to device if not already connected
    final bt = ref.read(bluetoothProvider);
    if (device.connectionState != models.ConnectionState.connected) {
      bt.connectToDevice(device.deviceId);
    }

    // Find or create conversation
    final conv = await ref.read(conversationsProvider.notifier).getOrCreate(
          device.deviceId,
          device.userName,
          device.avatarColorIndex,
        );
    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatWindowScreen(
          conversationId: conv.id,
          peerId: conv.peerId,
          peerName: conv.peerName,
          peerColorIndex: conv.peerAvatarColorIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlueSnapTheme.bgPrimary,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeFeedScreen(onOpenMessages: () => setState(() => _currentIndex = 2)),
          SearchScreen(onDeviceTap: _openChatFromDevice),
          ChatListScreen(onConversationTap: _openChat),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: BlueSnapTheme.bgSecondary,
          border: Border(
            top: BorderSide(color: BlueSnapTheme.divider, width: 0.5),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 52,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(0, AppIcons.home, AppIcons.homeBold),
                _navItem(1, AppIcons.search, AppIcons.searchBold),
                _navItem(2, AppIcons.messages, AppIcons.messagesBold),
                _navItem(3, AppIcons.profile, AppIcons.profileBold),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData idle, IconData active) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _currentIndex = index);
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        // A subtle spring-scale + crossfade as the tab activates.
        child: AnimatedScale(
          scale: isActive ? 1.12 : 1.0,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutBack,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: Icon(
              isActive ? active : idle,
              key: ValueKey(isActive),
              size: 25,
              color: isActive
                  ? BlueSnapTheme.textPrimary
                  : BlueSnapTheme.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}
