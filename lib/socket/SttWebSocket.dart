import 'package:flutter/foundation.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

class SttWebSocket {
  StompClient? _stomp;

  final String serverUrl;
  final String fac;
  final String group;
  final Function(int) onSttUpdate;

  SttWebSocket({
    required this.serverUrl,
    required this.fac,
    required this.group,
    required this.onSttUpdate,
  });

  // ✅ normalize giống BE
  String _normalize(String v) => v.replaceAll(' ', '').trim();

  void connect() {
    // 🔥 đảm bảo không có socket cũ
    dispose();

    final facClean = _normalize(fac);
    final grpClean = _normalize(group);
    final topic = "/topic/stt/$facClean/$grpClean";

    debugPrint("🔌 WS CONNECTING...");
    debugPrint("📌 SUBSCRIBE TOPIC: $topic");

    _stomp = StompClient(
      config: StompConfig(
        url: serverUrl,
        reconnectDelay: const Duration(seconds: 5),

        onConnect: (frame) {
          debugPrint("✅ WS CONNECTED");

          _stomp!.subscribe(
            destination: topic,
            callback: (msg) {
              final body = msg.body;
              debugPrint("📥 WS MSG [$topic]: $body");

              if (body == null) return;

              final value = int.tryParse(body);
              if (value != null) {
                debugPrint("✅ Parsed STT = $value");
                onSttUpdate(value);
              } else {
                debugPrint("❌ Cannot parse STT from body");
              }
            },
          );
        },

        onWebSocketError: (err) {
          debugPrint("❌ WS ERROR: $err");
        },

        onStompError: (frame) {
          debugPrint("❌ STOMP ERROR: ${frame.body}");
        },

        onDisconnect: (_) {
          debugPrint("🔌 WS DISCONNECTED");
        },
      ),
    );

    _stomp!.activate();
  }

  void dispose() {
    if (_stomp != null) {
      debugPrint("🧹 WS DISPOSE");
      _stomp!.deactivate();
      _stomp = null;
    }
  }
}
