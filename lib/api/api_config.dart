class ApiConfig {
  // static const String domain = 'plumular-rollickingly-kannon.ngrok-free.dev';
  static const String domain = 'localhost:9299';
  // static const int port = 9299;

  static String get baseUrl => 'http://$domain';
  static String get wsBaseUrl => 'ws://$domain';
}
