/// Đường dẫn quay lại sau khi đăng nhập (`?from=`).
abstract final class RouteTarget {
  static const home = '/home';
  static const login = '/';
  static const splash = '/splash';

  /// Chỉ nhận đường dẫn nội bộ: bắt đầu bằng `/`, không phải `//` hay `/\`,
  /// không chứa `://`. Trang login/splash không phải đích hợp lệ.
  /// Trả về `null` nếu không hợp lệ.
  static String? safe(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    if (!value.startsWith('/')) return null;
    if (value.startsWith('//') || value.startsWith(r'/\')) return null;
    if (value.contains('://')) return null;

    final path = Uri.tryParse(value)?.path;
    if (path == null || path == login || path == splash) return null;
    return value;
  }

  /// Đích sau đăng nhập: `from` hợp lệ, không thì `/home`.
  static String afterLogin(String? from) => safe(from) ?? home;
}
