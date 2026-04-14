import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:uconnecta/auth/user_scope.dart';
import 'package:uconnecta/data/navigation_service.dart';
import 'package:uconnecta/pages/call_page.dart';
import 'package:uconnecta/pages/chat_page.dart';
import "./data/notifiers.dart";
import 'auth/auth_gate.dart';
import "data/constrains_&_utils.dart";
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

void handlePushNavigation(RemoteMessage message) {
  final data = message.data;
  final type = data['type'];

  if (type == "call.incoming") {
    final fromUser = DriverProfile.fromJson(jsonDecode(data["from_user"]));

    NavigationService.navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => CallPage(
          callId: data["call_id"],
          chatId: data["chat_id"],
          fromUser: fromUser,
        ),
      ),
    );
  }

  if (type == 'message.created') {
    final chatId = data['chat_id'];

    if (ChatNavigationTracker.currentChatId == chatId) {
      return;
    }

    NavigationService.pushNamed('/chat', arguments: {'chatId': chatId});
  }

  if (type == 'incoming_call') {
    NavigationService.pushNamed(
      '/call',
      arguments: {'callId': data['call_id']},
    );
  }
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  FirebaseMessaging.onMessageOpenedApp.listen(handlePushNavigation);

  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    handlePushNavigation(initialMessage);
  }

  final userStore = UserStore();
  runApp(UserScope(store: userStore, child: const UconnectA()));
}

class UconnectA extends StatelessWidget {
  const UconnectA({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: NavigationService.navigatorKey,
      onGenerateRoute: (settings) {
        if (settings.name == '/chat') {
          final args = settings.arguments as Map<String, dynamic>;
          final chatId = args['chatId'] as String;

          return MaterialPageRoute(
            builder: (_) => ChatPage.byId(chatId: chatId),
          );
        }

        if (settings.name == '/call') {
          final args = settings.arguments as Map<String, dynamic>;
          final callId = args['callId'] as String;

          return MaterialPageRoute(
            builder: (_) => Center(child: Text("Calling $callId")),
          );
        }

        return MaterialPageRoute(builder: (_) => const AuthGate());
      },
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'InriaSans',
        colorScheme: ColorScheme.fromSeed(seedColor: KColors.mainColor),
      ),
      home: const AuthGate(),
    );
  }
}
