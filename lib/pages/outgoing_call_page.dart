import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uconnecta/app_services.dart';
import 'package:uconnecta/data/call_controller.dart';
import 'package:uconnecta/data/constrains_&_utils.dart';
import 'package:uconnecta/pages/call_in_progress_page.dart';

class OutgoingCallPage extends StatefulWidget {
  final DriverProfile peer;
  const OutgoingCallPage({super.key, required this.peer});

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
      // Callee accepted — move to the in-progress screen.
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
      // Call was rejected / cancelled.
      _navigating = true;
      Navigator.of(context).pop();
    }
  }

  Future<void> _cancel() async {
    if (_navigating) return;
    _navigating = true;
    await AppServices.callController.end();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final peer = widget.peer;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 56,
              backgroundImage: peer.photoUrl != null
                  ? NetworkImage(peer.photoUrl!)
                  : null,
              child: peer.photoUrl == null
                  ? const Icon(Icons.person, size: 56, color: Colors.white54)
                  : null,
            ),
            const SizedBox(height: 20),
            Text(
              peer.displayName ?? peer.username,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const _RingingLabel(),
            const SizedBox(height: 60),
            FloatingActionButton(
              backgroundColor: Colors.red,
              onPressed: _cancel,
              child: const Icon(Icons.call_end),
            ),
          ],
        ),
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
    _sub = Stream.periodic(const Duration(milliseconds: 600)).listen((_) {
      if (mounted) setState(() => _dots = (_dots + 1) % 4);
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
      style: const TextStyle(color: Colors.white70, fontSize: 16),
    );
  }
}