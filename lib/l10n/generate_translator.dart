import 'dart:convert';
import 'dart:io';

void main() async {
  final dir = Directory('lib/l10n');
  if (!dir.existsSync()) {
    print("❌ Không tìm thấy thư mục lib/l10n/");
    return;
  }

  final arbFiles = dir
      .listSync()
      .where((f) => f.path.endsWith('.arb'))
      .map((f) => File(f.path))
      .toList();

  if (arbFiles.isEmpty) {
    print("❌ Không tìm thấy file .arb nào trong lib/l10n/");
    return;
  }

  final Map<String, Map<String, dynamic>> arbData = {};
  for (var f in arbFiles) {
    arbData[f.path] = jsonDecode(f.readAsStringSync());
  }

  // Chọn file ref có nhiều key nhất
  String refFile = arbData.keys.first;
  int maxCount = 0;
  arbData.forEach((file, data) {
    final count = data.keys.where((e) => !e.startsWith('@')).length;
    if (count > maxCount) {
      refFile = file;
      maxCount = count;
    }
  });

  final refKeys = arbData[refFile]!.keys
      .where((k) => !k.startsWith('@'))
      .toList();

  print("✨ Reference keys from: $refFile");

  // -----------------------
  // BẮT ĐẦU TẠO FILE
  // -----------------------
  final buffer = StringBuffer('''
import 'package:flutter/widgets.dart';
import 'l10n/app_localizations.dart';
import 'l10n/app_localizations_en.dart';
import 'l10n/app_localizations_vi.dart';
import 'l10n/app_localizations_ja.dart';

extension TranslateExtension on String {

  // -----------------------------------------
  // 1. HÀM DỊCH THEO LOCALE HIỆN TẠI
  // -----------------------------------------
  String tr(BuildContext context, {Map<String, dynamic>? params}) {
    final t = AppLocalizations.of(context);
    late String value;

    switch (this) {
''');

  for (var key in refKeys) {
    // Kiểm tra placeholder
    bool hasPlaceholder = false;
    List<String> paramNames = [];

    for (var arb in arbData.values) {
      if (arb.containsKey('@$key')) {
        final placeholders = arb['@$key']['placeholders'];
        if (placeholders != null && placeholders.isNotEmpty) {
          hasPlaceholder = true;
          paramNames = placeholders.keys.toList();
          break;
        }
      }
    }

    if (hasPlaceholder) {
      final paramsPass = paramNames
          .map((p) => "params?['$p'] ?? ''")
          .join(", ");
      buffer.writeln("      case '$key': value = t!.$key($paramsPass); break;");
    } else {
      buffer.writeln("      case '$key': value = t!.$key; break;");
    }
  }

  buffer.writeln('''
      default:
        value = this;
    }

    // Replace placeholders
    if (params != null) {
      params.forEach((k, v) {
        value = value.replaceAll('{\$k}', v.toString());
      });
    }

    return value;
  }

  // -----------------------------------------
  // 2. HÀM DỊCH THEO LOCALE CỤ THỂ (VI / JA)
  // -----------------------------------------
  String _trLocale(String key, Locale locale, {Map<String, dynamic>? params}) {
    final t = lookupAppLocalizations(locale);
    if (t == null) return key;

    switch (key) {
''');

  // tạo _trLocale()
  for (var key in refKeys) {
    bool hasPlaceholder = false;
    List<String> paramNames = [];

    for (var arb in arbData.values) {
      if (arb.containsKey('@$key')) {
        final placeholders = arb['@$key']['placeholders'];
        if (placeholders != null && placeholders.isNotEmpty) {
          hasPlaceholder = true;
          paramNames = placeholders.keys.toList();
          break;
        }
      }
    }

    if (hasPlaceholder) {
      final paramsPass = paramNames
          .map((p) => "params?['$p'] ?? ''")
          .join(', ');
      buffer.writeln("      case '$key': return t.$key($paramsPass);");
    } else {
      buffer.writeln("      case '$key': return t.$key;");
    }
  }

  buffer.writeln('''
    }

    return key;
  }

  // -----------------------------------------
  // 3. TRẢ VỀ { vi: x, ja: y }
  // -----------------------------------------
  Map<String, String> multiLang(BuildContext context, String key,
      {Map<String, dynamic>? params}) {
    return {
      'vi': _trLocale(key, const Locale('vi'), params: params),
      'ja': _trLocale(key, const Locale('ja'), params: params),
    };
  }

  // -----------------------------------------
  // 4. TRẢ VỀ "VI\\nJA"
  // -----------------------------------------
  String combinedViJa(BuildContext context, String key,
      {Map<String, dynamic>? params}) {
    final vi = _trLocale(key, const Locale('vi'), params: params);
    final ja = _trLocale(key, const Locale('ja'), params: params);
    return "\$vi\\n\$ja";
  }
}
''');

  final output = File('lib/translator.dart');
  await output.writeAsString(buffer.toString());

  print("🎉 DONE: lib/translator.dart generated with VI/JA support!");
}
