import 'dart:async';
// import 'dart:nativewrappers/_internal/vm/lib/ffi_allocation_patch.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:uconnecta/app_services.dart';
import 'package:uconnecta/auth/user_scope.dart';
import 'package:uconnecta/data/constrains.dart';
import 'package:uconnecta/data/navigation_service.dart';
import 'package:uconnecta/pages/driver_profile_page.dart';
import 'package:uconnecta/pages/home_page.dart';
import 'dart:io';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import 'package:uconnecta/data/api.dart';
import 'package:image_picker/image_picker.dart';

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
  ChatListItem? _chat;
  final List<MessageItem> _messages = [];
  final _picker = ImagePicker();
  File? _pendingImage;

  String? _chatId;
  bool _loading = false;
  bool _sending = false;
  bool _creatingChat = false;

  bool get _isDraft => _chatId == null;

  DriverProfile get _peer {
    if (widget.otherUser != null) return widget.otherUser!;
    return _chat!.otherUser;
  }

  String get _peerTitle => _peer.displayName ?? "Anonymous";
  bool _startingCall = false;

  WebSocketChannel? _ws;
  StreamSubscription? _wsSub;

  String _wsBase() {
    // Api.baseUrl = "https://host"
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
    if (chatId == null) return;

    // already connected
    if (_ws != null) return;

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
            // NEW формат: {"type": "...", "payload": ...}
            if (data.containsKey("type")) {
              if (!mounted) return;
              _onWsEvent(data);
              return;
            }

            // OLD fallback: якщо сервер ще шле просто MessageSerializer
            final msg = MessageItem.fromJson(data);
            final exists = _messages.any((m) => m.id == msg.id);
            if (exists) return;

            if (!mounted) return;
            setState(() => _messages.add(msg));
            _scrollToBottom(delayMs: 20);
          }
        } catch (_) {
          // ignore bad payload
        }
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

  Future<void> _initChat() async {
    // 1️⃣ якщо чат уже передали напряму
    if (widget.chat != null) {
      _chat = widget.chat;
      _chatId = widget.chat!.id;

      await _loadMessages();
      await _connectWsIfPossible();
      return;
    }

    // 2️⃣ якщо прийшли з FCM / deeplink
    if (widget.chatId != null) {
      setState(() => _loading = true);
      try {
        final chats = await AppServices.chatApi.fetchChats();
        final store = AppServices.chatStore;
        final cached = store.getById(widget.chatId!);

        if (cached != null) {
          _chat = cached;
        } else {
          final chats = await AppServices.chatApi.fetchChats();
          store.setChats(chats);
          _chat = store.getById(widget.chatId!);
        }
        final found = chats.firstWhere((c) => c.id == widget.chatId);

        _chat = found;
        _chatId = found.id;

        await _loadMessages();
        await _connectWsIfPossible();
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Chat not found")));
        Navigator.pop(context);
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    ChatNavigationTracker.currentChatId = widget.chat?.id ?? widget.chatId;
    _chatId = widget.chat?.id;
    _initChat();
  }

  @override
  void dispose() {
    _closeWs();
    if (ChatNavigationTracker.currentChatId == _chatId) {
      ChatNavigationTracker.currentChatId = null;
    }
    _text.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final id = _chatId;
    if (id == null) return;

    setState(() => _loading = true);
    try {
      final items = await AppServices.chatApi.fetchMessages(id);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(items);
      });
      _scrollToBottom(delayMs: 50);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to load messages: $e")));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _msgImageUrl(MessageItem m) {
    final img = m.image;
    if (img == null || img.isEmpty) return null;
    if (img.startsWith('http')) return img;
    return '${Api.baseUrl}$img';
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please sign in to send images")),
      );
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
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to pick image: $e")));
    }
  }

  void _scrollToBottom({int delayMs = 0}) {
    if (!_scroll.hasClients) return;

    if (delayMs > 0) {
      Future.delayed(Duration(milliseconds: delayMs), () {
        if (!_scroll.hasClients) return;
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      });
      return;
    }

    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

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

  Future<void> _send() async {
    final me = UserScope.of(context).value;
    if (me == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please sign in to send messages")),
      );
      return;
    }

    final body = _text.text.trim();
    final image = _pendingImage;

    if (body.isEmpty && image == null) return;
    if (_sending || _creatingChat) return;

    setState(() => _sending = true);

    try {
      final id = await _ensureChatCreated();

      final created = await AppServices.chatApi.sendTextMessage(
        chatId: id,
        body: body.isEmpty ? null : body,
        imageFile: image,
      );

      if (!mounted) return;
      _text.clear();

      setState(() {
        _pendingImage = null;

        final i = _messages.indexWhere((m) => m.id == created.id);
        if (i == -1) {
          _messages.add(created);
        } else {
          // якщо WS уже додав — просто оновлюємо (на випадок image/body)
          _messages[i] = created;
        }
      });
      _scrollToBottom(delayMs: 20);
    } catch (e) {
      if (!mounted) return;

      String msg = "Failed to send";

      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map && data["detail"] != null) {
          msg = data["detail"].toString();
        } else {
          msg = "Failed to send: ${e.response?.statusCode ?? ''}";
        }
      } else {
        msg = "Failed to send: $e";
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ---------- MENU ACTIONS ----------
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
      );
    } finally {
      _startingCall = false;
    }
  }

  void _searchMessage() {
    // TODO: локальний пошук
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("TODO: Search message")));
  }

  void _clearHistory() {
    // локально чистимо
    setState(() => _messages.clear());
  }

  Future<void> _deleteChat() async {
    final id = _chatId;
    if (id == null) {
      // draft: просто вихід
      Navigator.pop(context);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete chat?"),
        content: const Text("This will delete chat for you."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await AppServices.chatApi.deleteChatForMe(id);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to delete: $e")));
    }
  }

  Future<void> _blockUser() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Block driver?"),
        content: const Text("You will no longer be able to chat or call."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Block"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await AppServices.chatApi.blockUser(_peer.id);
      if (!mounted) return;
      Navigator.pop(context); // назад з чату
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("User blocked")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to block: $e")));
    }
  }

  // ---------- UI HELPERS ----------
  Widget _avatar() {
    final p = _peer.photo;
    if (p != null && p.isNotEmpty) {
      return CircleAvatar(radius: 16, backgroundImage: NetworkImage(p));
    }
    return const CircleAvatar(
      radius: 20,
      backgroundImage: AssetImage("assets/images/blank_avatar.png"),
    );
  }

  String _formatTime(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return "$hh:$mm";
  }

  Future<void> _editMessageModal(String chatId, MessageItem m) async {
    final c = TextEditingController(text: m.body ?? "");
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
              if (!mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text("Failed to edit: $e")));
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
                const Text("Edit message", style: TextStyle(fontSize: 16)),
                const SizedBox(height: 10),
                TextField(
                  controller: c,
                  minLines: 2,
                  maxLines: 6,
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: saving ? null : () => Navigator.pop(ctx),
                        child: const Text("Cancel"),
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
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text("Save"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _bubble(MessageItem m) {
    final me = UserScope.of(context).value;
    final isMe = me != null && m.sender == me.id;

    final bubbleColor = isMe
        ? KColors.thirdColor.withOpacity(0.85)
        : KColors.lightBackgroundColor;
    final textColor = Colors.black;

    final time = _formatTime(m.createdAt);
    final imgUrl = _msgImageUrl(m);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: () async {
            final me = UserScope.of(context).value;
            final chatId = _chatId;

            if (me == null || chatId == null) return;

            final isMe = m.sender == me.id;

            final action = await showModalBottomSheet<String>(
              context: context,
              builder: (_) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (m.body != null && m.body!.isNotEmpty && isMe)
                      ListTile(
                        leading: const Icon(Icons.edit),
                        title: const Text("Edit message"),
                        onTap: () => Navigator.pop(context, "edit"),
                      ),
                    ListTile(
                      leading: const Icon(Icons.delete_outline),
                      title: const Text("Delete for me"),
                      onTap: () => Navigator.pop(context, "del_me"),
                    ),
                    if (isMe)
                      ListTile(
                        leading: const Icon(Icons.delete, color: Colors.red),
                        title: const Text(
                          "Delete for everyone",
                          style: TextStyle(color: Colors.red),
                        ),
                        onTap: () => Navigator.pop(context, "del_all"),
                      ),
                  ],
                ),
              ),
            );

            if (action == null) return;

            try {
              if (action == "del_me") {
                await AppServices.chatApi.deleteMessageForMe(chatId, m.id);
              } else if (action == "del_all") {
                await AppServices.chatApi.deleteMessageForAll(chatId, m.id);
              } else if (action == "edit") {
                await _editMessageModal(chatId, m);
              }

              if (!mounted) return;
              setState(() {
                _messages.removeWhere((x) => x.id == m.id);
              });
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text("Failed: $e")));
            }
          },

          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: ClipRRect(
              borderRadius: isMe
                  ? BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(0),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    )
                  : BorderRadius.only(
                      topLeft: Radius.circular(0),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: bubbleColor,

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
                    imgUrl != null ? 0 : 10,
                    0,
                    8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (imgUrl != null) ...[
                        GestureDetector(
                          onTap: () => _openImagePreview(imgUrl),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(0),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 220),
                              child: Image.network(
                                imgUrl,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return const SizedBox(
                                    height: 160,
                                    width: 220,
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                },
                                errorBuilder: (_, __, ___) => Container(
                                  height: 140,
                                  alignment: Alignment.center,
                                  color: Colors.black12,
                                  child: const Text("Failed to load image"),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if ((m.body ?? '').trim().isNotEmpty)
                          const SizedBox(height: 8),
                      ],
                      if ((m.body ?? '').trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            m.body!,
                            style: TextStyle(color: textColor, height: 1.25),
                          ),
                        ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          time,
                          style: TextStyle(
                            color: Colors.black.withOpacity(0.45),
                            fontSize: 11,
                            height: 1,
                          ),
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

  void _onWsEvent(Map<String, dynamic> e) {
    final type = e["type"];
    final payload = e["payload"];

    if (type == "message.created") {
      final m = MessageItem.fromJson(payload);
      final exists = _messages.any((x) => x.id == m.id);
      if (exists) return;

      AppServices.chatStore.upsert(_chat!.copyWith(lastMessageAt: m.createdAt));

      setState(() => _messages.add(m));
      _scrollToBottom(delayMs: 20);
    }

    if (type == "message.edited") {
      final m = MessageItem.fromJson(payload);
      setState(() {
        final i = _messages.indexWhere((x) => x.id == m.id);
        if (i != -1) _messages[i] = m;
      });
    }

    if (type == "message.deleted") {
      final id = payload["id"];
      final intId = (id is int) ? id : int.tryParse(id.toString());
      if (intId == null) return;

      setState(() => _messages.removeWhere((x) => x.id == intId));
    }

    if (type == "chat.deleted_for_all") {
      final chatId = payload["chat_id"];
      if (_chatId == chatId && mounted) Navigator.pop(context);
    }

    if (type == "chat.deleted_for_me") {
      final me = UserScope.of(context).value;
      if (me == null) return;

      final chatId = payload["chat_id"];
      final userId = payload["user_id"];
      if (_chatId == chatId && userId == me.id && mounted) {
        Navigator.pop(context);
      }
    }
  }

  Widget _draftCenterText() {
    return Center(
      child: Text(
        "Start messaging to create chat",
        style: TextStyle(
          color: Colors.black.withOpacity(0.35),
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Future<void> _showAttachSheet() async {
    final me = UserScope.of(context).value;
    if (me == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please sign in to send images")),
      );
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
              title: const Text("Gallery"),
              onTap: () => Navigator.pop(context, "gallery"),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text("Camera"),
              onTap: () => Navigator.pop(context, "camera"),
            ),
          ],
        ),
      ),
    );

    if (action == "gallery") {
      await _pickImage(ImageSource.gallery);
    } else if (action == "camera") {
      await _pickImage(ImageSource.camera);
    }
  }

  Widget _inputBar() {
    final me = UserScope.of(context).value;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: KColors.mainColor,
            borderRadius: BorderRadius.circular(24),
          ),
          padding: EdgeInsetsGeometry.symmetric(horizontal: 16),
          child: Row(
            spacing: 6,
            children: [
              GestureDetector(
                onTap: _showAttachSheet,
                child: const Icon(Icons.attach_file, color: KColors.thirdColor),
              ),
              Expanded(
                child: TextField(
                  controller: _text,
                  focusNode: _focus,
                  enabled: me != null && !_sending && !_creatingChat,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  style: KTextStyles.fontSmallStyle.copyWith(
                    color: Colors.white,
                  ),
                  cursorColor: Colors.white,
                  decoration: InputDecoration(
                    hintText: me == null
                        ? "Sign in to chat..."
                        : "Send message...",
                    hintStyle: KTextStyles.fontSmallStyle.copyWith(
                      color: Colors.white.withOpacity(0.75),
                    ),
                    border: InputBorder.none,
                    isCollapsed: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              IconButton(
                onPressed: (me == null || _sending || _creatingChat)
                    ? null
                    : _send,
                icon: (_sending || _creatingChat)
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        Icons.send,
                        color: !_sending
                            ? KColors.thirdColorHover
                            : KColors.thirdColor,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
            "assets/svgs/arrow_back.svg",
            width: 25,
            height: 14,
            colorFilter: ColorFilter.mode(KColors.thirdColor, BlendMode.srcIn),
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
                  fontWeight: .w600,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call, color: KColors.thirdColor),
            onPressed: me == null ? null : _call,
          ),
          PopupMenuButton<_ChatMenuAction>(
            icon: const Icon(Icons.more_vert, color: KColors.thirdColor),
            color: KColors.thirdColor,
            onSelected: (a) {
              switch (a) {
                case _ChatMenuAction.profile:
                  _openProfile();
                  break;
                case _ChatMenuAction.call:
                  _call();
                  break;
                case _ChatMenuAction.search:
                  _searchMessage();
                  break;
                case _ChatMenuAction.clear:
                  _clearHistory();
                  break;
                case _ChatMenuAction.delete:
                  _deleteChat();
                  break;
                case _ChatMenuAction.block:
                  _blockUser();
                  break;
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: _ChatMenuAction.profile,
                child: _MenuRow(icon: Icons.person, text: "Driver's profile"),
              ),
              const PopupMenuItem(
                value: _ChatMenuAction.call,
                child: _MenuRow(icon: Icons.call, text: "Call"),
              ),
              const PopupMenuItem(
                value: _ChatMenuAction.search,
                child: _MenuRow(icon: Icons.search, text: "Search message"),
              ),
              const PopupMenuItem(
                value: _ChatMenuAction.clear,
                child: _MenuRow(
                  icon: Icons.cleaning_services,
                  text: "Clear history",
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: _ChatMenuAction.delete,
                child: Row(
                  children: const [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 10),
                    Text("Видалити чат", style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: _ChatMenuAction.block,
                child: Row(
                  children: const [
                    Icon(Icons.block, color: Colors.red),
                    SizedBox(width: 10),
                    Text(
                      "Заблокувати водія",
                      style: TextStyle(color: Colors.red),
                    ),
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
                ? const Center(child: CircularProgressIndicator())
                : (_messages.isEmpty
                      ? (_isDraft
                            ? _draftCenterText()
                            : const SizedBox.shrink())
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                          itemCount: _messages.length,
                          itemBuilder: (_, i) => _bubble(_messages[i]),
                        )),
          ),
          if (_pendingImage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _pendingImage!,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Image ready to send",
                      style: KTextStyles.fontSmallStyle.copyWith(
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _pendingImage = null),
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
