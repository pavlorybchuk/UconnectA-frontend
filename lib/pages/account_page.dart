import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:uconnecta/app_services.dart';
import 'package:uconnecta/auth/current_user.dart';

import '../auth/user_scope.dart';
import '../data/constrains.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  bool _showEmailHint = true;
  String? _profileStr(Map<String, dynamic> p, String key) {
    final v = p[key];
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  Future<void> _editField({
    required String title,
    required String initialValue,
    required String hint,
    required Future<void> Function(String value) onSave,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) async {
    final c = TextEditingController(text: initialValue);
    bool saving = false;

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
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: saving
                            ? null
                            : () async {
                                final v = c.text.trim();
                                if (v.isEmpty) return;

                                setModalState(() => saving = true);
                                try {
                                  await onSave(v);
                                  if (!mounted) return;
                                  Navigator.pop(ctx);
                                } catch (e) {
                                  setModalState(() => saving = false);
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.toString())),
                                  );
                                }
                              },
                        icon: saving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: c,
                    keyboardType: keyboardType,
                    maxLines: maxLines,
                    decoration: InputDecoration(
                      hintText: hint,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveMePatch(Map<String, dynamic> data) async {
    // важливо: у тебе ApiClient вже має patch(...)
    final r = await AppServices.apiClient.patch("/api/me/", data: data);

    // Після PATCH онови UserStore з відповіді (якщо /api/me/ повертає актуального юзера)
    final updated = CurrentUser.fromJson(r.data);
    UserScope.of(context).value = updated; // якщо в тебе так оновлюється
    // якщо в тебе store.setUser(updated) — використовуй його
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final me = UserScope.of(context).value;
    if (me == null) {
      return const Scaffold(body: Center(child: Text("Not authorized")));
    }

    final p = me.profile;
    final displayName = (me.howToAddress?.trim().isNotEmpty == true)
        ? me.howToAddress!.trim()
        : "Anonymous";

    final username = me.username;
    final email = me.email;
    final phone = me.phone;

    final about = _profileStr(p, "about") ?? "";
    final photo = _profileStr(p, "photo"); // може бути абсолютний URL або шлях

    final double? rating = me.rating; // double?
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

    ImageProvider avatarProvider() {
      if (photo != null && photo.isNotEmpty) {
        // Якщо твій бек віддає відносний шлях — зроби тут збірку з Api.baseUrl (як у DriverProfile)
        final url = photo.startsWith("http") ? photo : photo;
        return NetworkImage(url);
      }
      return const AssetImage("assets/images/blank_avatar.png");
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
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
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: KColors.mainColor),
            onPressed: () {
              // TODO: відкрити сторінку редагування
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("TODO: Edit profile")),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: KColors.mainColor),
            onPressed: () {
              // TODO: меню
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                ),
                builder: (_) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      ListTile(
                        leading: const Icon(Icons.logout),
                        title: const Text("Logout"),
                        onTap: () {
                          Navigator.pop(context);
                          // TODO
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          children: [
            const SizedBox(height: 6),

            // Avatar
            CircleAvatar(
              radius: 54,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: avatarProvider(),
            ),

            const SizedBox(height: 12),

            // Rating pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                      ratingTextColor,
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

            const SizedBox(height: 10),

            // Name
            Text(
              displayName,
              style: KTextStyles.fontBigStyle.copyWith(
                color: Colors.black,
                height: 1,
              ),
            ),

            // @username + copy
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "@$username",
                  textAlign: .center,
                  style: KTextStyles.fontSecondaryMedium.copyWith(
                    color: Colors.black,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 8.0),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: username));
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
                                  style: KTextStyles.fontMediumStyle.copyWith(
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                  },
                  child: Icon(Icons.copy, size: 25, color: KColors.mainColor),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Your data section
            Container(
              width: double.infinity,
              color: KColors.lightBackgroundColor,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      "Your data",
                      style: KTextStyles.fontMediumBigStyle.copyWith(
                        color: Colors.black38,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _GoEditRow(
                        title: email,
                        subtitle: "Email",
                        onTap: () => _editField(
                          title: "Change email",
                          initialValue: email,
                          hint: "example@gmail.com",
                          keyboardType: TextInputType.emailAddress,
                          onSave: (v) => _saveMePatch({"email": v}),
                        ),
                      ),

                      if (_showEmailHint)
                        Positioned(
                          top: -25,
                          left: 0,
                          right: 0,
                          child: _HintBubble(
                            text: "Tap on the title to change data",
                            onClose: () =>
                                setState(() => _showEmailHint = false),
                          ),
                        ),
                    ],
                  ),
                  _GoEditRow(
                    title: phone,
                    subtitle: "Phone number",
                    onTap: () => _editField(
                      title: "Change phone",
                      initialValue: phone,
                      hint: "+380...",
                      keyboardType: TextInputType.phone,
                      onSave: (v) => _saveMePatch({"phone": v}),
                    ),
                  ),

                  Row(
                    spacing: 10,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _GoEditRow(
                          title: displayName,
                          subtitle: "Nickname",
                          onTap: () => _editField(
                            title: "Change nickname",
                            initialValue: displayName == "Anonymous"
                                ? ""
                                : displayName,
                            hint: "Your nickname",
                            onSave: (v) => _saveMePatch({"how_to_address": v}),
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          // TODO: change visibility / show_nickname
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("TODO: Change visibility"),
                            ),
                          );
                        },
                        icon: const Icon(Icons.open_in_new, size: 22),
                        label: const Text("Change visibility"),
                        style: TextButton.styleFrom(
                          foregroundColor: Color(0xFF00B7FF),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.center,
                      child: Text(
                        "About",
                        style: KTextStyles.fontMediumStyle.copyWith(
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: InkWell(
                      onTap: () => _editField(
                        title: "Change about",
                        initialValue: about,
                        hint: "Tell something about yourself...",
                        keyboardType: TextInputType.multiline,
                        maxLines: 6,
                        onSave: (v) => _saveMePatch({
                          "profile": {"about": v},
                        }),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          about.isEmpty
                              ? "You haven't left any description yet."
                              : about,
                          style: KTextStyles.fontMediumStyle.copyWith(
                            color: Colors.black87,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 23),

            // Your cars
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Your cars",
                  style: KTextStyles.fontMediumBigStyle.copyWith(
                    color: Colors.black54,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  for (final car in me.cars) ...[
                    _CarChip(
                      plate: car,
                      onRemove: () {
                        // TODO: remove car API
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("TODO: remove $car")),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                  ],

                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () async {
                      // TODO: додати через діалог + API
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("TODO: Add car")),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add, color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Text(
                            "Add",
                            style: KTextStyles.fontMediumStyle.copyWith(
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CarChip extends StatelessWidget {
  final String plate;
  final VoidCallback onRemove;

  const _CarChip({required this.plate, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: KColors.secondaryColor.withOpacity(0.55),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              plate,
              style: KTextStyles.fontMediumStyle.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onRemove,
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.close, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoEditRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _GoEditRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.black38),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.edit_outlined,
              size: 22,
              color: KColors.darkPlaceholderColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _HintBubble extends StatelessWidget {
  final String text;
  final VoidCallback onClose;

  const _HintBubble({required this.text, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
          bottomLeft: Radius.circular(0),
          bottomRight: Radius.circular(12),
        ),
        color: KColors.thirdColor,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: KColors.thirdColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  text,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: onClose,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: const Icon(
                    Icons.close,
                    size: 18,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
