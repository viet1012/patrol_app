import 'package:flutter/foundation.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

class SttWebSocket {
  late StompClient stomp;
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

  void connect() {
    stomp = StompClient(
      config: StompConfig(
        url: serverUrl,
        onConnect: (frame) {
          debugPrint("WS CONNECTED");

          final topic = "/topic/stt/$fac/$group";
          debugPrint("SUBSCRIBE: $topic");

          stomp.subscribe(
            destination: topic,
            callback: (msg) {
              final body = msg.body?.toString();
              debugPrint("WS MSG: $body");

              if (body != null) {
                final v = int.tryParse(body);
                if (v != null) onSttUpdate(v);
              }
            },
          );
        },

        // 🔥 FIX CHÍNH
        onWebSocketError: (err) {
          debugPrint("WS ERROR: ${err.toString()}");
        },

        onStompError: (f) {
          debugPrint("STOMP ERROR: ${f.body?.toString()}");
        },
      ),
    );

    stomp.activate();
  }

  void dispose() {
    stomp.deactivate();
  }
}
