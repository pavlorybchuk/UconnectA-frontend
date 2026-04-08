import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uconnecta/app_services.dart';
import 'package:uconnecta/data/constrains.dart';
import 'package:uconnecta/data/navigation_service.dart';
import 'package:uconnecta/pages/call_page.dart';

enum CallState { idle, incoming, ringing, inProgress }

class CallController {
  final ValueNotifier<CallState> _state = ValueNotifier<CallState>(
    CallState.idle,
  );

  CallState get state => _state.value;
  ValueListenable<CallState> get stateListenable => _state;
  Timer? _callTimer;
  Duration _callDuration = Duration.zero;
  Timer? _incomingTimeout;
  static const _incomingTimeoutSec = 35;
  Duration get callDuration => _callDuration;
  ValueNotifier<Duration> callDurationListenable = ValueNotifier(Duration.zero);
  String? callId;
  String? chatId;
  DriverProfile? fromUser;
  MediaStream? remoteStream;

  void _startIncomingTimeout() {
    _incomingTimeout?.cancel();

    _incomingTimeout = Timer(
      const Duration(seconds: _incomingTimeoutSec),
      () async {
        // якщо дзвінок досі incoming — це missed call
        if (callId == null || state != CallState.incoming) return;

        debugPrint('Missed call: $callId');

        await AppServices.callSound.stop();
        await AppServices.callVibration.stop();

        try {
          await AppServices.apiClient.post('/api/calls/$callId/missed/');
        } catch (_) {
          // сервер може вже закрити дзвінок — ігноруємо
        }

        reset();

        NavigationService.navigatorKey.currentState?.popUntil((r) => r.isFirst);
      },
    );
  }

  // =========================
  // Incoming call (from WS)
  // =========================
  Future<void> onIncomingCall(Map<String, dynamic> payload) async {
    // Захист від дублюючих дзвінків
    if (callId != null) return;

    final callIdRaw = payload['call_id'];
    final chatIdRaw = payload['chat_id'];
    final fromUserRaw = payload['from_user'];

    if (callIdRaw == null || chatIdRaw == null || fromUserRaw is! Map) {
      debugPrint('Invalid incoming call payload: $payload');
      return;
    }

    callId = callIdRaw.toString();
    chatId = chatIdRaw.toString();
    fromUser = DriverProfile.fromJson(Map<String, dynamic>.from(fromUserRaw));

    _state.value = CallState.incoming;

    await AppServices.callSound.playIncoming();
    await AppServices.callVibration.startIncoming();

    final navigator = NavigationService.navigatorKey.currentState;
    if (navigator == null) return;

    navigator.push(
      MaterialPageRoute(
        builder: (_) =>
            CallPage(callId: callId!, chatId: chatId!, fromUser: fromUser!),
      ),
    );
    _startIncomingTimeout();
  }

  Future<void> startOutgoingCall({
    required String chatId,
    required String calleeId,
  }) async {
    if (callId != null) return;

    this.chatId = chatId;

    final response = await AppServices.apiClient.post(
      '/api/calls/start/',
      data: {'chat_id': chatId, 'callee_id': calleeId},
    );

    callId = response.data['call_id'].toString();

    _state.value = CallState.ringing;

    // 2. відкриваємо CallPage
    // NavigationService.navigatorKey.currentState?.push(
    //   MaterialPageRoute(
    //     builder: (_) => CallPage(
    //       callId: callId!,
    //       chatId: chatId!,
    //       fromUser: null, // outgoing
    //     ),
    //   ),
    // );

    await AppServices.callService.initPeer(
      onRemoteStream: (stream) {
        remoteStream = stream;
      },
    );

    await AppServices.callService.initLocalAudio();
    await AppServices.callService.connectWs(callId!);

    await AppServices.callService.createOffer();
  }

  Future<void> accept({
    required void Function(MediaStream stream) onRemoteStream,
  }) async {
    if (callId == null) return;

    _incomingTimeout?.cancel();

    await AppServices.callSound.stop();
    await AppServices.callVibration.stop();
    await AppServices.callVibration.shortPulse();
    await AppServices.apiClient.post('/api/calls/$callId/accept/');

    _state.value = CallState.inProgress;

    await AppServices.callService.initPeer(
      onRemoteStream: (stream) {
        remoteStream = stream;
        onRemoteStream(stream);
      },
    );

    await AppServices.callService.initLocalAudio();
    await AppServices.callService.connectWs(callId!);

    _state.value = CallState.inProgress;
    _startCallTimer();
  }

  // =========================
  // Reject / End
  // =========================
  Future<void> reject() async {
    if (callId == null) return;

    _incomingTimeout?.cancel();
    await AppServices.callSound.stop();
    await AppServices.callVibration.stop();
    await AppServices.apiClient.post('/api/calls/$callId/reject/');
    reset();
  }

  Future<void> onCallEnded(Map payload) async {
    if (payload['call_id']?.toString() != callId) return;

    _incomingTimeout?.cancel();
    reset();

    NavigationService.navigatorKey.currentState?.popUntil((r) => r.isFirst);
  }

  // =========================
  // Reset
  // =========================
  void reset() async {
    _incomingTimeout?.cancel();
    _incomingTimeout = null;

    callId = null;
    chatId = null;
    fromUser = null;
    remoteStream = null;
    _stopCallTimer();
    await AppServices.callSound.stop();
    await AppServices.callVibration.stop();

    AppServices.callService.endLocal();
    _state.value = CallState.idle;
  }

  void _startCallTimer() {
    _callTimer?.cancel();
    _callDuration = Duration.zero;
    callDurationListenable.value = Duration.zero;

    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _callDuration += const Duration(seconds: 1);
      callDurationListenable.value = _callDuration;
    });
  }

  void _stopCallTimer() {
    _callTimer?.cancel();
    _callTimer = null;
  }
}
