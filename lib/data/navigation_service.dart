import 'package:flutter/material.dart';

class NavigationService {
  static final navigatorKey = GlobalKey<NavigatorState>();

  static Future<dynamic>? pushNamed(String route, {Object? arguments}) {
    return navigatorKey.currentState?.pushNamed(route, arguments: arguments);
  }
}

class ChatNavigationTracker {
  static String? currentChatId;
}
