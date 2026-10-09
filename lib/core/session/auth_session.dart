import 'package:flutter/foundation.dart';

import 'package:chuphinh/core/api/auth_api.dart';
import 'package:chuphinh/core/session/session_store.dart';

enum AuthStatus { restoring, authenticated, unauthenticated }

/// Trạng thái phiên đăng nhập toàn app.
///
/// Khi app khởi động (kể cả F5), [restore] tự đăng nhập lại bằng thông tin
/// đã lưu. GoRouter dùng instance này làm `refreshListenable` để chờ khôi
/// phục xong rồi mới quyết định redirect, nên không mất URL đích.
class AuthSession extends ChangeNotifier {
  AuthSession._();

  static final AuthSession instance = AuthSession._();

  AuthStatus _status = AuthStatus.restoring;
  AuthStatus get status => _status;
  bool get isRestoring => _status == AuthStatus.restoring;

  Future<void>? _restoring;

  /// Gọi 1 lần lúc khởi động; gọi lặp lại trả về cùng Future.
  Future<void> restore() => _restoring ??= _restore();

  Future<void> _restore() async {
    try {
      final creds = await SessionStore.getCreds();
      if (creds == null) return _finish(AuthStatus.unauthenticated);

      final (account, password) = creds;
      final normalizedAccount = account.trim();
      final normalizedPassword = password.trim();

      if (normalizedAccount.isEmpty || normalizedPassword.isEmpty) {
        await SessionStore.clear();
        return _finish(AuthStatus.unauthenticated);
      }

      final result = await AuthApi.login(
        account: normalizedAccount,
        password: normalizedPassword,
      );

      if (result.success == true) {
        SessionStore.markAuthenticated(normalizedAccount);
        return _finish(AuthStatus.authenticated);
      }

      // Giữ hành vi cũ của auto-login: thất bại thì xoá thông tin đã lưu.
      await SessionStore.clear();
      _finish(AuthStatus.unauthenticated);
    } catch (error, stackTrace) {
      debugPrint('Restore session error: $error');
      debugPrintStack(stackTrace: stackTrace);
      SessionStore.clearAuthenticatedAccount();
      await SessionStore.clear();
      _finish(AuthStatus.unauthenticated);
    }
  }

  void _finish(AuthStatus status) {
    _status = status;
    notifyListeners();
  }
}
