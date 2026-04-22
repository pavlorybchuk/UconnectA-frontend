import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uconnecta/app_services.dart';
import 'package:uconnecta/data/api.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class CallService {
  RTCPeerConnection? _pc;
  WebSocketChannel? _ws;
  MediaStream? _localStream;
  bool _isCaller = false;

  // ICE candidates that arrive before setRemoteDescription are buffered here.
  bool _remoteDescSet = false;
  final List<RTCIceCandidate> _pendingCandidates = [];

  String _wsBase() {
    final uri = Uri.parse(Api.baseUrl);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return Uri(
      scheme: scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
    ).toString();
  }

  /// Fetches ICE server config (including TURN credentials) from the backend.
  Future<List<Map<String, dynamic>>> _fetchIceServers() async {
    try {
      final r = await AppServices.apiClient.get('/api/webrtc/ice-servers/');
      final list = r.data['iceServers'] as List?;
      if (list != null) {
        return list
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    } catch (e) {
      debugPrint('[CallService] ICE fetch failed: $e — using STUN fallback');
    }
    return [
      {'urls': 'stun:stun.l.google.com:19302'},
    ];
  }

  Future<void> initPeer({
    required void Function(MediaStream stream) onRemoteStream,
  }) async {
    _remoteDescSet = false;
    _pendingCandidates.clear();

    final iceServers = await _fetchIceServers();
    debugPrint('[CallService] using ICE servers: $iceServers');

    _pc = await createPeerConnection({
      'iceServers': iceServers,
      'iceTransportPolicy': 'all',
      'bundlePolicy': 'max-bundle',
      'rtcpMuxPolicy': 'require',
    });

    _pc!.onTrack = (event) {
      debugPrint('[WebRTC] onTrack: ${event.track.kind}');
      if (event.streams.isNotEmpty) {
        onRemoteStream(event.streams.first);
      }
    };

    _pc!.onIceCandidate = (candidate) {
      if (candidate != null) {
        debugPrint('[WebRTC] local ICE: ${candidate.candidate}');
        _ws?.sink.add(
          jsonEncode({'type': 'ice', 'candidate': candidate.toMap()}),
        );
      }
    };

    _pc!.onConnectionState = (s) => debugPrint('[WebRTC] connection: $s');
    _pc!.onIceConnectionState = (s) => debugPrint('[WebRTC] ICE: $s');
    _pc!.onIceGatheringState = (s) => debugPrint('[WebRTC] gathering: $s');
    _pc!.onSignalingState = (s) => debugPrint('[WebRTC] signaling: $s');
  }

  Future<MediaStream> initLocalAudio() async {
    final stream = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': false,
    });
    _localStream = stream;
    debugPrint(
        '[CallService] local audio tracks: ${stream.getAudioTracks().length}');
    for (final track in stream.getAudioTracks()) {
      await _pc!.addTrack(track, stream);
      debugPrint(
          '[CallService] added audio track ${track.id} enabled=${track.enabled}');
    }
    return stream;
  }

  /// [asCaller] = true  → wait for callee's "ready", then create offer.
  /// [asCaller] = false → send "ready" once the WS handshake is complete.
  Future<void> connectWs(String callId, {bool asCaller = false}) async {
    _isCaller = asCaller;
    final access = await AppServices.tokenStorage.readAccess();
    _ws = WebSocketChannel.connect(
      Uri.parse('${_wsBase()}/ws/calls/$callId/?token=${access ?? ""}'),
    );
    _ws!.stream.listen(_onWsMessage, onError: (e) {
      debugPrint('[CallService] WS error: $e');
    });

    if (!asCaller) {
      // Give the server-side handshake time to complete before signalling.
      await Future.delayed(const Duration(milliseconds: 400));
      _ws!.sink.add(jsonEncode({'type': 'ready'}));
      debugPrint('[CallService] >> ready');
    }
  }

  void _onWsMessage(dynamic data) async {
    final msg = jsonDecode(data as String);
    final type = msg['type'] as String?;
    debugPrint('[CallService] << $type');

    switch (type) {
      case 'connected':
        // Server-side WS confirmation — nothing to do.
        break;
      case 'ready':
        if (_isCaller) {
          debugPrint('[CallService] callee ready → creating offer');
          await _createOffer();
        }
        break;
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

  Future<void> _createOffer() async {
    final offer = await _pc!.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': false,
    });
    await _pc!.setLocalDescription(offer);
    _ws!.sink.add(jsonEncode({'type': 'offer', 'sdp': offer.sdp}));
    debugPrint('[CallService] >> offer sent');
  }

  Future<void> _handleOffer(Map msg) async {
    await _pc!.setRemoteDescription(
        RTCSessionDescription(msg['sdp'], 'offer'));
    _remoteDescSet = true;
    await _flushPendingCandidates();

    final answer = await _pc!.createAnswer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': false,
    });
    await _pc!.setLocalDescription(answer);
    _ws!.sink.add(jsonEncode({'type': 'answer', 'sdp': answer.sdp}));
    debugPrint('[CallService] >> answer sent');
  }

  Future<void> _handleAnswer(Map msg) async {
    await _pc!.setRemoteDescription(
        RTCSessionDescription(msg['sdp'], 'answer'));
    _remoteDescSet = true;
    await _flushPendingCandidates();
    debugPrint('[CallService] remote description set (answer)');
  }

  Future<void> _handleIce(Map msg) async {
    final c = msg['candidate'];
    if (c == null) return;

    final candidate = RTCIceCandidate(
      c['candidate'] as String,
      c['sdpMid'] as String?,
      c['sdpMLineIndex'] as int?,
    );

    if (_remoteDescSet) {
      await _pc!.addCandidate(candidate);
    } else {
      debugPrint('[CallService] buffering ICE candidate');
      _pendingCandidates.add(candidate);
    }
  }

  Future<void> _flushPendingCandidates() async {
    if (_pendingCandidates.isEmpty) return;
    debugPrint(
        '[CallService] flushing ${_pendingCandidates.length} buffered ICE candidates');
    for (final c in _pendingCandidates) {
      await _pc!.addCandidate(c);
    }
    _pendingCandidates.clear();
  }

  void setMuted(bool muted) {
    _localStream?.getAudioTracks().forEach((t) => t.enabled = !muted);
  }

  Future<void> setSpeaker(bool on) async {
    await Helper.setSpeakerphoneOn(on);
  }

  void endLocal() {
    _ws?.sink.close();
    _pc?.close();
    _localStream?.dispose();
    _ws = null;
    _pc = null;
    _localStream = null;
    _isCaller = false;
    _remoteDescSet = false;
    _pendingCandidates.clear();
  }
}