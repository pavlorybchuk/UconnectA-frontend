import 'dart:async';
import 'package:uconnecta/data/navigation_service.dart';
import 'package:uconnecta/pages/account_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:uconnecta/app_services.dart';
import 'package:uconnecta/auth/user_scope.dart';
import 'package:uconnecta/components/chat_card.dart';
import 'package:uconnecta/components/search_field.dart';
import 'package:uconnecta/components/sort_tab.dart';
import 'package:uconnecta/data/constrains.dart';
import 'package:uconnecta/pages/call_page.dart';
import 'package:uconnecta/pages/chat_page.dart';
import 'package:uconnecta/pages/driver_profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController controller1 = TextEditingController();
  final List<String> sortTabs = const [
    "Last message ↓",
    "Last message ↑",
    "Unread",
    "Auto-delete",
  ];
  final ValueNotifier<int> sortNotifier = ValueNotifier<int>(0);
  bool _loading = true;
  String? _error;
  List<ChatListItem> _allChats = [];
  Timer? _wsReloadDebounce;
  bool _wsStarted = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final VoidCallback _onSortChanged;

  @override
  void initState() {
    super.initState();

    _loadChatsForIndex(sortNotifier.value);

    _onSortChanged = () => _loadChatsForIndex(sortNotifier.value);
    sortNotifier.addListener(_onSortChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_wsStarted) return;

    final me = UserScope.of(context).value;
    if (me == null) return;

    _wsStarted = true;

    AppServices.userWs.connect(
      onEvent: (event) {
        final type = event["type"]?.toString();

        if (type == "call.incoming") {
          final callId = event["call_id"];
          final chatId = event["chat_id"];
          final fromUser = DriverProfile.fromJson(event["from_user"]);

          NavigationService.navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) =>
                  CallPage(callId: callId, chatId: chatId, fromUser: fromUser),
            ),
          );
        }

        const reloadTypes = {
          "chat.created",
          "chat.deleted_for_me",
          "chat.deleted_for_all",
          "chat.restored",
          "message.created",
        };

        if (type != null && reloadTypes.contains(type)) {
          _wsReloadDebounce?.cancel();
          _wsReloadDebounce = Timer(const Duration(milliseconds: 250), () {
            if (!mounted) return;
            _loadChatsForIndex(sortNotifier.value);
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _wsReloadDebounce?.cancel();

    sortNotifier.removeListener(_onSortChanged);
    AppServices.userWs.disconnect();

    controller1.dispose();
    super.dispose();
  }

  Future<void> _loadChatsForIndex(int index) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final chats = await AppServices.chatApi.fetchChats(sort: "last_message");

      AppServices.chatStore.setChats(chats);

      setState(() {
        _allChats = chats;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<ChatListItem> _applyUiSortAndFilters(
    List<ChatListItem> chats,
    int index,
  ) {
    var out = List<ChatListItem>.from(chats);

    if (index == 1) {
      out = out.reversed.toList();
    }
    if (index == 3) {
      out = out.where((c) => c.autoDelete == true).toList();
    }

    return out;
  }

  @override
  Widget build(BuildContext context) {
    final user = UserScope.of(context).value;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final filtered = _applyUiSortAndFilters(_allChats, sortNotifier.value);

    return Scaffold(
      key: _scaffoldKey,
      drawer: _AppDrawer(
        onHome: () => Navigator.pop(context),
        onAccount: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AccountPage()),
          );
        },
        onSettings: () {
          Navigator.pop(context);
          // TODO
        },
        onCallsHistory: () {
          Navigator.pop(context);
          // TODO
        },
        onBlockedUsers: () {
          Navigator.pop(context);
          // TODO
        },
        onInstruction: () {
          Navigator.pop(context);
          // TODO
        },
        onSupport: () {
          Navigator.pop(context);
          // TODO
        },
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => _scaffoldKey.currentState?.openDrawer(),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: SvgPicture.asset(
                          'assets/svgs/menu_icon.svg',
                          width: 25,
                          height: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SearchInput(
                        key: const ValueKey("Main page search"),
                        controller: controller1,
                        isOnMainPage: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (user.hasPassword)
                      GestureDetector(
                        onTap: () {},
                        child: SvgPicture.asset(
                          'assets/svgs/locker_icon.svg',
                          width: 20,
                          height: 22,
                        ),
                      ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                child: SizedBox(
                  height: 44,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: sortTabs.asMap().entries.map((entry) {
                              final i = entry.key;
                              final el = entry.value;

                              return Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: SortTab(
                                  title: el,
                                  notifier: sortNotifier,
                                  index: i,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        child: IgnorePointer(
                          child: Container(
                            width: 16,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Theme.of(context).scaffoldBackgroundColor,
                                  Theme.of(
                                    context,
                                  ).scaffoldBackgroundColor.withOpacity(0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: IgnorePointer(
                          child: Container(
                            width: 16,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerRight,
                                end: Alignment.centerLeft,
                                colors: [
                                  Theme.of(context).scaffoldBackgroundColor,
                                  Theme.of(
                                    context,
                                  ).scaffoldBackgroundColor.withOpacity(0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 30),
                  child: CircularProgressIndicator(),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                  child: Column(
                    children: [
                      Text(
                        "Error loading chats:\n$_error",
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => _loadChatsForIndex(sortNotifier.value),
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                )
              else if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 30),
                  child: Text("No chats yet"),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final chat = filtered[i];
                    final other = chat.otherUser;

                    return ChatCard(
                      title: other.displayName ?? "Unknown driver",
                      subtitle: "@${other.username}",
                      avatar: other.photoUrl != null
                          ? NetworkImage(other.photoUrl!)
                          : null,
                      autoDeleteEnabled: chat.autoDelete,
                      autoDeleteEnabledAt: chat.autoDeleteEnabledAt,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatPage(chat: chat),
                          ),
                        );

                        if (!mounted) return;

                        setState(() {
                          _allChats = AppServices.chatStore.all;
                        });
                      },

                      onOpenProfile: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DriverProfilePage(profile: other),
                          ),
                        );
                      },

                      onCall: () {
                        // TODO: прив’яжемо до /api/calls/create/
                      },

                      onToggleAutoDelete: () async {
                        try {
                          final data = await AppServices.chatApi
                              .toggleAutoDelete(chat.id);

                          final newAutoDelete = data["auto_delete"] == true;
                          final dtRaw = data["auto_delete_enabled_at"];
                          final newEnabledAt =
                              (dtRaw != null && dtRaw is String)
                              ? DateTime.parse(dtRaw)
                              : null;

                          final updated = ChatListItem(
                            id: chat.id,
                            type: chat.type,
                            createdAt: chat.createdAt,
                            lastMessageAt: chat.lastMessageAt,
                            autoDelete: newAutoDelete,
                            autoDeleteEnabledAt: newEnabledAt,
                            otherUser: chat.otherUser,
                          );

                          AppServices.chatStore.upsert(updated);
                          setState(() {
                            final index = _allChats.indexWhere(
                              (c) => c.id == chat.id,
                            );
                            if (index != -1) {
                              _allChats[index] = updated;
                            }
                          });
                        } catch (e) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(e.toString())));
                        }
                      },

                      onDeleteChat: () async {
                        final choice = await showDialog<String>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text("Delete chat"),
                            content: const Text(
                              "Choose how you want to delete this chat.",
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, null),
                                child: const Text("Cancel"),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, "me"),
                                child: const Text("Delete for me"),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, "all"),
                                child: const Text("Delete for everyone"),
                              ),
                            ],
                          ),
                        );

                        if (choice == null) return;

                        try {
                          if (choice == "me") {
                            await AppServices.chatApi.deleteChatForMe(chat.id);
                          } else {
                            await AppServices.chatApi.deleteChatForAll(chat.id);
                          }

                          if (!context.mounted) return;
                          AppServices.chatStore.remove(chat.id);

                          setState(() {
                            _allChats.removeWhere((c) => c.id == chat.id);
                          });

                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                choice == "me"
                                    ? "Chat deleted for you"
                                    : "Chat deleted for everyone",
                              ),
                            ),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(e.toString())));
                        }
                      },

                      onBlockDriver: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text("Block driver?"),
                            content: Text(
                              "You won’t be able to message or call or search user @${chat.otherUser.username}.",
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text("Cancel"),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text("Block"),
                              ),
                            ],
                          ),
                        );

                        if (ok != true) return;

                        try {
                          await AppServices.chatApi.blockUser(
                            chat.otherUser.id,
                          );
                          if (!mounted) return;
                          AppServices.chatStore.remove(chat.id);
                          setState(
                            () => _allChats.removeWhere((c) => c.id == chat.id),
                          );

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Driver blocked")),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(e.toString())));
                        }
                      },
                    );
                  },
                ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () {
                  final auth = AppServices.auth;
                  auth.logout();
                },
                child: const Text("Logout"),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppDrawer extends StatelessWidget {
  final VoidCallback onHome;
  final VoidCallback onAccount;
  final VoidCallback onSettings;
  final VoidCallback onCallsHistory;
  final VoidCallback onBlockedUsers;
  final VoidCallback onInstruction;
  final VoidCallback onSupport;

  const _AppDrawer({
    required this.onHome,
    required this.onAccount,
    required this.onSettings,
    required this.onCallsHistory,
    required this.onBlockedUsers,
    required this.onInstruction,
    required this.onSupport,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = KColors.mainColor;

    Widget item({
      required String iconPath,
      required String title,
      required VoidCallback onTap,
    }) {
      return ListTile(
        leading: SizedBox(
          width: 32,
          child: Center(
            child: SvgPicture.asset(
              iconPath,
              width: 25,
              height: 25,
              fit: BoxFit.contain,
              colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
            ),
          ),
        ),
        title: Text(title, style: const TextStyle(fontSize: 16)),
        onTap: onTap,
        horizontalTitleGap: 10,
        minLeadingWidth: 24,
      );
    }

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 8, top: 4),
              child: Row(
                mainAxisAlignment: .end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  item(
                    iconPath: "assets/svgs/home_icon.svg",
                    title: "Home",
                    onTap: onHome,
                  ),
                  item(
                    iconPath: "assets/svgs/profile_icon.svg",
                    title: "Account",
                    onTap: onAccount,
                  ),
                  item(
                    iconPath: "assets/svgs/settings_icon.svg",
                    title: "Settings",
                    onTap: onSettings,
                  ),
                  item(
                    iconPath: "assets/svgs/phone_icon.svg",
                    title: "Calls history",
                    onTap: onCallsHistory,
                  ),
                  item(
                    iconPath: "assets/svgs/block_icon.svg",
                    title: "Blocked users",
                    onTap: onBlockedUsers,
                  ),
                  item(
                    iconPath: "assets/svgs/instruction_icon.svg",
                    title: "Instruction",
                    onTap: onInstruction,
                  ),
                  item(
                    iconPath: "assets/svgs/support_icon.svg",
                    title: "Support",
                    onTap: onSupport,
                  ),
                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.only(bottom: 18),
              child: Text(
                "© All rights reserved",
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
