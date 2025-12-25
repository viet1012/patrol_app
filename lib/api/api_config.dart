class ApiConfig {
  static const String domain = 'doctrinally-preambitious-evia.ngrok-free.dev';
  // static const String domain = 'localhost:9299';
  static const int port = 9299;

  static String get baseUrl => 'https://$domain';
  static String get wsBaseUrl => 'wss://$domain';
}
