/// Lỗi 409 Conflict từ server, [message] lấy từ body response.
class ApiConflictException implements Exception {
  final String message;

  const ApiConflictException(this.message);

  static const int statusCode = 409;

  factory ApiConflictException.fromResponseData(dynamic data) {
    return ApiConflictException(_extractMessage(data));
  }

  static String _extractMessage(dynamic data) {
    if (data is Map) {
      for (final key in const ['message', 'error', 'detail']) {
        final value = data[key]?.toString().trim() ?? '';
        if (value.isNotEmpty) return value;
      }
    }

    final text = data?.toString().trim() ?? '';
    return text.isEmpty ? 'Conflict (409)' : text;
  }

  @override
  String toString() => message;
}
