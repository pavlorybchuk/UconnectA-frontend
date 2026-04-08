class Api {
  static const String baseUrl = "https://uconnecta-backend.onrender.com";

  static const String login = "/api/auth/login/";
  static const String refresh = "/api/auth/refresh/";
  static const String register = "/api/auth/register/";
  static const String logout = "/api/auth/logout/";
  static const String me = "/api/me/";
  static const String block = "/api/block/";
  static const String recognizePhoto = "/api/recognize-photo/";
  static const String chats = "/api/chats/";
  static const String chatsDirect = "/api/chats/direct/";

  static String chatMessages(String chatId) => "/api/chats/$chatId/messages/";
  static String deleteChatForMe(String chatId) =>
      "/api/chats/$chatId/delete-for-me/";
  static String deleteChatForAll(String chatId) =>
      "/api/chats/$chatId/delete-for-all/";
  static String toggleAutoDelete(String chatId) =>
      "/api/chats/$chatId/toggle-auto-delete/";
}
