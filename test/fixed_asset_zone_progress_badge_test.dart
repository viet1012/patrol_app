import 'package:chuphinh/fixedAsset/map/fixed_asset_detected_map.dart';
import 'package:chuphinh/fixedAsset/map/floor_map_widget.dart';
import 'package:chuphinh/model/fixed_asset_zone_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fac_C/1F sample (same numbers as the zone-progress API check).
final Map<String, ZoneProgress> _facC1F = buildZoneProgressMap(const [
  FixedAssetZoneProgressRow(
    positionA: 'A30',
    positionAA: 'A30',
    total: 7,
    audited: 0,
  ),
  FixedAssetZoneProgressRow(
    positionA: 'A32',
    positionAA: 'A32-1',
    total: 24,
    audited: 0,
  ),
  FixedAssetZoneProgressRow(
    positionA: 'A32',
    positionAA: 'A32-2',
    total: 36,
    audited: 3,
  ),
  FixedAssetZoneProgressRow(
    positionA: 'A35',
    positionAA: 'A35-1',
    total: 24,
    audited: 1,
  ),
  FixedAssetZoneProgressRow(
    positionA: 'A35',
    positionAA: 'A35-2',
    total: 43,
    audited: 0,
  ),
]);

void main() {
  Future<void> pumpMap(
    WidgetTester tester, {
    required String positionA,
    String? positionAA,
    Map<String, ZoneProgress>? zoneProgress,
    double width = 800,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            child: FixedAssetDetectedMap(
              fac: 'Fac_C',
              floor: '1F',
              positionA: positionA,
              positionAA: positionAA,
              zoneProgress: zoneProgress,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('A35-1 focus: badge counts, header line, map fills card', (
    tester,
  ) async {
    await pumpMap(
      tester,
      positionA: 'A35',
      positionAA: 'A35-1',
      zoneProgress: _facC1F,
    );
    await tester.pump();

    expect(find.text('1/24'), findsOneWidget); // A35-1 badge
    expect(find.text('0/43'), findsOneWidget); // A35-2 badge
    expect(find.text('1/67'), findsOneWidget); // A35 badge
    expect(find.text('1/24 máy · 4%'), findsOneWidget); // header (target)

    // Card border 1px each side: the map spans the full inner width.
    expect(tester.getSize(find.byType(FloorMapWidget)).width, 798);
  });

  testWidgets('A32-2 focus: parent sums children', (tester) async {
    await pumpMap(
      tester,
      positionA: 'A32',
      positionAA: 'A32-2',
      zoneProgress: _facC1F,
    );
    await tester.pump();

    expect(find.text('3/60'), findsOneWidget); // A32
    expect(find.text('3/36'), findsOneWidget); // A32-2
    expect(find.text('0/24'), findsOneWidget); // A32-1
    expect(find.text('3/36 máy · 8%'), findsOneWidget);
  });

  testWidgets('A30 (parent without children) and a finished zone', (
    tester,
  ) async {
    await pumpMap(tester, positionA: 'A30', zoneProgress: _facC1F);
    await tester.pump();
    expect(find.text('0/7'), findsOneWidget);
    expect(find.text('0/7 máy · 0%'), findsOneWidget);

    // 100% but it is the target (solid select style): no check mark.
    await pumpMap(
      tester,
      positionA: 'A30',
      zoneProgress: const {'A30': ZoneProgress(audited: 7, total: 7)},
    );
    await tester.pump();
    expect(find.text('A30'), findsNWidgets(2)); // badge + header
    expect(find.text('✓ A30'), findsNothing);

    // 100% child that is not the target: green with a check mark.
    await pumpMap(
      tester,
      positionA: 'A35',
      positionAA: 'A35-1',
      zoneProgress: buildZoneProgressMap(const [
        FixedAssetZoneProgressRow(
          positionA: 'A35',
          positionAA: 'A35-2',
          total: 43,
          audited: 43,
        ),
      ]),
    );
    await tester.pump();
    expect(find.text('✓ A35-2'), findsOneWidget);
  });

  testWidgets('no zoneProgress: code-only badges, no header line', (
    tester,
  ) async {
    await pumpMap(tester, positionA: 'A35', positionAA: 'A35-1');
    await tester.pump();
    expect(find.text('A35-1'), findsWidgets);
    expect(find.textContaining('/'), findsNothing);
    expect(find.textContaining('máy'), findsNothing);
  });
}
