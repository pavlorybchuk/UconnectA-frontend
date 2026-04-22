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
    await AppServices.callController.accept(onRemoteStream: (_) {});

    if (!context.mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CallInProgressPage(chatId: chatId, peer: fromUser),
      ),
    );
  }

  Future<void> _reject(BuildContext context) async {
    await AppServices.callController.reject();
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 56,
              backgroundImage: fromUser.photoUrl != null
                  ? NetworkImage(fromUser.photoUrl!)
                  : null,
              child: fromUser.photoUrl == null
                  ? const Icon(Icons.person, size: 56, color: Colors.white54)
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              fromUser.displayName ?? fromUser.username,
              style: const TextStyle(color: Colors.white, fontSize: 20),
            ),
            const SizedBox(height: 8),
            const Text(
              'Incoming call…',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    FloatingActionButton(
                      backgroundColor: Colors.green,
                      onPressed: () => _accept(context),
                      child: const Icon(Icons.call),
                    ),
                    const SizedBox(height: 8),
                    const Text('Accept',
                        style: TextStyle(color: Colors.white70)),
                  ],
                ),
                Column(
                  children: [
                    FloatingActionButton(
                      backgroundColor: Colors.red,
                      onPressed: () => _reject(context),
                      child: const Icon(Icons.call_end),
                    ),
                    const SizedBox(height: 8),
                    const Text('Reject',
                        style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}