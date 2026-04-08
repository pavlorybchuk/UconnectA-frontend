import 'dart:async';
import 'dart:convert';

import 'package:uconnecta/app_services.dart';
import 'package:uconnecta/data/api.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import 'package:web_socket_channel/web_socket_channel.dart';

typedef WsEventHandler = void Function(Map<String, dynamic> event);

class UserWsService {
  WebSocketChannel? _ws;
  StreamSubscription? _sub;
  Timer? _reconnectTimer;

  bool _manuallyClosed = false;
  int _retry = 0;

  bool get isConnected => _ws != null;

  String _wsBase() {
    final uri = Uri.parse(Api.baseUrl);
    final scheme = uri.scheme == "https" ? "wss" : "ws";
    return Uri(
      scheme: scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
    ).toString();
  }

  Future<void> connect({required WsEventHandler onEvent}) async {
    if (_ws != null) return;

    final access = await AppServices.tokenStorage.readAccess();
    if (access == null || access.isEmpty) return;

    _manuallyClosed = false;

    final url = '${_wsBase()}/ws/user/?token=$access';
    _ws = WebSocketChannel.connect(Uri.parse(url));

    _sub = _ws!.stream.listen(
      (event) {
        try {
          final raw = (event is String) ? event : event.toString();
          final decoded = jsonDecode(raw);

          if (decoded is Map) {
            onEvent(Map<String, dynamic>.from(decoded));
          }
        } catch (_) {}
      },
      onDone: _handleDisconnect,
      onError: (_) => _handleDisconnect(),
      cancelOnError: true,
    );
  }

  void _handleDisconnect() {
    _ws = null;
    _sub = null;

    if (_manuallyClosed) return;

    _retry++;
    final delay = Duration(seconds: (_retry > 5 ? 5 : _retry));

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      connect(onEvent: AppServices.userWsEventHandler);
    });
  }

  Future<void> disconnect() async {
    _manuallyClosed = true;
    _retry = 0;

    _reconnectTimer?.cancel();
    await _sub?.cancel();
    _sub = null;

    try {
      _ws?.sink.close(ws_status.goingAway);
    } catch (_) {}

    _ws = null;
  }
}
