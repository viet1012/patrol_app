// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:chuphinh/core/models/auth_me.dart';

class SessionStore {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static String? _authenticatedAccountCode;

  static String? get authenticatedAccount => _authenticatedAccountCode;

  static void clearAuthenticatedAccount() {
    debugPrint('AUTH CLEAR: old=$_authenticatedAccountCode');
    _authenticatedAccountCode = null;
    clearAuthMe();
  }

  static void markAuthenticated(String accountCode) {
    final normalized = accountCode.trim();
    debugPrint('AUTH MARK: $normalized');
    if (normalized != _authenticatedAccountCode) clearAuthMe();
    _authenticatedAccountCode = normalized.isEmpty ? null : normalized;
  }

  // ================= AUTH ME (memory) =================
  // Chỉ cache trong bộ nhớ: F5 / logout là mất, route guard sẽ tải lại.
  static AuthMe? _authMe;
  static String? _authMeAccount;

  /// Quyền đã cache của tài khoản đang đăng nhập (null nếu chưa có).
  static AuthMe? get authMe {
    final account = _authenticatedAccountCode;
    if (account == null || account != _authMeAccount) return null;
    return _authMe;
  }

  static void cacheAuthMe(String accountCode, AuthMe me) {
    _authMeAccount = accountCode.trim();
    _authMe = me;
  }

  static void clearAuthMe() {
    _authMe = null;
    _authMeAccount = null;
  }

  static const _kAccount = 'account_code';
  static const _kPassword = 'account_password';
  static const _kPlant = 'selected_plant';

  // ================= SAVE =================
  static Future<void> saveCreds({
    required String account,
    required String password,
  }) async {
    if (kIsWeb) {
      html.window.localStorage[_kAccount] = account;
      html.window.localStorage[_kPassword] = password;
      // print('✅ SAVED to localStorage: $account / $password');
      // print('🔎 localStorage now: ${html.window.localStorage[_kAccount]}');
    } else {
      await _secureStorage.write(key: _kAccount, value: account);
      await _secureStorage.write(key: _kPassword, value: password);
    }
  }

  static Future<void> savePlant(String account, String plant) async {
    final key = 'selected_plant_$account';

    if (kIsWeb) {
      html.window.localStorage[key] = plant;
    } else {
      await _secureStorage.write(key: key, value: plant);
    }
  }

  // ================= READ =================
  static Future<(String account, String password)?> getCreds() async {
    String? account;
    String? password;

    if (kIsWeb) {
      account = html.window.localStorage[_kAccount];
      password = html.window.localStorage[_kPassword];
    } else {
      account = await _secureStorage.read(key: _kAccount);
      password = await _secureStorage.read(key: _kPassword);
    }

    if (account == null ||
        account.isEmpty ||
        password == null ||
        password.isEmpty) {
      return null;
    }

    return (account, password);
  }

  static Future<String?> getPlant(String account) async {
    final key = 'selected_plant_$account';

    if (kIsWeb) {
      return html.window.localStorage[key];
    } else {
      return await _secureStorage.read(key: key);
    }
  }

  // ================= UI PREFS =================
  /// Tuỳ chọn giao diện theo user (vd. layout cột bảng). Không lưu dữ liệu nhạy cảm.
  static Future<void> saveUiPref(String key, String value) async {
    final k = 'ui_pref_$key';
    if (kIsWeb) {
      html.window.localStorage[k] = value;
    } else {
      await _secureStorage.write(key: k, value: value);
    }
  }

  static Future<String?> getUiPref(String key) async {
    final k = 'ui_pref_$key';
    if (kIsWeb) return html.window.localStorage[k];
    return _secureStorage.read(key: k);
  }

  static Future<void> removeUiPref(String key) async {
    final k = 'ui_pref_$key';
    if (kIsWeb) {
      html.window.localStorage.remove(k);
    } else {
      await _secureStorage.delete(key: k);
    }
  }

  // ================= CLEAR =================
  static Future<void> clear() async {
    clearAuthenticatedAccount();

    if (kIsWeb) {
      html.window.localStorage.remove(_kAccount);
      html.window.localStorage.remove(_kPassword);
    } else {
      await _secureStorage.delete(key: _kAccount);
      await _secureStorage.delete(key: _kPassword);
    }
  }
}
