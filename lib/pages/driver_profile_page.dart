import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:uconnecta/app_services.dart';
import 'package:uconnecta/auth/user_scope.dart';
import 'package:uconnecta/pages/chat_page.dart';
import '../data/constrains.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class DriverProfilePage extends StatefulWidget {
  const DriverProfilePage({super.key, required this.profile});
  final DriverProfile profile;

  @override
  State<DriverProfilePage> createState() => _DriverProfilePageState();
}

class _DriverProfilePageState extends State<DriverProfilePage> {
  bool isPoliceExpanded = false;

  Future<void> _openSendMessageModal() async {
    String subject = '';
    String body = '';
    bool isSending = false;

    final carTag = widget.profile.carNumber != null
        ? "(${widget.profile.carNumber!.toUpperCase()})"
        : "";

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Future<void> send() async {
              final s = subject.trim();
              final b = body.trim();

              if (b.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Body is required")),
                );
                return;
              }

              setModalState(() => isSending = true);

              try {
                final payload = <String, String>{
                  "to": widget.profile.id,
                  "body": b,
                  "subject": s.isNotEmpty ? "$s $carTag" : "No subject $carTag",
                };

                final uri = Uri.parse(
                  "https://uconnecta-backend.onrender.com/api/email/send/",
                );

                final res = await http
                    .post(
                      uri,
                      headers: {
                        "Accept": "application/json",
                        "Content-Type": "application/json",
                      },
                      body: jsonEncode(payload),
                    )
                    .timeout(const Duration(seconds: 10));
                debugPrint(res.body.toString());

                if (res.statusCode < 200 || res.statusCode >= 300) {
                  throw Exception("Send failed: ${res.statusCode} ${res.body}");
                }

                if (!context.mounted) return;
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Expanded(child: Text('Message sended!')),
                      ],
                    ),
                    backgroundColor: KColors.goodColor,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text('Failed to send message (500 error)'),
                        ),
                      ],
                    ),
                    backgroundColor: KColors.badColor,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              } finally {
                if (ctx.mounted) setModalState(() => isSending = false);
              }
            }

            final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 14,
                bottom: bottomInset + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Send message",
                    style: KTextStyles.fontMediumBigStyle.copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    onChanged: (v) => subject = v,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      hintText: "Subject (optional)",
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    onChanged: (v) => body = v,
                    minLines: 4,
                    maxLines: 8,
                    decoration: InputDecoration(
                      hintText: "Message body *",
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isSending
                              ? null
                              : () => Navigator.of(ctx).pop(),
                          child: const Text("Cancel"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isSending ? null : send,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: KColors.thirdColor,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: isSending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : const Text("Send"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _blockUser(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Block user?'),
        content: const Text(
          'You will no longer be able to chat or call with this user.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Block'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await AppServices.chatApi.blockUser(widget.profile.id);

      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User blocked')));

      // опційно: повернутись назад
      Navigator.pop(context);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to block: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final double? rating = widget.profile.rating; // double?
    final hasRating = rating != null;

    final ratingLabel = hasRating
        ? (rating >= 4 ? "Very good!" : (rating >= 2 ? "Middle" : "Bad"))
        : "No rating yet";

    final ratingColor = hasRating
        ? (rating >= 4
              ? KColors.goodColor
              : (rating >= 2 ? KColors.mediumColor : KColors.badColor))
        : KColors.placeholderColor;

    final ratingTextColor = hasRating ? Colors.white : Colors.black;
    final currentUser = UserScope.of(context).value;
    final isLoggedIn = currentUser != null;
    return Scaffold(
      appBar: AppBar(
        title: Text("Driver's profile"),
        centerTitle: true,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: SvgPicture.asset(
            "assets/svgs/arrow_back.svg",
            width: 25,
            height: 14,
          ),
        ),
      ),
      body: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {
                if (!isPoliceExpanded) {
                  setState(() {
                    isPoliceExpanded = true;
                  });
                  return;
                }
                debugPrint("Police called");
                setState(() {
                  isPoliceExpanded = false;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: KColors.policeColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(999),
                    bottomLeft: Radius.circular(999),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.local_police,
                      size: 20,
                      color: Colors.white,
                    ),
                    ClipRect(
                      child: AnimatedAlign(
                        alignment: Alignment.centerLeft,
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeInOut,
                        widthFactor: isPoliceExpanded ? 1.0 : 0.0,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            "Complain",
                            style: KTextStyles.fontMediumStyle.copyWith(
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            softWrap: false,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: widget.profile.photo != null
                      ? NetworkImage(widget.profile.photo!)
                      : const AssetImage("assets/images/blank_avatar.png")
                            as ImageProvider,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: ratingColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgPicture.asset(
                        "assets/svgs/rating_icon.svg",
                        width: 18,
                        height: 18,
                        colorFilter: ColorFilter.mode(
                          Colors.yellow,
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        ratingLabel,
                        style: KTextStyles.fontMediumBigStyle.copyWith(
                          color: ratingTextColor,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (hasRating) ...[
                        const SizedBox(width: 10),
                        Text(
                          rating.toStringAsFixed(1),
                          style: KTextStyles.fontMediumBigStyle.copyWith(
                            color: ratingTextColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.profile.displayName == null
                      ? "Anonymous"
                      : widget.profile.displayName!,
                  style: KTextStyles.fontBigStyle.copyWith(color: Colors.black),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "@${widget.profile.username}",
                      textAlign: .center,
                      style: KTextStyles.fontSecondaryMedium.copyWith(
                        color: Colors.black,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(
                          ClipboardData(text: widget.profile.username),
                        );
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(
                              behavior: SnackBarBehavior.floating,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              elevation: 0,
                              backgroundColor: Color.fromRGBO(0, 0, 0, 0.85),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              duration: const Duration(milliseconds: 900),
                              content: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Username copied!',
                                      style: KTextStyles.fontMediumStyle
                                          .copyWith(color: Colors.white),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                      },
                      child: Icon(
                        Icons.copy,
                        size: 25,
                        color: KColors.mainColor,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: const Divider(color: KColors.secondaryColor),
                ),
                Text(
                  "Description",
                  style: KTextStyles.fontMediumBigStyle.copyWith(
                    color: KColors.darkenGreyColor,
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsGeometry.symmetric(horizontal: 12),
                  child: Text(
                    widget.profile.about == null ||
                            widget.profile.about!.isEmpty
                        ? "User haven't left description yet."
                        : widget.profile.about!,
                    style: KTextStyles.fontMediumBigStyle.copyWith(
                      fontWeight: .w300,
                    ),
                    textAlign: .center,
                  ),
                ),
                const SizedBox(height: 30),
                if (!isLoggedIn) ...[
                  Material(
                    color: KColors.thirdColor,
                    borderRadius: BorderRadius.circular(1000),
                    child: InkWell(
                      onTap: _openSendMessageModal,
                      borderRadius: BorderRadius.circular(1000),
                      splashColor: Colors.white38,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 10,
                        ),
                        child: Text(
                          "Send message",
                          style: KTextStyles.fontMediumBigStyle.copyWith(
                            color: Colors.black,
                            fontWeight: .bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  Material(
                    color: KColors.thirdColor,
                    borderRadius: BorderRadius.circular(1000),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ChatPage.otherUser(otherUser: widget.profile),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(1000),
                      splashColor: Colors.white38,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 10,
                        ),
                        child: Text(
                          "Start chat",
                          style: KTextStyles.fontMediumBigStyle.copyWith(
                            color: Colors.black,
                            fontWeight: .bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                isLoggedIn
                    ? Material(
                        color: KColors.badColor,
                        borderRadius: BorderRadius.circular(1000),
                        child: InkWell(
                          onTap: () => _blockUser(context),
                          borderRadius: BorderRadius.circular(1000),
                          splashColor: Colors.white38,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 10,
                            ),
                            child: Text(
                              "Block user",
                              style: KTextStyles.fontMediumBigStyle.copyWith(
                                color: Colors.white,
                                fontWeight: .bold,
                              ),
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
