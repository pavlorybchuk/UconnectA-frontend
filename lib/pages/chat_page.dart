import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:uconnecta/app_services.dart';
import 'package:uconnecta/auth/user_scope.dart';
import 'package:uconnecta/data/constrains_&_utils.dart';
import 'package:uconnecta/data/navigation_service.dart';
import 'package:uconnecta/data/pending_message_buffer.dart';
import 'package:uconnecta/pages/driver_profile_page.dart';
import 'package:uconnecta/pages/home_page.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import 'package:uconnecta/data/api.dart';
import 'package:image_picker/image_picker.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

String _newLocalId() =>
    '${DateTime.now().microsecondsSinceEpoch}_${DateTime.now().hashCode.abs()}';

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton shimmer widget
// ─────────────────────────────────────────────────────────────────────────────

class _SkeletonBubble extends StatefulWidget {
  final bool isRight;
  final double width;
  const _SkeletonBubble({required this.isRight, required this.width});

  @override
  State<_SkeletonBubble> createState() => _SkeletonBubbleState();
}

class _SkeletonBubbleState extends State<_SkeletonBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _shimmer = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Align(
        alignment:
            widget.isRight ? Alignment.centerRight : Alignment.centerLeft,
        child: AnimatedBuilder(
          animation: _shimmer,
          builder: (_, __) {
            return Container(
              width: widget.width,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: widget.isRight
                      ? const Radius.circular(16)
                      : Radius.zero,
                  topRight: widget.isRight
                      ? Radius.zero
                      : const Radius.circular(16),
                  bottomLeft: const Radius.circular(16),
                  bottomRight: const Radius.circular(16),
                ),
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  stops: [
                    (_shimmer.value - 0.5).clamp(0.0, 1.0),
                    _shimmer.value.clamp(0.0, 1.0),
                    (_shimmer.value + 0.5).clamp(0.0, 1.0),
                  ],
                  colors: const [
                    Color(0xFFE0E0E0),
                    Color(0xFFF5F5F5),
                    Color(0xFFE0E0E0),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

Widget _skeletonList() {
  return ListView(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    children: const [
      _SkeletonBubble(isRight: false, width: 180),
      _SkeletonBubble(isRight: true, width: 220),
      _SkeletonBubble(isRight: false, width: 140),
      _SkeletonBubble(isRight: true, width: 200),
      _SkeletonBubble(isRight: false, width: 160),
      _SkeletonBubble(isRight: true, width: 120),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// ChatPage
// ─────────────────────────────────────────────────────────────────────────────

class ChatPage extends StatefulWidget {
  final ChatListItem? chat;
  final DriverProfile? otherUser;
  final String? chatId;

  const ChatPage({super.key, this.chat, this.otherUser, this.chatId})
      : assert(
          chat != null || chatId != null || otherUser != null,
          'Either chat, chatId or otherUser must be provided',
        );

  const ChatPage.byId({super.key, required String chatId})
      : chatId = chatId,
        chat = null,
        otherUser = null;

  const ChatPage.otherUser({super.key, required DriverProfile otherUser})
      : otherUser = otherUser,
        chat = null,
        chatId = null;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  final _buffer = PendingMessageBuffer();

  ChatListItem? _chat;
  final List<MessageItem> _messages = [];
  final _picker = ImagePicker();
  File? _pendingImage;

  String? _chatId;
  bool _loading = false;
  bool _creatingChat = false;

  bool get _isDraft => _chatId == null;

  DriverProfile get _peer {
    if (widget.otherUser != null) return widget.otherUser!;
    return _chat!.otherUser;
  }

  String get _peerTitle => _peer.displayName ?? 'Anonymous';
  bool _startingCall = false;

  WebSocketChannel? _ws;
  StreamSubscription? _wsSub;

  // ── WebSocket ─────────────────────────────────────────────────────────────

  String _wsBase() {
    final uri = Uri.parse(Api.baseUrl);
    final scheme = (uri.scheme == 'https') ? 'wss' : 'ws';
    return Uri(
      scheme: scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
    ).toString();
  }

  Future<void> _connectWsIfPossible() async {
    final chatId = _chatId;
    if (chatId == null || _ws != null) return;

    final access = await AppServices.tokenStorage.readAccess();
    if (access == null || access.isEmpty) return;

    final url = '${_wsBase()}/ws/chats/$chatId/?token=$access';
    _ws = WebSocketChannel.connect(Uri.parse(url));

    _wsSub = _ws!.stream.listen(
      (event) {
        try {
          final raw = (event is String) ? event : event.toString();
          final data = jsonDecode(raw);
          if (data is Map<String, dynamic>) {
            if (data.containsKey('type')) {
              if (!mounted) return;
              _onWsEvent(data);
              return;
            }
            // Legacy fallback
            final msg = MessageItem.fromJson(data);
            if (_messages.any((m) => m.id == msg.id)) return;
            if (!mounted) return;
            setState(() => _messages.add(msg));
            _scrollToBottom(delayMs: 20);
          }
        } catch (_) {}
      },
      onError: (_) {},
      onDone: () {
        _ws = null;
        _wsSub = null;
      },
    );
  }

  void _closeWs() {
    _wsSub?.cancel();
    _wsSub = null;
    _ws?.sink.close(ws_status.goingAway);
    _ws = null;
  }

  // ── Init / dispose ────────────────────────────────────────────────────────

  Future<void> _initChat() async {
    if (widget.chat != null) {
      _chat = widget.chat;
      _chatId = widget.chat!.id;
      await _loadMessages();
      await _connectWsIfPossible();
      return;
    }

    if (widget.chatId != null) {
      if (mounted) setState(() => _loading = true);
      try {
        final store = AppServices.chatStore;
        final cached = store.getById(widget.chatId!);
        if (cached != null) {
          _chat = cached;
        } else {
          final chats = await AppServices.chatApi.fetchChats();
          store.setChats(chats);
          _chat = store.getById(widget.chatId!);
        }

        if (_chat == null) {
          if (!mounted) return;
          showErrorSnackBar('Chat not found', mounted, context);
          Navigator.pop(context);
          return;
        }

        _chatId = _chat!.id;
        // _loadMessages manages _loading itself from here on.
        if (mounted) setState(() => _loading = false);
        await _loadMessages();
        await _connectWsIfPossible();
      } catch (e) {
        if (!mounted) return;
        setState(() => _loading = false);
        showErrorSnackBar('Chat not found', mounted, context);
        Navigator.pop(context);
      }
    }
  }

  /// Load server messages and overlay any buffered pending messages that
  /// have not yet been confirmed — so they survive navigation away and back.
  Future<void> _loadMessages() async {
    final id = _chatId;
    if (id == null) return;
    if (!mounted) return;

    setState(() => _loading = true);
    try {
      final me = UserScope.of(context).value;

      // 1. Fetch persisted pending entries for today.
      final buffered = await _buffer.loadForChat(id);

      // 2. Fetch confirmed messages from server.
      final serverItems = await AppServices.chatApi.fetchMessages(id);

      if (!mounted) return;

      // 3. Decide which buffered entries are still in-flight.
      final pendingToShow = <MessageItem>[];
      for (final b in buffered) {
        if (me == null) continue;
        // Consider a buffered entry confirmed if the server already has a
        // matching message (same sender, same body, within 30 s).
        final confirmed = serverItems.any(
          (m) =>
              m.sender == me.id &&
              m.body == b.body &&
              m.createdAt
                  .difference(b.createdAt)
                  .abs()
                  .inSeconds <
                  30,
        );
        if (confirmed) {
          // Clean up stale buffer entry.
          await _buffer.remove(id, b.localId);
        } else {
          pendingToShow.add(MessageItem.optimistic(
            localId: b.localId,
            chatId: b.chatId,
            sender: b.senderId,
            senderUsername: b.senderUsername,
            body: b.body,
            localImagePath: b.localImagePath,
            createdAt: b.createdAt,
          ));
        }
      }

      // 4. Merge and sort.
      final merged = [...serverItems, ...pendingToShow];
      merged.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      setState(() {
        _messages
          ..clear()
          ..addAll(merged);
      });
      _scrollToBottom(delayMs: 50);
    } catch (e) {
      showErrorSnackBar('Failed to load messages: $e', mounted, context);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _didInit = false;

  @override
  void initState() {
    super.initState();
    ChatNavigationTracker.currentChatId = widget.chat?.id ?? widget.chatId;
    _chatId = widget.chat?.id;
    _text.addListener(refreshPage);
    // DO NOT call _initChat() here — it reads UserScope.of(context) which
    // requires InheritedWidget lookup, and that is illegal inside initState.
    // Schedule it for the first frame instead, where context is fully live.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initChat();
    });
  }

  void refreshPage() => setState(() {});

  @override
  void dispose() {
    _closeWs();
    if (ChatNavigationTracker.currentChatId == _chatId) {
      ChatNavigationTracker.currentChatId = null;
    }
    _text.removeListener(refreshPage);
    _text.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ── Send (optimistic) ─────────────────────────────────────────────────────

  Future<String> _ensureChatCreated() async {
    if (_chatId != null) return _chatId!;
    if (_creatingChat) {
      while (_creatingChat) {
        await Future.delayed(const Duration(milliseconds: 70));
      }
      if (_chatId != null) return _chatId!;
    }
    setState(() => _creatingChat = true);
    try {
      final id = await AppServices.chatApi.createDirectChat(_peer.id);
      _chatId = id;
      await _connectWsIfPossible();
      return id;
    } finally {
      if (mounted) setState(() => _creatingChat = false);
    }
  }

  /// Optimistic send: message appears instantly with a clock icon,
  /// API call runs in background, then the placeholder is replaced
  /// with the server-confirmed message (or marked failed on error).
  Future<void> _send() async {
    final me = UserScope.of(context).value;
    if (me == null) {
      showErrorSnackBar('Please sign in to send messages', mounted, context);
      return;
    }

    final body = _text.text.trim();
    final image = _pendingImage;
    if (body.isEmpty && image == null) return;
    if (_creatingChat) return;

    final localId = _newLocalId();
    final now = DateTime.now();

    // ── 1. Show message immediately ──────────────────────────────────────
    final optimistic = MessageItem.optimistic(
      localId: localId,
      chatId: _chatId ?? '',
      sender: me.id,
      senderUsername: me.username ?? '',
      body: body.isEmpty ? null : body,
      localImagePath: image?.path,
      createdAt: now,
    );

    setState(() {
      _messages.add(optimistic);
      _text.clear();
      _pendingImage = null;
    });
    _scrollToBottom(delayMs: 20);

    // ── 2. Persist to buffer (survives navigation) ───────────────────────
    final chatIdSnap = _chatId ?? '';
    if (chatIdSnap.isNotEmpty) {
      await _buffer.save(PendingBufferEntry(
        localId: localId,
        chatId: chatIdSnap,
        senderId: me.id,
        senderUsername: me.username ?? '',
        body: body.isEmpty ? null : body,
        localImagePath: image?.path,
        createdAt: now,
      ));
    }

    // ── 3. Send in background ────────────────────────────────────────────
    try {
      final chatId = await _ensureChatCreated();

      // If the chat was a draft, save the buffer entry now with the real id.
      if (chatIdSnap.isEmpty) {
        await _buffer.save(PendingBufferEntry(
          localId: localId,
          chatId: chatId,
          senderId: me.id,
          senderUsername: me.username ?? '',
          body: body.isEmpty ? null : body,
          localImagePath: image?.path,
          createdAt: now,
        ));
      }

      final created = await AppServices.chatApi.sendTextMessage(
        chatId: chatId,
        body: body.isEmpty ? null : body,
        imageFile: image,
      );

      if (!mounted) return;

      setState(() {
        final i = _messages.indexWhere((m) => m.localId == localId);
        if (i != -1) {
          // Normal case: replace placeholder with confirmed message.
          _messages[i] = created;
        } else {
          // WS arrived first and already reconciled; just ensure no phantom.
          _messages.removeWhere(
              (m) => m.localId == localId && m.isPending);
        }
      });

      await _buffer.remove(chatId, localId);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        final i = _messages.indexWhere((m) => m.localId == localId);
        if (i != -1) {
          _messages[i] =
              _messages[i].copyWith(isPending: false, isFailed: true);
        }
      });

      if (chatIdSnap.isNotEmpty) {
        await _buffer.remove(chatIdSnap, localId);
      }

      String msg = 'Failed to send';
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map && data['detail'] != null) {
          msg = data['detail'].toString();
        } else {
          msg = 'Failed to send: ${e.response?.statusCode ?? ""}';
        }
      } else {
        msg = 'Failed to send: $e';
      }

      showErrorSnackBar(msg, mounted, context);
    }
  }

  // ── WS events ──────────────────────────────────────────────────────────────

  void _onWsEvent(Map<String, dynamic> e) {
    final type = e['type'];
    final payload = e['payload'];
    final me = UserScope.of(context).value;

    if (type == 'message.created') {
      final m = MessageItem.fromJson(payload);

      // Already in list (by real id)?
      if (_messages.any((x) => x.id == m.id)) return;

      if (_chat != null) {
        AppServices.chatStore
            .upsert(_chat!.copyWith(lastMessageAt: m.createdAt));
      }

      // Reconcile with our own optimistic placeholder.
      if (me != null && m.sender == me.id) {
        final idx = _messages.indexWhere((x) =>
            x.isPending &&
            x.localId != null &&
            x.body == m.body &&
            m.createdAt.difference(x.createdAt).abs().inSeconds < 30);
        if (idx != -1) {
          setState(() => _messages[idx] = m);
          return;
        }
      }

      setState(() => _messages.add(m));
      _scrollToBottom(delayMs: 20);
      return;
    }

    if (type == 'message.edited') {
      final m = MessageItem.fromJson(payload);
      setState(() {
        final i = _messages.indexWhere((x) => x.id == m.id);
        if (i != -1) _messages[i] = m;
      });
      return;
    }

    if (type == 'message.deleted') {
      final id = payload['id'];
      final intId = (id is int) ? id : int.tryParse(id.toString());
      if (intId == null) return;
      setState(() => _messages.removeWhere((x) => x.id == intId));
      return;
    }

    if (type == 'chat.deleted_for_all') {
      final chatId = payload['chat_id'];
      if (_chatId == chatId && mounted) Navigator.pop(context);
      return;
    }

    if (type == 'chat.deleted_for_me') {
      if (me == null) return;
      final chatId = payload['chat_id'];
      final userId = payload['user_id'];
      if (_chatId == chatId && userId == me.id && mounted) {
        Navigator.pop(context);
      }
    }
  }

  // ── Scroll ────────────────────────────────────────────────────────────────

  void _scrollToBottom({int delayMs = 0}) {
    if (!_scroll.hasClients) return;
    void go() {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }

    if (delayMs > 0) {
      Future.delayed(Duration(milliseconds: delayMs), go);
    } else {
      go();
    }
  }

  // ── Image helpers ─────────────────────────────────────────────────────────

  String? _msgImageUrl(MessageItem m) {
    if (m.isPending) return null; // local file shown separately
    final img = m.image;
    if (img == null || img.isEmpty) return null;
    if (img.startsWith('http')) return img;
    return '${Api.baseUrl}$img';
  }

  File? _msgLocalFile(MessageItem m) {
    if (m.localImagePath != null) return File(m.localImagePath!);
    return null;
  }

  void _openImagePreview(String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (_) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 4.0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final me = UserScope.of(context).value;
    if (me == null) {
      showErrorSnackBar('Please sign in to send images', mounted, context);
      return;
    }
    try {
      final x = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 2000,
      );
      if (x == null) return;
      setState(() => _pendingImage = File(x.path));
    } catch (e) {
      showErrorSnackBar('Failed to pick image: $e', mounted, context);
    }
  }

  Future<void> _showAttachSheet() async {
    final me = UserScope.of(context).value;
    if (me == null) {
      showErrorSnackBar('Please sign in to send images', mounted, context);
      return;
    }
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
          ],
        ),
      ),
    );
    if (action == 'gallery') await _pickImage(ImageSource.gallery);
    if (action == 'camera') await _pickImage(ImageSource.camera);
  }

  // ── Menu actions ──────────────────────────────────────────────────────────

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DriverProfilePage(profile: _peer)),
    );
  }

  void _call() async {
    if (_startingCall || _creatingChat) return;
    _startingCall = true;
    try {
      final chatId = await _ensureChatCreated();
      AppServices.callController.startOutgoingCall(
        chatId: chatId,
        calleeId: _peer.id,
        peer: _peer,
      );
    } finally {
      _startingCall = false;
    }
  }

  void _searchMessage() {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('TODO: Search message')));
  }

  void _clearHistory() => setState(() => _messages.clear());

  Future<void> _deleteChat() async {
    final id = _chatId;
    if (id == null) {
      Navigator.pop(context);
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete chat?'),
        content: const Text('This will delete chat for you.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await AppServices.chatApi.deleteChatForMe(id);
      await _buffer.clearForChat(id);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      showErrorSnackBar('Failed to delete: $e', mounted, context);
    }
  }

  Future<void> _blockUser() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Block driver?'),
        content: const Text(
            'You will no longer be able to chat or call.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Block')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await AppServices.chatApi.blockUser(_peer.id);
      if (!mounted) return;
      Navigator.pop(context);
      showSuccessSnackBar('User blocked', mounted, context);
    } catch (e) {
      showErrorSnackBar('Failed to block: $e', mounted, context);
    }
  }

  Future<void> _editMessageModal(String chatId, MessageItem m) async {
    final c = TextEditingController(text: m.body ?? '');
    bool saving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          Future<void> save() async {
            final newBody = c.text.trim();
            if (newBody.isEmpty) return;
            setModalState(() => saving = true);
            try {
              final updated = await AppServices.chatApi.editMessage(
                chatId: chatId,
                messageId: m.id,
                body: newBody,
              );
              if (!mounted) return;
              setState(() {
                final i = _messages.indexWhere((x) => x.id == m.id);
                if (i != -1) _messages[i] = updated;
              });
              Navigator.pop(ctx);
            } catch (e) {
              showErrorSnackBar('Failed to edit: $e', mounted, context);
            } finally {
              if (ctx.mounted) setModalState(() => saving = false);
            }
          }

          final bottom = MediaQuery.of(ctx).viewInsets.bottom;
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, bottom + 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Edit message',
                    style: TextStyle(fontSize: 16)),
                const SizedBox(height: 10),
                TextField(
                    controller: c,
                    minLines: 2,
                    maxLines: 6,
                    autofocus: true),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: saving ? null : () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: saving ? null : save,
                      child: saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2))
                          : const Text('Save'),
                    ),
                  ),
                ]),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Bubble ────────────────────────────────────────────────────────────────

  String _formatTime(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  /// Telegram-style status icon shown on the sender's messages.
  Widget _statusIcon(MessageItem m) {
    if (m.isFailed) {
      return const Icon(Icons.error_outline,
          size: 13, color: Color(0xFFE53935));
    }
    if (m.isPending) {
      return SizedBox(
        width: 13,
        height: 13,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: Colors.black.withOpacity(0.4),
        ),
      );
    }
    return Icon(Icons.done,
        size: 13, color: Colors.black.withOpacity(0.45));
  }

  Widget _bubble(MessageItem m) {
    final me = UserScope.of(context).value;
    final isMe = me != null && m.sender == me.id;

    final bubbleColor = isMe
        ? KColors.thirdColor.withOpacity(0.85)
        : KColors.lightBackgroundColor;

    final time = _formatTime(m.createdAt);
    final imgUrl = _msgImageUrl(m);
    final localFile = _msgLocalFile(m);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: () async {
            final me = UserScope.of(context).value;
            final chatId = _chatId;
            if (me == null || chatId == null) return;

            // For failed messages: long-press dismisses.
            if (m.isFailed) {
              setState(() =>
                  _messages.removeWhere((x) => x.localId == m.localId));
              return;
            }
            // Pending messages can't be acted on yet.
            if (m.isPending) return;

            final action = await showModalBottomSheet<String>(
              context: context,
              builder: (_) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (m.body != null && m.body!.isNotEmpty && isMe)
                      ListTile(
                        leading: const Icon(Icons.edit),
                        title: const Text('Edit message'),
                        onTap: () => Navigator.pop(context, 'edit'),
                      ),
                    ListTile(
                      leading: const Icon(Icons.delete_outline),
                      title: const Text('Delete for me'),
                      onTap: () => Navigator.pop(context, 'del_me'),
                    ),
                    if (isMe)
                      ListTile(
                        leading: const Icon(Icons.delete,
                            color: Colors.red),
                        title: const Text('Delete for everyone',
                            style: TextStyle(color: Colors.red)),
                        onTap: () => Navigator.pop(context, 'del_all'),
                      ),
                  ],
                ),
              ),
            );

            if (action == null) return;
            try {
              if (action == 'del_me') {
                await AppServices.chatApi
                    .deleteMessageForMe(chatId, m.id);
              } else if (action == 'del_all') {
                await AppServices.chatApi
                    .deleteMessageForAll(chatId, m.id);
              } else if (action == 'edit') {
                await _editMessageModal(chatId, m);
                return;
              }
              if (!mounted) return;
              setState(() => _messages.removeWhere((x) => x.id == m.id));
            } catch (e) {
              showErrorSnackBar('Failed: $e', mounted, context);
            }
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: ClipRRect(
              borderRadius: isMe
                  ? const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(0),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    )
                  : const BorderRadius.only(
                      topLeft: Radius.circular(0),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: m.isFailed
                      ? const Color(0xFFFFCDD2)
                      : bubbleColor,
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                      color: Colors.black.withOpacity(0.08),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    0,
                    (imgUrl != null || localFile != null) ? 0 : 10,
                    0,
                    8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Image area
                      if (localFile != null) ...[
                        ConstrainedBox(
                          constraints:
                              const BoxConstraints(maxHeight: 220),
                          child: Opacity(
                            opacity: m.isPending ? 0.65 : 1.0,
                            child: Image.file(localFile,
                                fit: BoxFit.cover),
                          ),
                        ),
                        if ((m.body ?? '').trim().isNotEmpty)
                          const SizedBox(height: 8),
                      ] else if (imgUrl != null) ...[
                        GestureDetector(
                          onTap: () => _openImagePreview(imgUrl),
                          child: ConstrainedBox(
                            constraints:
                                const BoxConstraints(maxHeight: 220),
                            child: Image.network(
                              imgUrl,
                              fit: BoxFit.cover,
                              loadingBuilder: (_, child, progress) {
                                if (progress == null) return child;
                                return const SizedBox(
                                  height: 160,
                                  width: 220,
                                  child: Center(
                                      child: CircularProgressIndicator()),
                                );
                              },
                              errorBuilder: (_, __, ___) => Container(
                                height: 140,
                                alignment: Alignment.center,
                                color: Colors.black12,
                                child: const Text('Failed to load image'),
                              ),
                            ),
                          ),
                        ),
                        if ((m.body ?? '').trim().isNotEmpty)
                          const SizedBox(height: 8),
                      ],

                      // Text body
                      if ((m.body ?? '').trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14),
                          child: Text(
                            m.body!,
                            style: const TextStyle(
                                color: Colors.black, height: 1.25),
                          ),
                        ),

                      const SizedBox(height: 4),

                      // Time + status row
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              time,
                              style: TextStyle(
                                color: Colors.black.withOpacity(0.45),
                                fontSize: 11,
                                height: 1,
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 4),
                              _statusIcon(m),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Input bar ─────────────────────────────────────────────────────────────

  Widget _draftCenterText() {
    return Center(
      child: Text(
        'Start messaging to create chat',
        style: TextStyle(
          color: Colors.black.withOpacity(0.35),
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _inputBar() {
    final me = UserScope.of(context).value;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: KColors.mainColor,
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: GestureDetector(
                  onTap: _showAttachSheet,
                  child: const Icon(Icons.attach_file,
                      color: Colors.white),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: _text,
                  focusNode: _focus,
                  enabled: me != null,
                  textInputAction: TextInputAction.newline,
                  style: KTextStyles.fontSmallStyle
                      .copyWith(color: Colors.white),
                  cursorColor: Colors.white,
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: me == null
                        ? 'Sign in to chat...'
                        : 'Send message...',
                    hintStyle: KTextStyles.fontSmallStyle.copyWith(
                      color: Colors.white.withOpacity(0.75),
                    ),
                    border: InputBorder.none,
                    isCollapsed: true,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              if (_text.text.isNotEmpty || _pendingImage != null)
                IconButton(
                  onPressed: me == null || _creatingChat ? null : _send,
                  icon: _creatingChat
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send, color: Colors.white),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  Widget _avatar() {
    final p = _peer.photo;
    if (p != null && p.isNotEmpty) {
      return CircleAvatar(radius: 16, backgroundImage: NetworkImage(p));
    }
    return const CircleAvatar(
      radius: 20,
      backgroundImage: AssetImage('assets/images/blank_avatar.png'),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final me = UserScope.of(context).value;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: KColors.mainColor,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => HomePage()),
            );
          },
          icon: SvgPicture.asset(
            'assets/svgs/arrow_back.svg',
            width: 25,
            height: 14,
            colorFilter: const ColorFilter.mode(
                Colors.white, BlendMode.srcIn),
          ),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            _avatar(),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _peerTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: KTextStyles.fontMediumBigStyle.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call, color: Colors.white),
            onPressed: me == null ? null : _call,
          ),
          PopupMenuButton<_ChatMenuAction>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: KColors.thirdColor,
            onSelected: (a) {
              switch (a) {
                case _ChatMenuAction.profile:
                  _openProfile();
                case _ChatMenuAction.call:
                  _call();
                case _ChatMenuAction.search:
                  _searchMessage();
                case _ChatMenuAction.clear:
                  _clearHistory();
                case _ChatMenuAction.delete:
                  _deleteChat();
                case _ChatMenuAction.block:
                  _blockUser();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: _ChatMenuAction.profile,
                child: _MenuRow(
                    icon: Icons.person, text: "Driver's profile"),
              ),
              const PopupMenuItem(
                value: _ChatMenuAction.call,
                child: _MenuRow(icon: Icons.call, text: 'Call'),
              ),
              const PopupMenuItem(
                value: _ChatMenuAction.search,
                child: _MenuRow(
                    icon: Icons.search, text: 'Search message'),
              ),
              const PopupMenuItem(
                value: _ChatMenuAction.clear,
                child: _MenuRow(
                    icon: Icons.cleaning_services,
                    text: 'Clear history'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: _ChatMenuAction.delete,
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 10),
                    Text('Видалити чат',
                        style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: _ChatMenuAction.block,
                child: Row(
                  children: [
                    Icon(Icons.block, color: Colors.red),
                    SizedBox(width: 10),
                    Text('Заблокувати водія',
                        style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? _skeletonList()
                : (_messages.isEmpty
                    ? (_isDraft
                        ? _draftCenterText()
                        : const SizedBox.shrink())
                    : ListView.builder(
                        controller: _scroll,
                        padding:
                            const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) {
                          final message = _messages[i];
                          final currentDate = message.createdAt;
                          final prevDate = i > 0
                              ? _messages[i - 1].createdAt
                              : null;

                          final showSep = prevDate == null ||
                              currentDate.year != prevDate.year ||
                              currentDate.month != prevDate.month ||
                              currentDate.day != prevDate.day;

                          return Column(
                            children: [
                              if (showSep)
                                ChatDateSeparator(date: currentDate),
                              _bubble(message),
                            ],
                          );
                        },
                      )),
          ),

          if (_pendingImage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(_pendingImage!,
                        width: 64, height: 64, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Image ready to send',
                      style: KTextStyles.fontSmallStyle
                          .copyWith(color: Colors.black54),
                    ),
                  ),
                  IconButton(
                    onPressed: () =>
                        setState(() => _pendingImage = null),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

          _inputBar(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Supporting widgets / enums
// ─────────────────────────────────────────────────────────────────────────────

enum _ChatMenuAction { profile, call, search, clear, delete, block }

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MenuRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: KColors.mainColor),
        const SizedBox(width: 10),
        Text(text),
      ],
    );
  }
}

class ChatDateSeparator extends StatelessWidget {
  final DateTime date;

  const ChatDateSeparator({super.key, required this.date});

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final isToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
    if (isToday) return 'Today';

    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
    if (isYesterday) return 'Yesterday';

    const months = [
      '',
      'January', 'February', 'March', 'April',
      'May', 'June', 'July', 'August',
      'September', 'October', 'November', 'December',
    ];
    return '${months[date.month]} ${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Center(
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
          decoration: BoxDecoration(
            color: KColors.lightBackgroundColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            _formatDate(date),
            style: const TextStyle(
              color: Colors.black,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}