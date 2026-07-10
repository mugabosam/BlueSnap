/// BlueSnap Chat Window — messaging screen
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme.dart';
import '../../core/app_icons.dart';
import '../../data/models/models.dart' show Message, MessageType, MessageStatus;
import '../../providers/providers.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:open_filex/open_filex.dart';
import '../../services/bluetooth_service.dart';
import '../../services/crypto_service.dart';
import '../../services/media_service.dart';
import '../../data/database/database_service.dart';
import '../../widgets/shared_widgets.dart';
import '../../widgets/voice_message_widget.dart';
import '../../widgets/file_transfer_widget.dart' show SnapViewer;
import '../call/call_screen.dart';
import 'package:image_picker/image_picker.dart';

class ChatWindowScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String peerId;
  final String peerName;
  final int peerColorIndex;

  const ChatWindowScreen({
    super.key,
    required this.conversationId,
    required this.peerId,
    required this.peerName,
    required this.peerColorIndex,
  });

  @override
  ConsumerState<ChatWindowScreen> createState() => _ChatWindowScreenState();
}

class _ChatWindowScreenState extends ConsumerState<ChatWindowScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _uuid = const Uuid();
  final _picker = ImagePicker();
  final _bt = BluetoothService();
  bool _peerTyping = false; // real: driven by peer's typing signal
  bool _isRecordingVoice = false;
  bool _showAttachMenu = false;
  bool _peerOnline = false; // real: driven by connection state
  bool _typingSent = false;
  Timer? _typingDebounce;

  late final StreamSubscription _messageSubscription;
  late final StreamSubscription _typingSubscription;
  late final StreamSubscription _connectionSubscription;
  late final StreamSubscription _mediaSubscription;

  @override
  void initState() {
    super.initState();

    // Mark conversation as read when opening
    final db = ref.read(databaseProvider);
    final user = ref.read(currentUserProvider);
    if (user != null) {
      db.markConversationRead(widget.conversationId, user.id);
      final conv = db.getConversation(widget.conversationId);
      if (conv != null && conv.unreadCount > 0) {
        conv.unreadCount = 0;
        conv.save();
        ref.read(conversationsProvider.notifier).refresh();
      }
    }

    _peerOnline = _bt.isPeerOnline(widget.peerId);

    // Listen for incoming messages
    _messageSubscription = _bt.onMessageReceived.listen((msg) {
      if (msg.conversationId == widget.conversationId) {
        ref.read(messagesProvider(widget.conversationId).notifier).refresh();
        ref.read(conversationsProvider.notifier).refresh();
        _scrollToBottom();
      }
    });

    // Real typing indicator — only shows when the peer is actually typing.
    _typingSubscription = _bt.onTypingChanged.listen((e) {
      if (e.endpointId == widget.peerId && mounted) {
        setState(() => _peerTyping = e.isTyping);
        if (e.isTyping) _scrollToBottom();
      }
    });

    // Real presence — reflects the live connection to this peer.
    _connectionSubscription = _bt.onConnectionChanged.listen((e) {
      if (e.endpointId == widget.peerId && mounted) {
        setState(() => _peerOnline = e.connected);
      }
    });

    // A received image/voice file was saved — show it in this conversation.
    _mediaSubscription = _bt.onMediaReceived.listen((e) {
      if (e.conversationId == widget.conversationId && mounted) {
        ref.read(messagesProvider(widget.conversationId).notifier).refresh();
        ref.read(conversationsProvider.notifier).refresh();
        _scrollToBottom();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _messageSubscription.cancel();
    _typingSubscription.cancel();
    _connectionSubscription.cancel();
    _mediaSubscription.cancel();
    _typingDebounce?.cancel();
    if (_typingSent) _bt.sendTyping(widget.peerId, false);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Send real typing signals to the peer, debounced.
  void _onTextChanged(String text) {
    setState(() {}); // toggles mic/send button
    final typing = text.trim().isNotEmpty;
    if (typing && !_typingSent) {
      _typingSent = true;
      _bt.sendTyping(widget.peerId, true);
    }
    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(seconds: 2), () {
      if (_typingSent) {
        _typingSent = false;
        _bt.sendTyping(widget.peerId, false);
      }
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(messagesProvider(widget.conversationId));
    final currentUser = ref.watch(currentUserProvider);
    final myId = currentUser?.id ?? 'me';

    return Scaffold(
      backgroundColor: BlueSnapTheme.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ─────────────────────
            _buildHeader(context),

            // ── Messages ───────────────────
            Expanded(
              child: messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          UserAvatar(
                            name: widget.peerName,
                            colorIndex: widget.peerColorIndex,
                            size: 72,
                          ),
                          const SizedBox(height: 16),
                          Text(widget.peerName, style: BlueSnapTheme.headingS),
                          const SizedBox(height: 8),
                          const Text(
                            'Say hi to start the conversation',
                            style: BlueSnapTheme.bodyS,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      itemCount: messages.length + (_peerTyping ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i == messages.length && _peerTyping) {
                          return _typingIndicator();
                        }
                        return _messageBubble(messages[i], myId);
                      },
                    ),
            ),

            // ── Input Bar ──────────────────
            if (_isRecordingVoice)
              VoiceMessageRecorder(
                onRecordingComplete: (path, dur) => _sendVoiceMessage(myId, path, dur),
                onCancel: () => setState(() => _isRecordingVoice = false),
              )
            else
              _buildInputBar(myId),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: const BoxDecoration(
        color: BlueSnapTheme.bgSecondary,
        border: Border(
          bottom: BorderSide(color: BlueSnapTheme.divider, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(AppIcons.back, size: 22),
          ),
          UserAvatar(
            name: widget.peerName,
            colorIndex: widget.peerColorIndex,
            size: 36,
            showOnlineIndicator: _peerOnline,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.peerName,
                  style: BlueSnapTheme.username,
                ),
                const SizedBox(height: 1),
                Text(
                  _peerOnline ? 'Connected' : 'Not in range',
                  style: BlueSnapTheme.caption.copyWith(
                    color: _peerOnline
                        ? BlueSnapTheme.onlineGreen
                        : BlueSnapTheme.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _peerOnline ? () => _startCall(CallType.audio) : null,
            icon: Icon(AppIcons.call,
                size: 22,
                color: _peerOnline
                    ? BlueSnapTheme.textPrimary
                    : BlueSnapTheme.textTertiary),
          ),
          IconButton(
            onPressed: _peerOnline ? () => _startCall(CallType.video) : null,
            icon: Icon(AppIcons.video,
                size: 22,
                color: _peerOnline
                    ? BlueSnapTheme.textPrimary
                    : BlueSnapTheme.textTertiary),
          ),
          IconButton(
            onPressed: _showChatMenu,
            icon: const Icon(AppIcons.more,
                size: 20, color: BlueSnapTheme.textPrimary),
          ),
        ],
      ),
    );
  }

  // ── Security / safety menu ───────────────────────────
  void _showChatMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: BlueSnapTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        final db = DatabaseService();
        final muted = db.isMuted(widget.conversationId);
        final blocked = db.isBlocked(widget.peerId);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(AppIcons.verified,
                    color: BlueSnapTheme.primary),
                title: const Text('Verify security', style: BlueSnapTheme.username),
                subtitle: const Text('Compare safety codes in person',
                    style: BlueSnapTheme.bodyS),
                onTap: () {
                  Navigator.pop(context);
                  _showFingerprint();
                },
              ),
              ListTile(
                leading: Icon(muted ? AppIcons.muteOff : AppIcons.muteOn,
                    color: BlueSnapTheme.textPrimary),
                title: Text(muted ? 'Unmute' : 'Mute notifications',
                    style: BlueSnapTheme.username),
                onTap: () async {
                  await db.setMuted(widget.conversationId, !muted);
                  if (mounted) Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(AppIcons.block, color: BlueSnapTheme.accentRed),
                title: Text(blocked ? 'Unblock ${widget.peerName}'
                                    : 'Block ${widget.peerName}',
                    style: BlueSnapTheme.username
                        .copyWith(color: BlueSnapTheme.accentRed)),
                onTap: () async {
                  await db.setBlocked(widget.peerId, !blocked);
                  if (!mounted) return;
                  Navigator.pop(context);
                  showAppSnack(context,
                      blocked ? 'Unblocked ${widget.peerName}'
                              : 'Blocked ${widget.peerName}',
                      icon: Icons.block);
                  if (!blocked) Navigator.pop(context); // leave the chat
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _showFingerprint() {
    final db = DatabaseService();
    final myFp = CryptoService.fingerprint(CryptoService().myPublicKeyBase64);
    final peerKey = db.pinnedKeyFor(widget.peerId);
    final peerFp = peerKey != null ? CryptoService.fingerprint(peerKey) : null;
    final verified = db.isVerified(widget.peerId);
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: BlueSnapTheme.bgCard,
        title: const Text('Safety codes', style: BlueSnapTheme.headingS),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('These codes must match on both phones. If they do, no '
                'one is intercepting your chat.',
                style: BlueSnapTheme.bodyS),
            const SizedBox(height: 16),
            const Text('YOUR CODE', style: BlueSnapTheme.caption),
            Text(myFp, style: _fpStyle),
            const SizedBox(height: 12),
            Text('${widget.peerName.toUpperCase()}\'S CODE',
                style: BlueSnapTheme.caption),
            Text(peerFp ?? 'Not connected yet', style: _fpStyle),
          ],
        ),
        actions: [
          if (peerFp != null)
            TextButton(
              onPressed: () async {
                await db.setVerified(widget.peerId, !verified);
                if (mounted) Navigator.pop(context);
              },
              child: Text(verified ? 'Mark unverified' : 'They match',
                  style: const TextStyle(color: BlueSnapTheme.accentGreen)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: BlueSnapTheme.primary)),
          ),
        ],
      ),
    );
  }

  static const TextStyle _fpStyle = TextStyle(
    fontFamily: BlueSnapTheme.fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.5,
    color: BlueSnapTheme.primary,
  );

  Widget _messageBubble(Message message, String myId) {
    final isMine = message.senderId == myId;
    final timeStr = DateFormat.jm().format(message.timestamp);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) const SizedBox(width: 4),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMine ? BlueSnapTheme.primary : BlueSnapTheme.surface2,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMine ? 18 : 4),
                  bottomRight: Radius.circular(isMine ? 4 : 18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Voice message
                  if (message.messageType == MessageType.voice)
                    VoiceMessagePlayer(
                      durationMs: message.durationMs ?? 5000,
                      isMine: isMine,
                      audioPath: message.mediaPath,
                    )
                  // Image message
                  else if (message.messageType == MessageType.file)
                    _fileBubble(message, isMine)
                  else if (message.messageType == MessageType.image)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: message.mediaPath != null
                              ? () => _openMedia(message.mediaPath!)
                              : null,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: message.mediaPath != null
                                ? MediaImage(
                                    path: message.mediaPath!,
                                    width: 220,
                                    height: 170,
                                    fallbackColor: isMine
                                        ? Colors.white
                                        : BlueSnapTheme.primary,
                                  )
                                : Container(
                                    width: 220,
                                    height: 170,
                                    color: isMine
                                        ? Colors.white.withValues(alpha: 0.1)
                                        : BlueSnapTheme.primary.withValues(alpha: 0.08),
                                    child: Center(
                                      child: Icon(Icons.image,
                                          size: 40,
                                          color: isMine
                                              ? Colors.white38
                                              : BlueSnapTheme.primary.withValues(alpha: 0.3)),
                                    ),
                                  ),
                          ),
                        ),
                        if (message.content.isNotEmpty && message.content != '📷 Photo')
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              message.content,
                              style: BlueSnapTheme.bodyM.copyWith(
                                color: isMine ? Colors.white : BlueSnapTheme.textPrimary,
                              ),
                            ),
                          ),
                      ],
                    )
                  // Snap message (tap to view)
                  else if (message.messageType == MessageType.snap)
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => SnapViewer(
                            textContent: message.content,
                            expirySeconds: 10,
                            onExpired: () {
                              // Mark as expired
                            },
                          ),
                        ));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isMine
                              ? Colors.white.withValues(alpha: 0.1)
                              : BlueSnapTheme.accentPurple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.visibility, size: 16,
                              color: isMine ? Colors.white70 : BlueSnapTheme.accentPurple),
                            const SizedBox(width: 6),
                            Text(
                              'Tap to view snap',
                              style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600,
                                color: isMine ? Colors.white70 : BlueSnapTheme.accentPurple,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  // Text message (default)
                  else
                    Text(
                      message.content,
                      style: BlueSnapTheme.bodyM.copyWith(
                        color: isMine ? Colors.white : BlueSnapTheme.textPrimary,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 10,
                          color: isMine
                              ? Colors.white.withValues(alpha: 0.6)
                              : BlueSnapTheme.textTertiary,
                        ),
                      ),
                      if (isMine) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.status == MessageStatus.read
                              ? Icons.done_all
                              : message.status == MessageStatus.delivered
                                  ? Icons.done_all
                                  : Icons.done,
                          size: 14,
                          color: message.status == MessageStatus.read
                              ? const Color(0xFF00E5FF)
                              : Colors.white.withValues(alpha: 0.6),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMine) const SizedBox(width: 4),
        ],
      ),
    );
  }

  /// A tappable file attachment (documents, audio, anything non-image).
  Widget _fileBubble(Message message, bool isMine) {
    final onFg = isMine ? Colors.white : BlueSnapTheme.textPrimary;
    final sub = isMine ? Colors.white70 : BlueSnapTheme.textSecondary;
    final sizeLabel = message.mediaSizeBytes != null
        ? _formatBytes(message.mediaSizeBytes!)
        : 'File';
    return GestureDetector(
      onTap: message.mediaPath != null ? () => _openMedia(message.mediaPath!) : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (isMine ? Colors.white : BlueSnapTheme.primary)
                  .withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(AppIcons.file, size: 20, color: onFg),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BlueSnapTheme.bodyM.copyWith(
                      color: onFg, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text('$sizeLabel · Tap to open',
                    style: BlueSnapTheme.caption.copyWith(color: sub, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openMedia(String path) async {
    final res = await OpenFilex.open(path);
    if (res.type != ResultType.done && mounted) {
      showAppSnack(context, "No app can open this file", isError: true);
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  Widget _typingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: BlueSnapTheme.surface2,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: BlueSnapTheme.textTertiary,
                    shape: BoxShape.circle,
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(String myId) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: const BoxDecoration(
        color: BlueSnapTheme.bgSecondary,
        border: Border(
          top: BorderSide(color: BlueSnapTheme.divider, width: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Attach menu
          if (_showAttachMenu)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                color: BlueSnapTheme.bgCard,
                borderRadius: BorderRadius.circular(BlueSnapTheme.radiusL),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _attachOption(AppIcons.gallery, 'Photo', BlueSnapTheme.accentGreen, () {
                    setState(() => _showAttachMenu = false);
                    _pickImage(myId);
                  }),
                  _attachOption(AppIcons.camera, 'Camera', BlueSnapTheme.primary, () {
                    setState(() => _showAttachMenu = false);
                    _takePhoto(myId);
                  }),
                  _attachOption(AppIcons.file, 'File', BlueSnapTheme.accentOrange, () {
                    setState(() => _showAttachMenu = false);
                    _sendFileMessage(myId);
                  }),
                  _attachOption(AppIcons.location, 'Location', BlueSnapTheme.accentRed, () {
                    setState(() => _showAttachMenu = false);
                    _sendLocationMessage(myId);
                  }),
                ],
              ),
            ),
          Row(
            children: [
              // Attach button
              IconButton(
                onPressed: () => setState(() => _showAttachMenu = !_showAttachMenu),
                icon: Icon(
                  _showAttachMenu ? AppIcons.close : AppIcons.attach,
                  color: BlueSnapTheme.primary,
                  size: 26,
                ),
              ),
              // Text field
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: BlueSnapTheme.surface2,
                    borderRadius: BorderRadius.circular(BlueSnapTheme.radiusFull),
                  ),
                  child: TextField(
                    controller: _textController,
                    style: BlueSnapTheme.bodyM,
                    cursorColor: BlueSnapTheme.primary,
                    decoration: InputDecoration(
                      hintText: 'Message...',
                      hintStyle: BlueSnapTheme.bodyM.copyWith(
                        color: BlueSnapTheme.textTertiary,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                    onSubmitted: (_) => _sendMessage(myId),
                    onChanged: _onTextChanged,
                    textInputAction: TextInputAction.send,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Voice or Send button
              if (_textController.text.trim().isEmpty)
                Pressable(
                  onTap: () => setState(() => _isRecordingVoice = true),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      AppIcons.mic,
                      color: BlueSnapTheme.textPrimary,
                      size: 24,
                    ),
                  ),
                )
              else
                Pressable(
                  onTap: () => _sendMessage(myId),
                  child: Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: BlueSnapTheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      AppIcons.send,
                      color: Colors.white,
                      size: 17,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _attachOption(IconData icon, String label, Color color, VoidCallback onTap) {
    return Pressable(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 4),
          Text(label, style: BlueSnapTheme.caption.copyWith(fontSize: 10)),
        ],
      ),
    );
  }

  Future<void> _sendMessage(String myId) async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    // We just sent, so we're no longer typing — tell the peer.
    if (_typingSent) {
      _typingSent = false;
      _bt.sendTyping(widget.peerId, false);
    }
    setState(() {}); // switch send→mic button

    final message = Message(
      id: _uuid.v4(),
      conversationId: widget.conversationId,
      senderId: myId,
      receiverId: widget.peerId,
      content: text,
      messageTypeIndex: MessageType.text.index,
      statusIndex: MessageStatus.sending.index,
    );

    await ref.read(messagesProvider(widget.conversationId).notifier).addMessage(message);
    ref.read(conversationsProvider.notifier).updateLastMessage(widget.conversationId, text);
    _scrollToBottom();

    // Real send. Delivery/read state updates arrive via acks from the peer;
    // nothing here fabricates a reply.
    await _bt.sendMessage(message);
    ref.read(messagesProvider(widget.conversationId).notifier).refresh();
  }

  void _startCall(CallType type) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          peerName: widget.peerName,
          peerColorIndex: widget.peerColorIndex,
          callType: type,
          peerId: widget.peerId,
        ),
      ),
    );
  }

  Future<void> _pickImage(String myId) async {
    final photo = await _picker.pickImage(
      source: ImageSource.gallery, imageQuality: 75, maxWidth: 1080);
    if (photo == null) return;
    await _sendImage(myId, photo.path);
  }

  Future<void> _takePhoto(String myId) async {
    final photo = await _picker.pickImage(
      source: ImageSource.camera, imageQuality: 85, maxWidth: 1080);
    if (photo == null) return;
    await _sendImage(myId, photo.path);
  }

  /// Compress an image and transmit it for real over the current transport.
  Future<void> _sendImage(String myId, String sourcePath) async {
    // Compress for radio transfer; fall back to the original on failure.
    final compressed = await MediaService().compressImage(sourcePath);
    final path = compressed?.path ?? sourcePath;

    final message = Message(
      id: _uuid.v4(),
      conversationId: widget.conversationId,
      senderId: myId,
      receiverId: widget.peerId,
      content: '📷 Photo',
      messageTypeIndex: MessageType.image.index,
      statusIndex: MessageStatus.sending.index,
      mediaPath: path,
      mediaSizeBytes: await _fileSize(path),
    );

    await ref.read(messagesProvider(widget.conversationId).notifier).addMessage(message);
    ref.read(conversationsProvider.notifier).updateLastMessage(widget.conversationId, '📷 Photo');
    _scrollToBottom();
    await _transmit(message, path);
  }

  Future<int> _fileSize(String path) async {
    try {
      return await File(path).length();
    } catch (_) {
      return 0;
    }
  }

  /// Send a media file and reflect the *real* transfer outcome in the bubble.
  Future<void> _transmit(Message message, String path) async {
    final ok = await _bt.sendFile(
      filePath: path,
      receiverId: widget.peerId,
      conversationId: widget.conversationId,
      fileSizeBytes: message.mediaSizeBytes ?? 0,
      onProgress: (_) {},
      // Carried alongside the file so the receiver rebuilds the right bubble.
      meta: {
        'id': message.id,
        'msgType': message.messageTypeIndex,
        'durationMs': message.durationMs,
        'caption': message.content,
      },
    );
    message.status = ok ? MessageStatus.sent : MessageStatus.failed;
    await message.save();
    if (mounted) {
      ref.read(messagesProvider(widget.conversationId).notifier).refresh();
    }
  }

  Future<void> _sendFileMessage(String myId) async {
    // Pick a real file and transmit it over the transport.
    final result = await FilePicker.platform.pickFiles(withReadStream: false);
    final picked = result?.files.single;
    if (picked?.path == null) return;
    final path = picked!.path!;

    // Route images through the image path so they render as photos; everything
    // else is a real file the recipient can open with its own app.
    final isImage = _looksLikeImage(picked.name);
    final message = Message(
      id: _uuid.v4(),
      conversationId: widget.conversationId,
      senderId: myId,
      receiverId: widget.peerId,
      content: isImage ? '📷 Photo' : picked.name,
      messageTypeIndex:
          (isImage ? MessageType.image : MessageType.file).index,
      statusIndex: MessageStatus.sending.index,
      mediaPath: path,
      mediaSizeBytes: picked.size,
    );

    await ref.read(messagesProvider(widget.conversationId).notifier).addMessage(message);
    ref.read(conversationsProvider.notifier)
        .updateLastMessage(widget.conversationId, isImage ? '📷 Photo' : '📎 ${picked.name}');
    _scrollToBottom();
    await _transmit(message, path);
  }

  bool _looksLikeImage(String name) {
    final n = name.toLowerCase();
    return n.endsWith('.jpg') || n.endsWith('.jpeg') || n.endsWith('.png') ||
        n.endsWith('.gif') || n.endsWith('.webp') || n.endsWith('.heic');
  }

  Future<void> _sendLocationMessage(String myId) async {
    // Capture the real device location and share it as a map link.
    String content;
    try {
      final perm = await Geolocator.checkPermission();
      final granted = perm == LocationPermission.always ||
          perm == LocationPermission.whileInUse ||
          (await Geolocator.requestPermission()) == LocationPermission.whileInUse;
      if (!granted) {
        if (mounted) {
          showAppSnack(context, 'Location permission is needed to share your location',
              icon: Icons.location_off_outlined, isError: true);
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      final lat = pos.latitude.toStringAsFixed(5);
      final lng = pos.longitude.toStringAsFixed(5);
      content = '📍 My location: https://maps.google.com/?q=$lat,$lng';
    } catch (e) {
      if (mounted) {
        showAppSnack(context, "Couldn't get your location right now",
            icon: Icons.location_off_outlined, isError: true);
      }
      return;
    }

    final message = Message(
      id: _uuid.v4(),
      conversationId: widget.conversationId,
      senderId: myId,
      receiverId: widget.peerId,
      content: content,
      messageTypeIndex: MessageType.text.index,
      statusIndex: MessageStatus.sending.index,
    );

    await ref.read(messagesProvider(widget.conversationId).notifier).addMessage(message);
    ref.read(conversationsProvider.notifier).updateLastMessage(widget.conversationId, '📍 Location');
    _scrollToBottom();
    await _bt.sendMessage(message);
    ref.read(messagesProvider(widget.conversationId).notifier).refresh();
  }

  Future<void> _sendVoiceMessage(String myId, String path, int durationMs) async {
    final message = Message(
      id: _uuid.v4(),
      conversationId: widget.conversationId,
      senderId: myId,
      receiverId: widget.peerId,
      content: '🎤 Voice message',
      messageTypeIndex: MessageType.voice.index,
      statusIndex: MessageStatus.sending.index,
      mediaPath: path,
      durationMs: durationMs,
      mediaSizeBytes: await _fileSize(path),
    );

    await ref.read(messagesProvider(widget.conversationId).notifier).addMessage(message);
    ref.read(conversationsProvider.notifier).updateLastMessage(widget.conversationId, '🎤 Voice message');
    setState(() => _isRecordingVoice = false);
    _scrollToBottom();

    // Transmit the actual recorded audio file over the transport.
    await _transmit(message, path);
  }
}
