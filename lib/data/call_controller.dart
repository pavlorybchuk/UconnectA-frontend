import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uconnecta/app_services.dart';
import 'package:uconnecta/data/constrains_&_utils.dart';
import 'package:uconnecta/data/navigation_service.dart';
import 'package:uconnecta/pages/call_in_progress_page.dart';
import 'package:uconnecta/pages/outgoing_call_page.dart';
import 'package:uconnecta/pages/call_page.dart';

enum CallState { idle, incoming, ringing, inProgress }

class CallController {
  final ValueNotifier<CallState> _state =
      ValueNotifier<CallState>(CallState.idle);

  CallState get state => _state.value;
  ValueListenable<CallState> get stateListenable => _state;

  Timer? _callTimer;
  Duration _callDuration = Duration.zero;
  Timer? _incomingTimeout;
  static const _incomingTimeoutSec = 35;

  Duration get callDuration => _callDuration;
  final ValueNotifier<Duration> callDurationListenable =
      ValueNotifier(Duration.zero);

  // Use a ValueNotifier so CallInProgressPage can reactively attach the stream
  // to the renderer as soon as it arrives (which is after the page is shown).
  final ValueNotifier<MediaStream?> remoteStreamNotifier =
      ValueNotifier<MediaStream?>(null);
  MediaStream? get remoteStream => remoteStreamNotifier.value;

  String? callId;
  String? chatId;
  DriverProfile? fromUser; // peer for INCOMING calls
  DriverProfile? callee;   // peer for OUTGOING calls

  // ─── Incoming call ────────────────────────────────────────────────────────

  Future<void> onIncomingCall(Map<String, dynamic> event) async {
    if (callId != null) return;
    final callIdRaw   = event['call_id'];
    final chatIdRaw   = event['chat_id'];
    final fromUserRaw = event['from_user'];
    if (callIdRaw == null || fromUserRaw is! Map) {
      debugPrint('Invalid incoming call event: $event');
      return;
    }
    callId   = callIdRaw.toString();
    chatId   = chatIdRaw?.toString();
    fromUser = DriverProfile.fromJson(Map<String, dynamic>.from(fromUserRaw));
    _state.value = CallState.incoming;
    NavigationService.navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => CallPage(
          callId: callId!,
          chatId: chatId ?? '',
          fromUser: fromUser!,
        ),
      ),
    );
    try { await AppServices.callSound.playIncoming(); } catch (e) {
      debugPrint('callSound error: $e');
    }
    try { await AppServices.callVibration.startIncoming(); } catch (e) {
      debugPrint('callVibration error: $e');
    }
    _startIncomingTimeout();
  }

  void _startIncomingTimeout() {
    _incomingTimeout?.cancel();
    _incomingTimeout = Timer(
      const Duration(seconds: _incomingTimeoutSec),
      () async {
        if (callId == null || state != CallState.incoming) return;
        try { await AppServices.apiClient.post('/api/calls/$callId/missed/'); }
        catch (_) {}
        reset();
        NavigationService.navigatorKey.currentState?.popUntil((r) => r.isFirst);
      },
    );
  }

  // ─── Outgoing call ────────────────────────────────────────────────────────

  Future<void> startOutgoingCall({
    required String chatId,
    required String calleeId,
    required DriverProfile peer,
  }) async {
    if (callId != null) return;

    this.chatId = chatId;
    this.callee = peer;

    // 1. Create the call → server notifies receiver via WS/FCM.
    final response = await AppServices.apiClient.post(
      '/api/calls/create/',
      data: {'receiver_id': calleeId, 'chat_id': chatId},
    );
    callId = response.data['call_id'].toString();
    _state.value = CallState.ringing;

    // 2. Show outgoing screen immediately.
    NavigationService.navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => OutgoingCallPage(peer: peer)),
    );

    // 3. Set up WebRTC and JOIN the signaling channel NOW — while the phone
    //    is still ringing — so we are guaranteed to receive the callee's
    //    "ready" message regardless of network latency on either side.
    await AppServices.callService.initPeer(
      onRemoteStream: (stream) => remoteStreamNotifier.value = stream,
    );
    await AppServices.callService.initLocalAudio();
    await AppServices.callService.connectWs(callId!, asCaller: true);
  }

  // ─── Caller: receiver accepted ────────────────────────────────────────────
  // WebRTC is already running. Just navigate to the in-progress screen.

  Future<void> onCallAccepted(Map<String, dynamic> event) async {
    if (event['call_id']?.toString() != callId) return;
    if (state != CallState.ringing) return;

    _state.value = CallState.inProgress;
    _startCallTimer();

    // Enable speaker now that we're in a call.
    try { await AppServices.callService.setSpeaker(true); } catch (_) {}

    NavigationService.navigatorKey.currentState?.pushReplacement(
      MaterialPageRoute(
        builder: (_) => CallInProgressPage(
          chatId: chatId ?? '',
          peer: callee!,
        ),
      ),
    );
  }

  // ─── Accept incoming call (callee) ────────────────────────────────────────

  Future<void> accept({
    required void Function(MediaStream stream) onRemoteStream,
  }) async {
    if (callId == null) return;

    _incomingTimeout?.cancel();
    try { await AppServices.callSound.stop(); } catch (_) {}
    try { await AppServices.callVibration.stop(); } catch (_) {}
    try { await AppServices.callVibration.shortPulse(); } catch (_) {}

    await AppServices.apiClient.post('/api/calls/$callId/accept/');
    _state.value = CallState.inProgress;
    _startCallTimer();

    await AppServices.callService.initPeer(
      onRemoteStream: (stream) {
        remoteStreamNotifier.value = stream;
        onRemoteStream(stream);
      },
    );
    await AppServices.callService.initLocalAudio();
    // Send "ready" → triggers caller to create and send the SDP offer.
    await AppServices.callService.connectWs(callId!, asCaller: false);

    // Enable speaker.
    try { await AppServices.callService.setSpeaker(true); } catch (_) {}
  }

  // ─── Reject / End ─────────────────────────────────────────────────────────

  Future<void> reject() async {
    if (callId == null) return;
    _incomingTimeout?.cancel();
    try { await AppServices.callSound.stop(); } catch (_) {}
    try { await AppServices.callVibration.stop(); } catch (_) {}
    try { await AppServices.apiClient.post('/api/calls/$callId/reject/'); }
    catch (_) {}
    reset();
  }

  Future<void> end() async {
    if (callId == null) return;
    try { await AppServices.apiClient.post('/api/calls/$callId/end/'); }
    catch (_) {}
    reset();
  }

  // ─── Remote side ended ────────────────────────────────────────────────────

  Future<void> onCallEnded(Map<String, dynamic> event) async {
    if (event['call_id']?.toString() != callId) return;
    _incomingTimeout?.cancel();
    reset();
    // The _onStateChanged listener in each call page handles navigation.
    // We only popUntil as a safety net in case no page is listening.
    NavigationService.navigatorKey.currentState?.popUntil((r) => r.isFirst);
  }

  // ─── Reset ────────────────────────────────────────────────────────────────

  void reset() {
    _incomingTimeout?.cancel();
    _incomingTimeout = null;
    _stopCallTimer();

    callId    = null;
    chatId    = null;
    fromUser  = null;
    callee    = null;
    remoteStreamNotifier.value = null;

    try { AppServices.callSound.stop(); } catch (_) {}
    try { AppServices.callVibration.stop(); } catch (_) {}
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