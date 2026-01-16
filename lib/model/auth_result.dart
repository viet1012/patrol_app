class AuthResult {
  final bool success;
  final String message;
  final bool isServerError; // 👈 QUAN TRỌNG

  AuthResult({
    required this.success,
    required this.message,
    this.isServerError = false,
  });
}
