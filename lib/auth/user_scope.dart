import 'package:flutter/widgets.dart';
import '../data/notifiers.dart';

class UserScope extends InheritedNotifier<UserStore> {
  const UserScope({super.key, required UserStore store, required Widget child})
    : super(notifier: store, child: child);

  static UserStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<UserScope>();
    assert(scope != null, 'UserScope not found in widget tree');
    return scope!.notifier!;
  }
}
