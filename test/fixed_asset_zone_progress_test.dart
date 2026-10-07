import 'package:chuphinh/core/models/fixed_asset_zone_progress.dart';
import 'package:flutter_test/flutter_test.dart';

FixedAssetZoneProgressRow row(String a, String aa, int audited, int total) =>
    FixedAssetZoneProgressRow(
      positionA: a,
      positionAA: aa,
      total: total,
      audited: audited,
    );

void main() {
  group('buildZoneProgressMap (Fac_C/1F sample)', () {
    final map = buildZoneProgressMap([
      row('A30', 'A30', 0, 7),
      row('A32', 'A32-1', 0, 24),
      row('A32', 'A32-2', 3, 36),
      row('A35', 'A35-1', 1, 24),
      row('A35', 'A35-2', 0, 43),
    ]);

    test('parent without children uses positionA only', () {
      expect(map['A30'], const ZoneProgress(audited: 0, total: 7));
    });

    test('parent sums its children; children keyed by positionAA', () {
      expect(map['A32'], const ZoneProgress(audited: 3, total: 60));
      expect(map['A32-1'], const ZoneProgress(audited: 0, total: 24));
      expect(map['A32-2'], const ZoneProgress(audited: 3, total: 36));
      expect(map['A35'], const ZoneProgress(audited: 1, total: 67));
      expect(map['A35-1'], const ZoneProgress(audited: 1, total: 24));
      expect(map['A35-2'], const ZoneProgress(audited: 0, total: 43));
    });

    test('exactly the expected keys, unmodifiable', () {
      expect(
        map.keys.toSet(),
        {'A30', 'A32', 'A32-1', 'A32-2', 'A35', 'A35-1', 'A35-2'},
      );
      expect(() => (map as Map)['X'] = ZoneProgress.empty, throwsA(anything));
    });
  });

  test('rows with total <= 0 or empty positionA are dropped', () {
    final map = buildZoneProgressMap([
      row('A40', 'A40-1', 0, 0),
      row('A40', 'A40-2', 2, -1),
      row('', 'A41', 1, 5),
      row('A42', 'A42-1', 1, 4),
    ]);
    expect(map.keys.toSet(), {'A42', 'A42-1'});
    expect(map['A42'], const ZoneProgress(audited: 1, total: 4));
  });

  test('audited is clamped to 0..total', () {
    final map = buildZoneProgressMap([
      row('A43', 'A43', 9, 5),
      row('A44', 'A44-1', -3, 5),
    ]);
    expect(map['A43'], const ZoneProgress(audited: 5, total: 5));
    expect(map['A44'], const ZoneProgress(audited: 0, total: 5));
    expect(map['A44-1'], const ZoneProgress(audited: 0, total: 5));
  });

  group('ZoneProgress', () {
    test('ratio / percent / remaining / isDone', () {
      const p = ZoneProgress(audited: 1, total: 24);
      expect(p.remaining, 23);
      expect(p.percent, 4);
      expect(p.isDone, isFalse);
      expect(const ZoneProgress(audited: 7, total: 7).isDone, isTrue);
      expect(ZoneProgress.empty.ratio, 0);
      expect(ZoneProgress.empty.isDone, isFalse);
    });

    test('operator +', () {
      expect(
        const ZoneProgress(audited: 1, total: 2) +
            const ZoneProgress(audited: 3, total: 4),
        const ZoneProgress(audited: 4, total: 6),
      );
    });
  });

  test('FixedAssetZoneProgressRow.fromJson trims and parses num/string', () {
    final r = FixedAssetZoneProgressRow.fromJson({
      'positionA': ' A35 ',
      'positionAA': 'A35-1 ',
      'total': '24',
      'audited': 1.0,
    });
    expect(r.positionA, 'A35');
    expect(r.positionAA, 'A35-1');
    expect(r.total, 24);
    expect(r.audited, 1);
    final bad = FixedAssetZoneProgressRow.fromJson({'total': 'x'});
    expect(bad.total, 0);
    expect(bad.audited, 0);
  });
}
