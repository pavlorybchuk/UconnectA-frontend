import 'package:uconnecta/data/call_controller.dart';
import 'package:uconnecta/data/call_service.dart';
import 'package:uconnecta/data/call_sound_service.dart';
import 'package:uconnecta/data/call_vibration_services.dart';
import 'package:uconnecta/data/chat_api.dart';
import 'package:uconnecta/data/chat_store.dart';
import 'package:uconnecta/data/user_ws_service.dart';
import 'auth/token_storage.dart';
import 'auth/api_client.dart';
import 'auth/auth_service.dart';

class AppServices {
  AppServices._();

  static final TokenStorage tokenStorage = TokenStorage();
  static final ApiClient apiClient = ApiClient(tokenStorage: tokenStorage);
  static final AuthService auth = AuthService(
    api: apiClient,
    storage: tokenStorage,
  );
  static final chatApi = ChatApi(apiClient);
  static final userWs = UserWsService();
  static final chatStore = ChatStore();
  static late CallService callService;
  static final callController = CallController();
  static final callSound = CallSoundService();
  static final callVibration = CallVibrationService();
  static void userWsEventHandler(Map<String, dynamic> event) {
    final type = event["type"];
    final payload = event["payload"];

    if (type == "call.incoming") {
      callController.onIncomingCall(payload);
    }

    if (type == "call.rejected" || type == "call.ended") {
      callController.onCallEnded(payload);
    }
  }
}
