import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uconnecta/data/constrains.dart';
import 'package:uconnecta/data/notifiers.dart';
import 'package:uconnecta/pages/sign_up_in_page.dart';

// ─── Quick-message definitions ───────────────────────────────────────────────

class _QuickMsg {
  final String body;
  final String subject; // used as email subject / category label
  final IconData icon;

  const _QuickMsg({
    required this.body,
    required this.subject,
    required this.icon,
  });
}

const List<_QuickMsg> _quickMessages = [
  _QuickMsg(
    body: 'Your car is obstructing traffic.',
    subject: 'Bad parking',
    icon: Icons.no_transfer,
  ),
  _QuickMsg(
    body: 'Your car blocked the exit.',
    subject: 'Bad parking',
    icon: Icons.block,
  ),
  _QuickMsg(
    body: 'Your car was in an accident.',
    subject: 'Car accident',
    icon: Icons.car_crash,
  ),
  _QuickMsg(
    body: 'I need your help, please come quickly.',
    subject: 'Emergency',
    icon: Icons.emergency,
  ),
  _QuickMsg(
    body: 'Your car is damaged.',
    subject: 'Damaged car',
    icon: Icons.build,
  ),
];

// ─── Page ────────────────────────────────────────────────────────────────────

class HomePageUnregistered extends StatefulWidget {
  const HomePageUnregistered({super.key});

  @override
  State<HomePageUnregistered> createState() => _HomePageUnregisteredState();
}

