import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:uconnecta/app_services.dart';
import 'package:uconnecta/data/call_controller.dart';
import 'package:uconnecta/data/constrains_&_utils.dart';
import 'package:uconnecta/pages/call_in_progress_page.dart';

class OutgoingCallPage extends StatefulWidget {
  final DriverProfile peer;

  const OutgoingCallPage({
    super.key,
    required this.peer,
  });

  @override
  State<OutgoingCallPage> createState() => _OutgoingCallPageState();
}

class _OutgoingCallPageState extends State<OutgoingCallPage> {
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    AppServices.callController.stateListenable.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    AppServices.callController.stateListenable.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (_navigating || !mounted) return;

    final s = AppServices.callController.state;

    if (s == CallState.inProgress) {
      _navigating = true;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CallInProgressPage(
            chatId: AppServices.callController.chatId ?? '',
            peer: widget.peer,
          ),
        ),
      );
    } else if (s == CallState.idle) {
      _navigating = true;
      Navigator.of(context).pop();
    }
  }

  Future<void> _cancel() async {
    if (_navigating) return;

    _navigating = true;

    await AppServices.callController.end();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final peer = widget.peer;

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
                  Color(0xFF1E293B),
                  Color(0xFF111827),
                ],
              ),
            ),
          ),

          // Decorative blur circles
          Positioned(
            top: -60,
            left: -40,
            child: _GlowCircle(
              size: 220,
              color: Colors.blueAccent.withOpacity(0.18),
            ),
          ),

          Positioned(
            bottom: -80,
            right: -40,
            child: _GlowCircle(
              size: 260,
              color: Colors.deepPurpleAccent.withOpacity(0.18),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const Spacer(),

                  // Avatar with glow
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 170,
                        height: 170,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blueAccent.withOpacity(0.25),
                              blurRadius: 50,
                              spreadRadius: 8,
                            ),
                          ],
                        ),
                      ),

                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.15),
                            width: 1.5,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 72,
                          backgroundColor: Colors.white12,
                          backgroundImage: peer.photoUrl != null
                              ? NetworkImage(peer.photoUrl!)
                              : null,
                          child: peer.photoUrl == null
                              ? const Icon(
                                  Icons.person_rounded,
                                  size: 72,
                                  color: Colors.white54,
                                )
                              : null,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 36),

                  // Name
                  Text(
                    peer.displayName ?? peer.username,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Ringing label
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.08),
                      ),
                    ),
                    child: const _RingingLabel(),
                  ),

                  const Spacer(),

                  // Bottom glass controls
                  ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: 18,
                        sigmaY: 18,
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 28,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Calling...',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),

                            const SizedBox(height: 24),

                            GestureDetector(
                              onTap: _cancel,
                              child: Container(
                                width: 76,
                                height: 76,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFFFF4D67),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFFFF4D67,
                                      ).withOpacity(0.45),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.call_end_rounded,
                                  color: Colors.white,
                                  size: 34,
                                ),
                              ),
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

class _RingingLabel extends StatefulWidget {
  const _RingingLabel();

  @override
  State<_RingingLabel> createState() => _RingingLabelState();
}

class _RingingLabelState extends State<_RingingLabel> {
  int _dots = 0;
  late final StreamSubscription _sub;

  @override
  void initState() {
    super.initState();

    _sub = Stream.periodic(
      const Duration(milliseconds: 600),
    ).listen((_) {
      if (mounted) {
        setState(() => _dots = (_dots + 1) % 4);
      }
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      'Ringing${'.' * _dots}',
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
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