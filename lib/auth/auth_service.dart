import 'package:dio/dio.dart';
import 'package:uconnecta/app_services.dart';
import '../data/api.dart';
import 'api_client.dart';
import 'token_storage.dart';
import 'tokens.dart';

class AuthService {
  final ApiClient api;
  final TokenStorage storage;

  AuthService({required this.api, required this.storage});

  Future<JwtTokens> login({
    required String email,
    required String password,
  }) async {
    final r = await api.dio.post(
      Api.login,
      data: {"email": email.trim(), "password": password},
    );

    final tokens = JwtTokens.fromJson(Map<String, dynamic>.from(r.data));
    await storage.saveTokens(access: tokens.access, refresh: tokens.refresh);

    AppServices.userWs.connect(onEvent: AppServices.userWsEventHandler);
    return tokens;
  }

  Future<void> register({
    required String email,
    required String phone,
    required String password,
    required String repeatPassword,
    required String howToAddress,
  }) async {
    await api.dio.post(
      Api.register,
      data: {
        "email": email.trim(),
        "phone": phone.trim(),
        "password": password,
        "repeat_password": repeatPassword,
        "how_to_address": howToAddress,
      },
    );
  }

  Future<Map<String, dynamic>> me() async {
    final r = await api.dio.get(Api.me);
    return Map<String, dynamic>.from(r.data);
  }

  Future<void> logout() async {
    // 1️⃣ Завершити активний дзвінок (якщо був)
    try {
      AppServices.callController.reset();
    } catch (_) {}

    // 2️⃣ Закрити CallService
    try {
      AppServices.callService.endLocal();
    } catch (_) {}

    // 3️⃣ Закрити user WS
    try {
      await AppServices.userWs.disconnect();
    } catch (_) {}

    // 4️⃣ Очистити чати
    AppServices.chatStore.clear();

    // 5️⃣ Очистити токени
    await storage.clear();
  }

  bool isDio401(DioException e) => e.response?.statusCode == 401;

  Future<void> saveFcmToken(String token) async {
    await api.post("/api/me/fcm/", data: {"fcm_token": token});
  }
}