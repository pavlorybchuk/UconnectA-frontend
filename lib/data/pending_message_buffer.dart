import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// A lightweight entry stored in SharedPreferences for each optimistic message.
class PendingBufferEntry {
  final String localId;
  final String chatId;
  final String senderId;
  final String senderUsername;
  final String? body;
  final String? localImagePath;
  final DateTime createdAt;

  PendingBufferEntry({
    required this.localId,
    required this.chatId,
    required this.senderId,
    required this.senderUsername,
    this.body,
    this.localImagePath,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'localId': localId,
        'chatId': chatId,
        'senderId': senderId,
        'senderUsername': senderUsername,
        'body': body,
        'localImagePath': localImagePath,
        'createdAt': createdAt.toIso8601String(),
      };

  factory PendingBufferEntry.fromJson(Map<String, dynamic> j) {
    return PendingBufferEntry(
      localId: j['localId'] as String,
      chatId: j['chatId'] as String,
      senderId: j['senderId'] as String,
      senderUsername: (j['senderUsername'] as String?) ?? '',
      body: j['body'] as String?,
      localImagePath: j['localImagePath'] as String?,
      createdAt: DateTime.parse(j['createdAt'] as String),
    );
  }
}

/// Persists optimistic "pending" messages so they survive navigation away
/// from the chat page and back. Only today's entries are kept.
class PendingMessageBuffer {
  static const _prefix = 'pending_msgs_';

  String _key(String chatId) => '$_prefix$chatId';

  /// Load pending entries for [chatId] that were created today.
  Future<List<PendingBufferEntry>> loadForChat(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key(chatId)) ?? [];

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    final entries = <PendingBufferEntry>[];
    for (final s in raw) {
      try {
        final entry = PendingBufferEntry.fromJson(
          jsonDecode(s) as Map<String, dynamic>,
        );
        final d = entry.createdAt;
        final entryDay = DateTime(d.year, d.month, d.day);
        if (!entryDay.isBefore(todayStart)) entries.add(entry);
      } catch (_) {
        // corrupted entry — skip
      }
    }
    return entries;
  }

  /// Persist a new pending entry.
  Future<void> save(PendingBufferEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _key(entry.chatId);
    final existing = prefs.getStringList(key) ?? [];
    existing.add(jsonEncode(entry.toJson()));
    await prefs.setStringList(key, existing);
  }

  /// Remove a confirmed (or failed) entry by [localId].
  Future<void> remove(String chatId, String localId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _key(chatId);
    final existing = prefs.getStringList(key) ?? [];
    final updated = existing.where((s) {
      try {
        final m = jsonDecode(s) as Map<String, dynamic>;
        return m['localId'] != localId;
      } catch (_) {
        return true;
      }
    }).toList();
    await prefs.setStringList(key, updated);
  }

  /// Wipe all pending entries for a chat (e.g. when chat is deleted).
  Future<void> clearForChat(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(chatId));
  }
}