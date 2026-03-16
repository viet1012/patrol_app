// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionStore {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

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

  // ================= CLEAR =================
  static Future<void> clear() async {
    if (kIsWeb) {
      html.window.localStorage.remove(_kAccount);
      html.window.localStorage.remove(_kPassword);
    } else {
      await _secureStorage.delete(key: _kAccount);
      await _secureStorage.delete(key: _kPassword);
    }
  }
}
