import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uconnecta/app_services.dart';
import 'package:uconnecta/auth/current_user.dart';
import 'package:uconnecta/auth/user_scope.dart';
import 'package:uconnecta/data/notifiers.dart';
import 'package:uconnecta/pages/home_page.dart';
import 'package:uconnecta/pages/home_page_unregistered.dart';
import 'package:uconnecta/pages/sign_up_in_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _GateResult {
  final bool loggedIn;
  final bool showUnregisteredOnce;

  const _GateResult({
    required this.loggedIn,
    required this.showUnregisteredOnce,
  });
}

class _AuthGateState extends State<AuthGate> {
  late Future<_GateResult> _future;
  bool _inited = false;

  Future<bool> _tryAutoLogin(UserStore userStore) async {
    final auth = AppServices.auth;
    final storage = AppServices.tokenStorage;

    final refresh = await storage.readRefresh();
    if (refresh == null || refresh.isEmpty) return false;

    try {
      final data = await auth.me();
      final fcmToken = await FirebaseMessaging.instance.getToken();
      print("FCM TOKEN: $fcmToken");

      // відправити на сервер
      await AppServices.auth.saveFcmToken(fcmToken!);
      userStore.setUser(CurrentUser.fromJson(data));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _consumeFirstLaunchFlag() async {
    final prefs = await SharedPreferences.getInstance();
    final first = prefs.getBool("first_launch") ?? true;

    if (first) {
      // “споживаємо” перший запуск: показали unregistered → більше не показуємо
      await prefs.setBool("first_launch", false);
      return true;
    }
    return false;
  }

  Future<_GateResult> _boot(UserStore userStore) async {
    // 1) пробуємо авто-логін (твоя логіка)
    final ok = await _tryAutoLogin(userStore);
    if (ok && userStore.value != null) {
      return const _GateResult(loggedIn: true, showUnregisteredOnce: false);
    }

    // 2) якщо не залогінений — вирішуємо, чи це перший запуск
    final firstLaunch = await _consumeFirstLaunchFlag();
    return _GateResult(loggedIn: false, showUnregisteredOnce: firstLaunch);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inited) return;
    _inited = true;

    final store = UserScope.of(context);
    _future = _boot(store);
  }

  @override
  Widget build(BuildContext context) {
    final userStore = UserScope.of(context);

    return FutureBuilder<_GateResult>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final res = snapshot.data;

        if (res?.loggedIn == true && userStore.value != null) {
          return const HomePage();
        }

        if (res?.showUnregisteredOnce == true) {
          return const HomePageUnregistered();
        }

        signUpInTabsNotifier.value = 0;
        return const SignUpInPage();
      },
    );
  }
}
