import 'package:chuphinh/model/fixed_asset_machine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  bool parse(Object? value, {bool include = true}) =>
      FixedAssetMachine.fromJson({
        'machineCode': ' A-1456 ',
        'faName': 'Sprue Bush',
        if (include) 'auditedInPeriod': value,
      }).auditedInPeriod;

  test('auditedInPeriod accepts bool, "true"/"1" and 1', () {
    expect(parse(true), isTrue);
    expect(parse('true'), isTrue);
    expect(parse(' TRUE '), isTrue);
    expect(parse('1'), isTrue);
    expect(parse(1), isTrue);
  });

  test('auditedInPeriod false / missing / unknown -> false', () {
    expect(parse(false), isFalse);
    expect(parse('false'), isFalse);
    expect(parse('0'), isFalse);
    expect(parse(0), isFalse);
    expect(parse(null), isFalse);
    expect(parse('yes'), isFalse);
    expect(parse(null, include: false), isFalse); // older backend
  });

  test('other fields unchanged', () {
    final m = FixedAssetMachine.fromJson({
      'machineCode': ' A-1456 ',
      'faName': ' Sprue Bush ',
    });
    expect(m.machineCode, 'A-1456');
    expect(m.faName, 'Sprue Bush');
    expect(m.auditedInPeriod, isFalse);
  });
}
