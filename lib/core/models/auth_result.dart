class AuthResult {
  final bool success;
  final String message;
  final String? code;
  final bool isServerError;
  final dynamic data; // 👈 thêm

  AuthResult({
    required this.success,
    required this.message,
    this.code,
    this.isServerError = false,
    this.data,
  });
}
