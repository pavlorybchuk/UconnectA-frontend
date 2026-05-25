import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:uconnecta/app_services.dart';
import 'package:uconnecta/data/constrains_&_utils.dart';
import 'package:uconnecta/pages/call_in_progress_page.dart';

/// Shown on the RECEIVER's device for an incoming call.
class CallPage extends StatelessWidget {
  final String callId;
  final String chatId;
  final DriverProfile fromUser;

  const CallPage({
    super.key,
    required this.callId,
    required this.chatId,
    required this.fromUser,
  });

  Future<void> _accept(BuildContext context) async {
    await AppServices.callController.accept(
      onRemoteStream: (_) {},
    );

    if (!context.mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CallInProgressPage(
          chatId: chatId,
          peer: fromUser,
        ),
      ),
    );
  }

  Future<void> _reject(BuildContext context) async {
    await AppServices.callController.reject();

    if (context.mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F172A),
                  Color(0xFF111827),
                  Color(0xFF1E293B),
                ],
              ),
            ),
          ),

          // Decorative glows
          Positioned(
            top: -60,
            left: -40,
            child: _GlowCircle(
              size: 240,
              color: Colors.greenAccent.withOpacity(0.16),
            ),
          ),

          Positioned(
            bottom: -90,
            right: -40,
            child: _GlowCircle(
              size: 280,
              color: Colors.blueAccent.withOpacity(0.16),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const Spacer(),

                  // Incoming label
                  ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: 18,
                        sigmaY: 18,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF4ADE80),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Incoming call',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 42),

                  // Avatar section
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 190,
                        height: 190,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color:
                                  Colors.greenAccent.withOpacity(0.20),
                              blurRadius: 55,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                      ),

                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.14),
                            width: 1.5,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 80,
                          backgroundColor: Colors.white12,
                          backgroundImage: fromUser.photoUrl != null
                              ? NetworkImage(fromUser.photoUrl!)
                              : null,
                          child: fromUser.photoUrl == null
                              ? const Icon(
                                  Icons.person_rounded,
                                  size: 80,
                                  color: Colors.white54,
                                )
                              : null,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 36),

                  // User name
                  Text(
                    fromUser.displayName ?? fromUser.username,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    'is calling you...',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 17,
                    ),
                  ),

                  const Spacer(),

                  // Bottom controls
                  ClipRRect(
                    borderRadius: BorderRadius.circular(34),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: 18,
                        sigmaY: 18,
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 26,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(34),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceEvenly,
                          children: [
                            _CallActionButton(
                              icon: Icons.call_end_rounded,
                              color: const Color(0xFFFF4D67),
                              label: 'Decline',
                              onTap: () => _reject(context),
                            ),

                            _CallActionButton(
                              icon: Icons.call_rounded,
                              color: const Color(0xFF22C55E),
                              label: 'Accept',
                              onTap: () => _accept(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CallActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _CallActionButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.45),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 36,
            ),
          ),
        ),

        const SizedBox(height: 12),

        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowCircle({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 80,
          sigmaY: 80,
        ),
        child: const SizedBox(),
      ),
    );
  }
}