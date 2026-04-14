import 'package:flutter/material.dart';
import 'package:uconnecta/app_services.dart';
import 'package:uconnecta/data/constrains_&_utils.dart';
import 'package:uconnecta/pages/call_in_progress_page.dart';

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
    final controller = AppServices.callController;

    await controller.accept(onRemoteStream: (_) {});

    if (!context.mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CallInProgressPage(chatId: chatId, peer: fromUser),
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
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 48,
              backgroundImage: fromUser.photoUrl != null
                  ? NetworkImage(fromUser.photoUrl!)
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
                FloatingActionButton(
                  backgroundColor: Colors.green,
                  onPressed: () => _accept(context),
                  child: const Icon(Icons.call),
                ),
                FloatingActionButton(
                  backgroundColor: Colors.red,
                  onPressed: () => _reject(context),
                  child: const Icon(Icons.call_end),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
