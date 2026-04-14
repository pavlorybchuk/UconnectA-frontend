import 'package:flutter/material.dart';
import 'package:uconnecta/data/constrains_&_utils.dart';

class ChatStore extends ChangeNotifier {
  final Map<String, ChatListItem> _chats = {};

  List<ChatListItem> get all => _chats.values.toList();

  ChatListItem? getById(String id) => _chats[id];

  void setChats(List<ChatListItem> list) {
    _chats.clear();
    for (final c in list) {
      _chats[c.id] = c;
    }
    notifyListeners();
  }

  void upsert(ChatListItem chat) {
    _chats[chat.id] = chat;
    notifyListeners();
  }

  void remove(String id) {
    _chats.remove(id);
    notifyListeners();
  }

  void clear() {
    _chats.clear();
  }
}
