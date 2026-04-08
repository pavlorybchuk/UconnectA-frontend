import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:uconnecta/data/constrains.dart';

class ChatCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final ImageProvider? avatar;

  final VoidCallback? onTap;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onCall;
  final VoidCallback? onToggleAutoDelete;
  final VoidCallback? onDeleteChat;
  final VoidCallback? onBlockDriver;
  final DateTime? autoDeleteEnabledAt;
  final bool autoDeleteEnabled;

  const ChatCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.autoDeleteEnabledAt,
    this.avatar,
    this.onTap,
    this.onOpenProfile,
    this.onCall,
    this.onToggleAutoDelete,
    this.onDeleteChat,
    this.onBlockDriver,
    this.autoDeleteEnabled = false,
  });

  String _hhmm(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return "$h:$m";
  }

  DateTime? _deleteAt() {
    if (!autoDeleteEnabled) return null;
    if (autoDeleteEnabledAt == null) return null;
    return autoDeleteEnabledAt!.toLocal().add(const Duration(hours: 24));
  }

  @override
  Widget build(BuildContext context) {
    final delAt = _deleteAt();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Material(
        color: KColors.mainColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            height: 76,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.white.withOpacity(.2),
                  backgroundImage:
                      avatar ??
                      const AssetImage("assets/images/blank_avatar.png")
                          as ImageProvider,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KTextStyles.fontMediumBigStyle.copyWith(
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KTextStyles.fontSmallStyle.copyWith(
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (delAt != null)
                        Text(
                          "This chat will be deleted at ${_hhmm(delAt)}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: KTextStyles.fontSmallStyle.copyWith(
                            color: KColors.mediumColor,
                            height: 1,
                          ),
                        ),
                    ],
                  ),
                ),
                _MoreButton(
                  autoDeleteEnabled: autoDeleteEnabled,
                  onOpenProfile: onOpenProfile,
                  onCall: onCall,
                  onToggleAutoDelete: onToggleAutoDelete,
                  onDeleteChat: onDeleteChat,
                  onBlockDriver: onBlockDriver,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MoreButton extends StatefulWidget {
  final VoidCallback? onOpenProfile;
  final VoidCallback? onCall;
  final VoidCallback? onToggleAutoDelete;
  final VoidCallback? onDeleteChat;
  final VoidCallback? onBlockDriver;

  final bool autoDeleteEnabled;

  const _MoreButton({
    required this.autoDeleteEnabled,
    this.onOpenProfile,
    this.onCall,
    this.onToggleAutoDelete,
    this.onDeleteChat,
    this.onBlockDriver,
  });

  @override
  State<_MoreButton> createState() => _MoreButtonState();
}

class _MoreButtonState extends State<_MoreButton> {
  final GlobalKey _btnKey = GlobalKey();

  void _openMenu() {
    final renderBox = _btnKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final btnPos = renderBox.localToGlobal(Offset.zero);
    final btnSize = renderBox.size;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "menu",
      barrierColor: Colors.black.withOpacity(.15),
      transitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (ctx, a1, a2) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.of(ctx).pop(),
                child: Container(color: Colors.transparent),
              ),
            ),

            Positioned(
              left: (btnPos.dx - 210).clamp(12.0, window.physicalSize.width),
              top: btnPos.dy + btnSize.height - 30,
              child: _MenuCard(
                autoDeleteEnabled: widget.autoDeleteEnabled,
                onOpenProfile: () {
                  Navigator.of(ctx).pop();
                  widget.onOpenProfile?.call();
                },
                onCall: () {
                  Navigator.of(ctx).pop();
                  widget.onCall?.call();
                },
                onToggleAutoDelete: () {
                  Navigator.of(ctx).pop();
                  widget.onToggleAutoDelete?.call();
                },
                onDeleteChat: () {
                  Navigator.of(ctx).pop();
                  widget.onDeleteChat?.call();
                },
                onBlockDriver: () {
                  Navigator.of(ctx).pop();
                  widget.onBlockDriver?.call();
                },
              ),
            ),
          ],
        );
      },
      transitionBuilder: (ctx, anim, sec, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOut);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: _btnKey,
      icon: const Icon(Icons.more_vert, color: Colors.white),
      onPressed: _openMenu,
      splashRadius: 20,
      tooltip: "More",
    );
  }
}

class _MenuCard extends StatelessWidget {
  final VoidCallback? onOpenProfile;
  final VoidCallback? onCall;
  final VoidCallback? onToggleAutoDelete;
  final VoidCallback? onDeleteChat;
  final VoidCallback? onBlockDriver;
  final bool autoDeleteEnabled;

  const _MenuCard({
    required this.autoDeleteEnabled,
    this.onOpenProfile,
    this.onCall,
    this.onToggleAutoDelete,
    this.onDeleteChat,
    this.onBlockDriver,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: KColors.thirdColor,
      elevation: 10,
      shadowColor: Colors.black.withOpacity(.25),
      borderRadius: BorderRadius.circular(14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 230,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MenuItem(
                icon: Icons.badge_outlined,
                text: "Driver’s profile",
                onTap: onOpenProfile,
              ),
              _MenuItem(icon: Icons.call, text: "Call", onTap: onCall),
              _MenuItem(
                icon: Icons.timer_outlined,
                text: autoDeleteEnabled
                    ? "Auto-delete (ON)"
                    : "Auto-delete (24 hours)",
                onTap: onToggleAutoDelete,
              ),
              const Divider(height: 1),
              _MenuItem(
                icon: Icons.delete_outline,
                text: "Delete chat",
                textColor: Colors.red,
                iconColor: Colors.red,
                onTap: onDeleteChat,
              ),
              _MenuItem(
                icon: Icons.block,
                text: "Block driver",
                textColor: Colors.red,
                iconColor: Colors.red,
                onTap: onBlockDriver,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;
  final Color? textColor;
  final Color? iconColor;

  const _MenuItem({
    required this.icon,
    required this.text,
    this.onTap,
    this.textColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = textColor ?? const Color(0xFF0F2D46);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 26, color: iconColor ?? color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 16,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