class _HomePageUnregisteredState extends State<HomePageUnregistered>
    with SingleTickerProviderStateMixin {
  final TextEditingController _carNumberController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  // Animation for the field sliding up
  late final AnimationController _slideAnim;
  late final Animation<Offset> _slideOffset;

  bool _isFocused = false;
  bool _isSearching = false;

  // Loaded profile (id is enough to send the email)
  String? _profileId;
  String? _profileError;

  // ── regex ──
  static final RegExp _carRegex = RegExp(r'^[A-Za-z]{2}\d{4}[A-Za-z]{2}$');

  @override
  void initState() {
    super.initState();

    _slideAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _slideOffset = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -0.08),
    ).animate(CurvedAnimation(parent: _slideAnim, curve: Curves.easeOut));

    _focusNode.addListener(_onFocusChange);
    _carNumberController.addListener(_onTextChanged);
  }

  void _onFocusChange() {
    final focused = _focusNode.hasFocus;
    setState(() => _isFocused = focused);
    if (focused) {
      _slideAnim.forward();
    } else {
      _slideAnim.reverse();
    }
  }

  void _onTextChanged() {
    final text = _carNumberController.text;

    // Only search for plain car numbers (not @username)
    if (!text.startsWith('@') && text.length == 8 && _carRegex.hasMatch(text)) {
      _searchDriver(text);
    } else {
      // Reset results when text changes
      if (_profileId != null || _profileError != null) {
        setState(() {
          _profileId = null;
          _profileError = null;
        });
      }
    }
  }

  Future<void> _searchDriver(String carNumber) async {
    if (_isSearching) return;
    setState(() {
      _isSearching = true;
      _profileId = null;
      _profileError = null;
    });

    try {
      final uri = Uri.parse(
        'https://uconnecta-backend.onrender.com/api/users/search/',
      ).replace(queryParameters: {'car_number': carNumber.toUpperCase()});

      final res = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 404) {
        setState(() => _profileError = 'Водія не знайдено');
        return;
      }
      if (res.statusCode != 200) {
        setState(() => _profileError = 'Помилка сервера');
        return;
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final id = (data['id'] ?? '').toString();
      if (id.isEmpty) {
        setState(() => _profileError = 'Профіль не знайдено');
        return;
      }
      setState(() => _profileId = id);
    } catch (_) {
      setState(() => _profileError = 'Немає зʼєднання');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  // ── send email ──────────────────────────────────────────────────────────────

  Future<void> _sendQuickMessage(_QuickMsg msg) async {
    if (_profileId == null) return;

    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Підтвердження'),
        content: Text(
          'Надіслати повідомлення:\n\n"${msg.body}"',
          style: KTextStyles.fontSmallStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Скасувати'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: KColors.mainColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Надіслати'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Send request
    try {
      final uri = Uri.parse(
        'https://uconnecta-backend.onrender.com/api/email/send/',
      );
      final res = await http
          .post(
            uri,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'to': _profileId,
              'subject': msg.subject,
              'body': msg.body,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (res.statusCode >= 200 && res.statusCode < 300) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Expanded(child: Text('Повідомлення успішно надіслано!')),
              ],
            ),
            backgroundColor: KColors.goodColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      } else {
        throw Exception('HTTP ${res.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Помилка надсилання: $e'),
          backgroundColor: KColors.badColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  // ── dispose ─────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _carNumberController.removeListener(_onTextChanged);
    _focusNode.dispose();
    _carNumberController.dispose();
    _slideAnim.dispose();
    super.dispose();
  }

  // ── build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'UconnectA',
          style: KTextStyles.fontBigStyle.copyWith(color: KColors.mainColor),
        ),
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22.0),
            child: Material(
              color: KColors.thirdColor,
              borderRadius: BorderRadius.circular(1000),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) {
                        signUpInTabsNotifier.value = 1;
                        return SignUpInPage();
                      },
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(1000),
                splashColor: KColors.thirdColorHover,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Sign in',
                        style: KTextStyles.fontMediumStyle.copyWith(
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.login, size: 24, color: Colors.black),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── blurred background when focused ────────────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            child: _isFocused
                ? GestureDetector(
                    key: const ValueKey('blur'),
                    onTap: () => _focusNode.unfocus(),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                      child: Container(color: Colors.black.withOpacity(0.15)),
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // ── main content ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            child: Center(
              child: Column(
                children: [
                  Text(
                    'Who will we start the conversation with today?',
                    style: KTextStyles.fontVeryBigStyle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  // ── animated search field ──────────────────────────────────
                  SlideTransition(
                    position: _slideOffset,
                    child: _buildSearchField(),
                  ),

                  const SizedBox(height: 16),

                  // ── quick-message cards ────────────────────────────────────
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.05),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    ),
                    child: _profileId != null
                        ? _buildQuickMessages()
                        : _buildPromoCard(),
                  ),
                ],
              ),
            ),
          ),

          // ── copyright footer ───────────────────────────────────────────────
          Positioned(
            right: 0,
            left: 0,
            bottom: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                '© All rights reserved',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: KColors.darkPlaceholderColor,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── search field widget ────────────────────────────────────────────────────

  Widget _buildSearchField() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: TextField(
        controller: _carNumberController,
        focusNode: _focusNode,
        maxLength: 8,
        buildCounter: (_, {required currentLength, required isFocused, required maxLength}) => null,
        textCapitalization: TextCapitalization.characters,
        cursorColor: Colors.white,
        decoration: InputDecoration(
          hintText: 'Search: XX1234XX',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: KColors.mainColor, width: 2),
            borderRadius: BorderRadius.circular(999),
          ),
          hintStyle: KTextStyles.fontSmallStyle.copyWith(
            color: KColors.thirdColor,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          filled: true,
          fillColor: KColors.mainColor,
          prefixIcon: _isSearching
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: KColors.thirdColorHover,
                    ),
                  ),
                )
              : const Icon(Icons.search, color: KColors.thirdColor, size: 22),
          suffixIcon: _carNumberController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 18, color: KColors.thirdColor),
                  onPressed: () {
                    _carNumberController.clear();
                    setState(() {
                      _profileId = null;
                      _profileError = null;
                    });
                  },
                )
              : null,
        ),
        style: KTextStyles.fontSmallStyle.copyWith(
          color: KColors.thirdColorHover,
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  // ── quick-message cards ────────────────────────────────────────────────────

  Widget _buildQuickMessages() {
    return ConstrainedBox(
      key: const ValueKey('quick'),
      constraints: const BoxConstraints(maxWidth: 600),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Швидке повідомлення водієві:',
              style: KTextStyles.fontSmallStyle.copyWith(
                color: KColors.darkPlaceholderColor,
              ),
            ),
          ),
          ...List.generate(_quickMessages.length, (i) {
            final msg = _quickMessages[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _QuickMessageCard(
                msg: msg,
                onTap: () => _sendQuickMessage(msg),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── promo card (default state) ─────────────────────────────────────────────

  Widget _buildPromoCard() {
    return Container(
      key: const ValueKey('promo'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 22),
      constraints: const BoxConstraints(maxWidth: 600.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: KColors.mainGradient,
      ),
      child: Column(
        children: [
          Text(
            'Get more out of UconnectA!',
            style: KTextStyles.fontMediumStyle.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '- Communication through chats and calls',
                  softWrap: true,
                  style: KTextStyles.fontSmallestStyle.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                '- Maintaining a profile',
                style: KTextStyles.fontSmallestStyle.copyWith(
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '- Ability to block users',
                style: KTextStyles.fontSmallestStyle.copyWith(
                  color: Colors.white,
                ),
              ),
              Text(
                '- Customizing your app',
                style: KTextStyles.fontSmallestStyle.copyWith(
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Material(
            color: KColors.thirdColorHover,
            borderRadius: BorderRadius.circular(1000),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) {
                      signUpInTabsNotifier.value = 0;
                      return SignUpInPage();
                    },
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
                  'Sign up now!',
                  style: KTextStyles.fontSmallStyle.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Quick-message card widget ────────────────────────────────────────────────

class _QuickMessageCard extends StatelessWidget {
  final _QuickMsg msg;
  final VoidCallback onTap;

  const _QuickMessageCard({required this.msg, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: KColors.thirdColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: KColors.mainColor.withOpacity(0.15),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: KColors.mainColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(msg.icon, size: 20, color: KColors.mainColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      msg.body,
                      style: KTextStyles.fontSmallStyle.copyWith(
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      msg.subject,
                      style: KTextStyles.fontSmallestStyle.copyWith(
                        color: KColors.darkPlaceholderColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.send_rounded,
                size: 18,
                color: KColors.mainColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}