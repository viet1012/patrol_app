class ApiConfig {
  static const String domain = 'localhost';
  static const int port = 9299;

  static String get baseUrl => 'http://$domain:$port';
}
