class ApiConfig {
  static const String version = 'V1.9.4';

  // static const String domain = 'plumular-rollickingly-kannon.ngrok-free.dev';
  // static const String domain = '192.168.122.16:8002';
  // static const String domain = '192.168.122.15:9299';
  // static const String domain = 'localhost:9299';
  static const String domain = 'api.s-patrol.ngrok.io';

  static const int port = 9299;

  static String get imgUrl => 'http://192.168.122.15:9299';

  static String get baseUrl => 'https://$domain';
  static String get wsBaseUrl => 'wss://$domain';
}
