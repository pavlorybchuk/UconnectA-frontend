import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uconnecta/components/search_field.dart';
import 'package:uconnecta/data/constrains.dart';
import 'package:uconnecta/data/notifiers.dart';
import 'package:uconnecta/pages/sign_up_in_page.dart';

class HomePageUnregistered extends StatefulWidget {
  const HomePageUnregistered({super.key});

  @override
  State<HomePageUnregistered> createState() => _HomePageUnregisteredState();
}

class _HomePageUnregisteredState extends State<HomePageUnregistered>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  late final AnimationController _slideAnim;

  bool _isFocused = false;
  DriverProfile? _foundProfile;

  @override
  void initState() {
    super.initState();

    _slideAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _focusNode.addListener(_onFocusChange);
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

  void _onProfileFound(DriverProfile? profile) {
    setState(() => _foundProfile = profile);
  }

  Future<void> _sendQuickMessage(QuickMsg msg) async {
    if (_foundProfile == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Confirm'),
        content: Text(
          'Do you want to send this message?:\n\n"${msg.body}"',
          style: KTextStyles.fontSmallStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: KColors.mainColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

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
              'to': _foundProfile!.id,
              'subject': msg.subject,
              'body': msg.body+_searchController.text,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (res.statusCode >= 200 && res.statusCode < 300) {
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
      } else {
        throw Exception('HTTP ${res.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sending error: $e'),
          backgroundColor: KColors.badColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _searchController.dispose();
    _slideAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isFocused, // дозволяти pop тільки якщо НЕ у фокусі
      onPopInvoked: (didPop) {
        if (didPop) return;

        // якщо back натиснули, але pop заблокований
        _focusNode.unfocus();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              AnimatedSwitcher(
                duration: Duration(milliseconds: 300),
                child: !_isFocused
                    ? Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'UconnectA',
                                style: KTextStyles.fontBigStyle.copyWith(
                                  color: KColors.mainColor,
                                ),
                              ),
                            ),
                            Material(
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
                                        style: KTextStyles.fontMediumStyle
                                            .copyWith(color: Colors.black),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(
                                        Icons.login,
                                        size: 24,
                                        color: Colors.black,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: Column(
                    children: [
                      AnimatedSwitcher(
                        duration: Duration(milliseconds: 300),
                        child: !_isFocused
                            ? Column(
                                children: [
                                  Text(
                                    'Who will we start the conversation with today?',
                                    style: KTextStyles.fontVeryBigStyle,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 40),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),

                      SearchInput(
                        controller: _searchController,
                        isOnMainPage: false,
                        focusNode: _focusNode,
                        onProfileFound: _onProfileFound,
                      ),
                      const SizedBox(height: 6),
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
                        child: _foundProfile != null && _isFocused
                            ? _buildQuickMessages()
                            : const SizedBox.shrink(),
                      ),
                      AnimatedSwitcher(
                        duration: Duration(milliseconds: 300),
                        child: !_isFocused
                            ? Column(
                                children: [
                                  const SizedBox(height: 16),
                                  _buildPromoCard(),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
              'Quick messages to driver:',
              style: KTextStyles.fontSmallStyle.copyWith(
                color: KColors.darkPlaceholderColor,
              ),
            ),
          ),
          ...List.generate(quickMessages.length, (i) {
            final msg = quickMessages[i];
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

// ─── Quick-message card widget ─────────────────────────────────────────────────

class _QuickMessageCard extends StatelessWidget {
  final QuickMsg msg;
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: KColors.mainColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(msg.icon, size: 14, color: KColors.mainColor),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  msg.body,
                  style: KTextStyles.fontSmallStyle.copyWith(
                    color: Colors.black87,
                  ),
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
