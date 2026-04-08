import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uconnecta/app_services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class CallService {
  RTCPeerConnection? _pc;
  WebSocketChannel? _ws;
  MediaStream? _localStream;

  final String baseUrl;
  final String wsUrl;
  final String accessToken;

  CallService({
    required this.baseUrl,
    required this.wsUrl,
    required this.accessToken,
  });

  Future<void> initPeer({
    required void Function(MediaStream stream) onRemoteStream,
  }) async {
    _pc = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    });

    _pc!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        onRemoteStream(event.streams.first);
      }
    };

    _pc!.onIceCandidate = (candidate) {
      if (candidate != null) {
        _ws?.sink.add(
          jsonEncode({'type': 'ice', 'candidate': candidate.toMap()}),
        );
      }
    };
  }

  Future<MediaStream> initLocalAudio() async {
    final stream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': false,
    });

    _localStream = stream;

    if (_pc != null) {
      for (final track in stream.getTracks()) {
        await _pc!.addTrack(track, stream);
      }
    }

    return stream;
  }

  Future<void> connectWs(String callId) async {
    _ws = WebSocketChannel.connect(
      Uri.parse('$wsUrl/ws/calls/$callId/?token=$accessToken'),
    );

    _ws!.stream.listen(_onWsMessage);
  }

  void _onWsMessage(dynamic data) async {
    final msg = jsonDecode(data);

    switch (msg['type']) {
      case 'offer':
        await _handleOffer(msg);
        break;
      case 'answer':
        await _handleAnswer(msg);
        break;
      case 'ice':
        await _handleIce(msg);
        break;
      case 'hangup':
        AppServices.callController.reset();
        break;
    }
  }

  Future<void> createOffer() async {
    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);

    _ws!.sink.add(jsonEncode({'type': 'offer', 'sdp': offer.sdp}));
  }

  Future<void> _handleOffer(Map msg) async {
    await _pc!.setRemoteDescription(RTCSessionDescription(msg['sdp'], 'offer'));

    final answer = await _pc!.createAnswer();
    await _pc!.setLocalDescription(answer);

    _ws!.sink.add(jsonEncode({'type': 'answer', 'sdp': answer.sdp}));
  }

  Future<void> _handleAnswer(Map msg) async {
    await _pc!.setRemoteDescription(
      RTCSessionDescription(msg['sdp'], 'answer'),
    );
  }

  Future<void> _handleIce(Map msg) async {
    final c = msg['candidate'];
    await _pc!.addCandidate(
      RTCIceCandidate(c['candidate'], c['sdpMid'], c['sdpMLineIndex']),
    );
  }

  void setMuted(bool muted) {
    if (_localStream == null) return;

    for (final track in _localStream!.getAudioTracks()) {
      track.enabled = !muted;
    }
  }

  Future<void> setSpeaker(bool on) async {
    await Helper.setSpeakerphoneOn(on);
  }

  Future<void> attachLocalStream(MediaStream stream) async {
    _localStream = stream;
    for (final track in stream.getTracks()) {
      await _pc?.addTrack(track, stream);
    }
  }

  void endLocal() {
    _ws?.sink.close();
    _pc?.close();
    _localStream?.dispose();
    _pc = null;
  }
}
