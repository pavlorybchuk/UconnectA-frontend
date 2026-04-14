import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uconnecta/app_services.dart';
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

  @override
  void initState() {
    super.initState();
    _initRenderer();
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

  Future<void> _initRenderer() async {
    await _remoteRenderer.initialize();

    final stream = AppServices.callController.remoteStream;
    if (stream != null) {
      _remoteRenderer.srcObject = stream;
    }
  }

  @override
  void dispose() {
    _remoteRenderer.dispose();
    super.dispose();
  }

  Future<void> _hangup() async {
    await AppServices.callController.reject();

    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _toggleSpeaker() async {
    _speakerOn = !_speakerOn;
    await AppServices.callService.setSpeaker(_speakerOn);
    setState(() {});
  }

  void _toggleMute() {
    _muted = !_muted;
    AppServices.callService.setMuted(_muted);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hasVideo =
        _remoteRenderer.srcObject?.getVideoTracks().isNotEmpty == true;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // ---------- VIDEO / AVATAR ----------
            Positioned.fill(
              child: hasVideo
                  ? RTCVideoView(
                      _remoteRenderer,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    )
                  : _AudioOnlyView(peer: widget.peer),
            ),

            // ---------- TOP ----------
            Positioned(
              top: 24,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Text(
                    widget.peer.displayName ?? widget.peer.username,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ValueListenableBuilder<Duration>(
                    valueListenable:
                        AppServices.callController.callDurationListenable,
                    builder: (_, duration, __) {
                      return Text(
                        _format(duration),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "In call",
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),

            // ---------- CONTROLS ----------
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ControlButton(
                    icon: _muted ? Icons.mic_off : Icons.mic,
                    onTap: _toggleMute,
                  ),
                  FloatingActionButton(
                    backgroundColor: Colors.red,
                    onPressed: _hangup,
                    child: const Icon(Icons.call_end),
                  ),
                  _ControlButton(
                    icon: _speakerOn ? Icons.volume_up : Icons.volume_off,
                    onTap: _toggleSpeaker,
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

class _AudioOnlyView extends StatelessWidget {
  final DriverProfile peer;

  const _AudioOnlyView({required this.peer});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 56,
            backgroundImage: peer.photoUrl != null
                ? NetworkImage(peer.photoUrl!)
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            peer.displayName ?? peer.username,
            style: const TextStyle(color: Colors.white, fontSize: 20),
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ControlButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      backgroundColor: Colors.grey.shade900,
      onPressed: onTap,
      child: Icon(icon),
    );
  }
}
