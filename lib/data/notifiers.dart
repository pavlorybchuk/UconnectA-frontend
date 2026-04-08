import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:uconnecta/data/constrains.dart';
import '../auth/current_user.dart';

ValueNotifier<int> signUpInTabsNotifier = ValueNotifier(0);

class UserStore extends ValueNotifier<CurrentUser?> {
  UserStore() : super(null);

  bool get isLoggedIn => value != null;

  void setUser(CurrentUser user) => value = user;

  void clear() => value = null;
}

ValueNotifier countryNotifier = ValueNotifier(countries.first);
