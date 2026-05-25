import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uconnecta/app_services.dart';
import 'package:uconnecta/data/call_controller.dart';
import 'package:uconnecta/data/constrains_&_utils.dart';

class CallInProgressPage extends StatefulWidget {
  final String chatId;
  final DriverProfile peer;

  const CallInProgressPage({
    super.key,
    required this.chatId,
    required this.peer,
  });

  @override
  State<CallInProgressPage> createState() => _CallInProgressPageState();
}

class _CallInProgressPageState extends State<CallInProgressPage> {
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  bool _speakerOn = true;
  bool _muted = false;
  bool _popping = false;

  @override
  void initState() {
    super.initState();

    _initRenderer();

    AppServices.callController.stateListenable.addListener(_onStateChanged);

    AppServices.callController.remoteStreamNotifier
        .addListener(_onRemoteStream);
  }

  @override
  void dispose() {
    AppServices.callController.stateListenable.removeListener(_onStateChanged);

    AppServices.callController.remoteStreamNotifier
        .removeListener(_onRemoteStream);

    _remoteRenderer.dispose();

    super.dispose();
  }

  Future<void> _initRenderer() async {
    await _remoteRenderer.initialize();

    final stream = AppServices.callController.remoteStream;

    if (stream != null && mounted) {
      setState(() => _remoteRenderer.srcObject = stream);
    }
  }

  void _onRemoteStream() {
    final stream = AppServices.callController.remoteStream;

    if (stream != null && mounted) {
      setState(() => _remoteRenderer.srcObject = stream);
    }
  }

  void _onStateChanged() {
    if (AppServices.callController.state == CallState.idle &&
        mounted &&
        !_popping) {
      _popping = true;
      Navigator.of(context).pop();
    }
  }

  String _format(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);

    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:'
          '${m.toString().padLeft(2, '0')}:'
          '${s.toString().padLeft(2, '0')}';
    }

    return '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  Future<void> _hangup() async {
    if (_popping) return;

    _popping = true;

    await AppServices.callController.end();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _toggleSpeaker() async {
    _speakerOn = !_speakerOn;

    await AppServices.callService.setSpeaker(_speakerOn);

    if (mounted) {
      setState(() {});
    }
  }

  void _toggleMute() {
    _muted = !_muted;

    AppServices.callService.setMuted(_muted);

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasVideo =
        _remoteRenderer.srcObject?.getVideoTracks().isNotEmpty == true;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          Positioned.fill(
            child: hasVideo
                ? RTCVideoView(
                    _remoteRenderer,
                    objectFit:
                        RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  )
                : _AudioOnlyView(peer: widget.peer),
          ),

          // Dark overlay for readability
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.55),
                    Colors.transparent,
                    Colors.black.withOpacity(0.75),
                  ],
                ),
              ),
            ),
          ),

          // Top info
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: 18,
                        sigmaY: 18,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 18,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              widget.peer.displayName ??
                                  widget.peer.username,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),

                            const SizedBox(height: 10),

                            ValueListenableBuilder<Duration>(
                              valueListenable: AppServices
                                  .callController
                                  .callDurationListenable,
                              builder: (_, duration, __) => Text(
                                _format(duration),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),

                            const SizedBox(height: 6),

                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
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
                                  'In call',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 22,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(34),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceEvenly,
                          children: [
                            _ControlButton(
                              icon: _muted
                                  ? Icons.mic_off_rounded
                                  : Icons.mic_rounded,
                              isActive: _muted,
                              onTap: _toggleMute,
                            ),

                            _HangupButton(
                              onTap: _hangup,
                            ),

                            _ControlButton(
                              icon: _speakerOn
                                  ? Icons.volume_up_rounded
                                  : Icons.volume_off_rounded,
                              isActive: !_speakerOn,
                              onTap: _toggleSpeaker,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AudioOnlyView extends StatelessWidget {
  final DriverProfile peer;

  const _AudioOnlyView({
    required this.peer,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Gradient background
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

        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Avatar glow
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blueAccent.withOpacity(0.25),
                          blurRadius: 50,
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
                        color: Colors.white.withOpacity(0.15),
                        width: 1.5,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 76,
                      backgroundColor: Colors.white12,
                      backgroundImage: peer.photoUrl != null
                          ? NetworkImage(peer.photoUrl!)
                          : null,
                      child: peer.photoUrl == null
                          ? const Icon(
                              Icons.person_rounded,
                              size: 76,
                              color: Colors.white54,
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;

  const _ControlButton({
    required this.icon,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 66,
        height: 66,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive
              ? Colors.white.withOpacity(0.18)
              : Colors.white.withOpacity(0.10),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
          ),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }
}

class _HangupButton extends StatelessWidget {
  final VoidCallback onTap;

  const _HangupButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 78,
        height: 78,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFFF4D67),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF4D67).withOpacity(0.45),
              blurRadius: 24,
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