import 'package:dio/dio.dart';
import 'dart:io';
import '../auth/api_client.dart';
import 'api.dart';
import 'constrains.dart';

class ChatApi {
  final ApiClient apiClient;

  ChatApi(this.apiClient);

  Future<List<ChatListItem>> fetchChats({String sort = "last_message"}) async {
    final r = await apiClient.dio.get(
      Api.chats,
      queryParameters: {"sort": sort},
    );

    final data = r.data;
    if (data is! List) return const [];

    return data
        .whereType<Map<String, dynamic>>()
        .map(ChatListItem.fromJson)
        .toList();
  }

  Future<List<MessageItem>> fetchMessages(String chatId) async {
    final r = await apiClient.dio.get(Api.chatMessages(chatId));

    final data = r.data;
    if (data is! List) return const [];

    return data
        .whereType<Map<String, dynamic>>()
        .map(MessageItem.fromJson)
        .toList();
  }

  Future<void> blockUser(String userId) async {
    await apiClient.dio.post(Api.block, data: {"user_id": userId});
  }

  Future<String> createDirectChat(String otherUserId) async {
    final r = await apiClient.dio.post(
      Api.chatsDirect,
      data: {"other_user_id": otherUserId},
    );

    final chatId = (r.data is Map) ? (r.data["chat_id"] as String?) : null;
    if (chatId == null || chatId.isEmpty) {
      throw DioException(
        requestOptions: r.requestOptions,
        error: "chat_id missing in response",
      );
    }
    return chatId;
  }

  Future<Map<String, dynamic>> toggleAutoDelete(String chatId) async {
    final r = await apiClient.dio.post(Api.toggleAutoDelete(chatId));
    final data = r.data;
    if (data is Map<String, dynamic>) return data;
    throw Exception("Invalid response from toggle-auto-delete");
  }

  Future<MessageItem> sendTextMessage({
    required String chatId,
    String? body,
    File? imageFile,
  }) async {
    final form = FormData();

    if (body != null && body.trim().isNotEmpty) {
      form.fields.add(MapEntry('body', body.trim()));
    }

    if (imageFile != null) {
      form.files.add(
        MapEntry(
          'image',
          await MultipartFile.fromFile(
            imageFile.path,
            filename: imageFile.path.split('/').last,
          ),
        ),
      );
    }

    final res = await apiClient.dio.post(
      '/api/chats/$chatId/messages/',
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );

    return MessageItem.fromJson(res.data);
  }

  Future<void> deleteMessageForMe(String chatId, int msgId) async {
    await apiClient.dio.post(
      '/api/chats/$chatId/messages/$msgId/delete_for_me/',
    );
  }

  Future<void> deleteMessageForAll(String chatId, int msgId) async {
    await apiClient.dio.post(
      '/api/chats/$chatId/messages/$msgId/delete_for_all/',
    );
  }

  Future<MessageItem> editMessage({
    required String chatId,
    required int messageId,
    required String body,
  }) async {
    final res = await apiClient.dio.patch(
      '/api/chats/$chatId/messages/$messageId/',
      data: {"body": body},
    );

    return MessageItem.fromJson(res.data);
  }

  Future<void> deleteChatForMe(String chatId) async {
    await apiClient.dio.post(Api.deleteChatForMe(chatId));
  }

  Future<void> deleteChatForAll(String chatId) async {
    await apiClient.dio.post(Api.deleteChatForAll(chatId));
  }
}
