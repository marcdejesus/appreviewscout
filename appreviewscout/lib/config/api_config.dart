class ApiConfig {
  static const String host = '127.0.0.1';
  static const int port = 8000;

  static String get baseUrl => 'http://$host:$port';
  static String get staticUrl => '$baseUrl/static';
}
