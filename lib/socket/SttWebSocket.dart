import 'package:stomp_dart_client/stomp_dart_client.dart';

class SttWebSocket {
  late StompClient stomp;
  final String serverUrl;
  final String group;
  final Function(int) onSttUpdate;

  SttWebSocket({
    required this.serverUrl,
    required this.group,
    required this.onSttUpdate,
  });

  void connect() {
    stomp = StompClient(
      config: StompConfig(
        url: serverUrl, // MUST be ws://.../ws-stt/websocket
        onConnect: (frame) {
          stomp.subscribe(
            destination: "/topic/stt/$group",
            callback: (msg) {
              if (msg.body != null) {
                final v = int.tryParse(msg.body!);
                if (v != null) onSttUpdate(v);
              }
            },
          );
        },
        onWebSocketError: (err) => print("WS ERROR: $err"),
        onStompError: (f) => print("STOMP ERROR: ${f.body}"),
      ),
    );

    stomp.activate();
  }

  void dispose() {
    stomp.deactivate();
  }
}
