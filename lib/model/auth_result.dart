class AuthResult {
  final bool success;
  final String message;
  final String? code; // 👈 THÊM DÒNG NÀY
  final bool isServerError;

  AuthResult({
    required this.success,
    required this.message,
    this.code, // 👈 THÊM
    this.isServerError = false,
  });
}
