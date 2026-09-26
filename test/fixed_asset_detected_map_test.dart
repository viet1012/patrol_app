import 'package:chuphinh/fixedAsset/map/fixed_asset_detected_map.dart';
import 'package:chuphinh/fixedAsset/map/floor_map_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpDetectedMap(
    WidgetTester tester, {
    String? fac,
    String? floor,
    String? positionA,
    String? positionAA,
    double width = 800,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            child: FixedAssetDetectedMap(
              fac: fac,
              floor: floor,
              positionA: positionA,
              positionAA: positionAA,
            ),
          ),
        ),
      ),
    );
  }

  // The selected-polygon highlight loops forever, so pumpAndSettle would
  // never settle; pump past the dialog transition instead.
  Future<void> pumpTransition(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  FloorMapWidget renderedMap(WidgetTester tester) {
    return tester.widget<FloorMapWidget>(find.byType(FloorMapWidget));
  }

  testWidgets('null inputs render no map', (tester) async {
    await pumpDetectedMap(tester);
    expect(find.byType(FloorMapWidget), findsNothing);
  });

  final layoutCases = <({String positionA, String floor, String title})>[
    (positionA: 'A1', floor: '1F', title: 'Floor 1 - Press'),
    (positionA: 'A12', floor: '1F', title: 'Floor 1 - Guide'),
    (positionA: 'A22', floor: '1F', title: 'Floor 1 - Warehouse (WH)'),
    (positionA: 'A30', floor: '1F', title: 'Floor 1 - Mold'),
    (positionA: 'A40', floor: '2F', title: 'Floor 2 - All'),
  ];

  for (final testCase in layoutCases) {
    testWidgets('${testCase.positionA} renders ${testCase.title}', (
      tester,
    ) async {
      await pumpDetectedMap(
        tester,
        fac: 'Factory 2',
        floor: testCase.floor,
        positionA: testCase.positionA,
      );

      expect(find.byType(FloorMapWidget), findsOneWidget);
      expect(renderedMap(tester).data.title, testCase.title);
    });
  }

  testWidgets('passes exact parent and child selection to renderer', (
    tester,
  ) async {
    await pumpDetectedMap(
      tester,
      fac: 'Factory 2',
      floor: '1F',
      positionA: 'A14',
      positionAA: 'A14-3',
    );

    final map = renderedMap(tester);
    expect(map.selectedParentZone, 'A14');
    expect(map.selectedChildZone, 'A14-3');
  });

  testWidgets('unknown PositionA renders no map', (tester) async {
    await pumpDetectedMap(
      tester,
      fac: 'Factory 2',
      floor: '1F',
      positionA: 'A99',
    );
    expect(find.byType(FloorMapWidget), findsNothing);
  });

  testWidgets('PositionAA-only input does not infer a parent', (tester) async {
    await pumpDetectedMap(
      tester,
      fac: 'Factory 2',
      floor: '1F',
      positionAA: 'A35-1',
    );
    expect(find.byType(FloorMapWidget), findsNothing);
  });

  testWidgets('resolved ACTUAL mismatch fields render their map', (
    tester,
  ) async {
    await pumpDetectedMap(
      tester,
      fac: 'Factory 2',
      floor: '1F',
      positionA: 'A31',
      positionAA: 'A31-4',
    );

    final map = renderedMap(tester);
    expect(map.data.title, 'Floor 1 - Mold');
    expect(map.selectedParentZone, 'A31');
    expect(map.selectedChildZone, 'A31-4');
  });

  testWidgets('changed location inputs replace the previous map selection', (
    tester,
  ) async {
    await pumpDetectedMap(
      tester,
      fac: 'Factory 2',
      floor: '1F',
      positionA: 'A31',
      positionAA: 'A31-4',
    );
    expect(renderedMap(tester).data.title, 'Floor 1 - Mold');

    await pumpDetectedMap(
      tester,
      fac: 'Factory 2',
      floor: '1F',
      positionA: 'A12',
      positionAA: 'A12-2',
    );

    final map = renderedMap(tester);
    expect(map.data.title, 'Floor 1 - Guide');
    expect(map.selectedParentZone, 'A12');
    expect(map.selectedChildZone, 'A12-2');
  });

  for (final width in <double>[360, 390, 430, 900]) {
    testWidgets('renders without overflow at ${width.toInt()} px', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpDetectedMap(
        tester,
        width: width,
        fac: 'Fac_C',
        floor: '1F',
        positionA: 'A35',
        positionAA: 'A35-1',
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Floor 1 - Mold'), findsOneWidget);
      expect(find.text('A35-1'), findsWidgets);
    });
  }

  testWidgets('embedded map with child shows only the parent context', (
    tester,
  ) async {
    await pumpDetectedMap(
      tester,
      fac: 'Fac_C',
      floor: '1F',
      positionA: 'A35',
      positionAA: 'A35-1',
    );

    expect(renderedMap(tester).focusParentZone, 'A35');
    final map = find.byType(FloorMapWidget);
    for (final code in <String>['A35', 'A35-1', 'A35-2']) {
      expect(
        find.descendant(of: map, matching: find.text(code)),
        findsOneWidget,
      );
    }
    for (final code in <String>['A31', 'A34', 'A36', 'A31-4']) {
      expect(find.descendant(of: map, matching: find.text(code)), findsNothing);
    }
  });

  testWidgets('embedded map with parent only shows all its children', (
    tester,
  ) async {
    await pumpDetectedMap(tester, fac: 'Fac_C', floor: '1F', positionA: 'A35');

    final map = find.byType(FloorMapWidget);
    expect(renderedMap(tester).selectedChildZone, isNull);
    for (final code in <String>['A35', 'A35-1', 'A35-2']) {
      expect(
        find.descendant(of: map, matching: find.text(code)),
        findsOneWidget,
      );
    }
    expect(find.descendant(of: map, matching: find.text('A36')), findsNothing);
  });

  testWidgets('expanded map opens focused and can show all', (tester) async {
    await pumpDetectedMap(
      tester,
      fac: 'Fac_C',
      floor: '1F',
      positionA: 'A35',
      positionAA: 'A35-1',
    );

    await tester.tap(find.byIcon(Icons.open_in_full_rounded));
    await pumpTransition(tester);

    Finder expanded() => find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(FloorMapWidget),
    );
    expect(tester.widget<FloorMapWidget>(expanded()).focusParentZone, 'A35');
    expect(
      find.descendant(of: expanded(), matching: find.text('A36')),
      findsNothing,
    );

    await tester.tap(find.byIcon(Icons.layers_rounded));
    await pumpTransition(tester);
    expect(tester.widget<FloorMapWidget>(expanded()).focusParentZone, isNull);
    expect(
      find.descendant(of: expanded(), matching: find.text('A36')),
      findsOneWidget,
    );
  });

  for (final c in <({String fac, String floor, String a, String aa})>[
    (fac: 'Factory 2', floor: '1F', a: 'A1', aa: 'A1-1'),
    (fac: 'Fac_C', floor: '1F', a: 'A35', aa: 'A35-1'),
    (fac: 'Factory 2', floor: '2F', a: 'A42', aa: 'A42-1'),
  ]) {
    testWidgets('fullscreen ${c.a} is framed large on a phone', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpDetectedMap(
        tester,
        width: 390,
        fac: c.fac,
        floor: c.floor,
        positionA: c.a,
        positionAA: c.aa,
      );
      await tester.tap(find.byIcon(Icons.open_in_full_rounded));
      await pumpTransition(tester);
      expect(tester.takeException(), isNull);

      final viewer = find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(InteractiveViewer),
      );
      final view = tester.getRect(viewer);
      // Map viewport uses nearly the full dialog below the compact header.
      expect(view.height, greaterThan(844 - 42 - 40));
      final scale = tester
          .widget<InteractiveViewer>(viewer)
          .transformationController!
          .value
          .getMaxScaleOnAxis();
      final badge = tester.getCenter(
        find.descendant(of: viewer, matching: find.text(c.a)),
      );
      expect(scale, greaterThan(1.5));
      expect(view.contains(badge), isTrue);
      expect(
        (badge - view.center).distance,
        lessThan(view.shortestSide * 0.25),
      );
    });
  }

  testWidgets('expand action opens and closes a fullscreen map', (
    tester,
  ) async {
    await pumpDetectedMap(
      tester,
      fac: 'Fac_C',
      floor: '1F',
      positionA: 'A35',
      positionAA: 'A35-1',
    );

    await tester.tap(find.byIcon(Icons.open_in_full_rounded));
    await pumpTransition(tester);
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(FloorMapWidget), findsNWidgets(2));

    await tester.tap(find.byIcon(Icons.close_rounded));
    await pumpTransition(tester);
    expect(find.byType(Dialog), findsNothing);
  });

  group('embedded collapse', () {
    Rect mapRect(WidgetTester tester) =>
        tester.getRect(find.byType(FloorMapWidget).first);

    for (final width in <double>[360, 390, 430]) {
      testWidgets('collapses to header and back at ${width.toInt()} px', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await pumpDetectedMap(
          tester,
          width: width,
          fac: 'Fac_C',
          floor: '1F',
          positionA: 'A35',
          positionAA: 'A35-1',
        );
        final cardFinder = find.byType(FixedAssetDetectedMap);
        final expandedHeight = tester.getSize(cardFinder).height;
        final state = tester.state(find.byType(FloorMapWidget));

        await tester.tap(find.byIcon(Icons.keyboard_arrow_up_rounded));
        await pumpTransition(tester);
        expect(tester.takeException(), isNull);
        expect(tester.getSize(cardFinder).height, lessThan(50));
        expect(renderedMap(tester).enablePolygonAnimation, isFalse);

        // New location while collapsed: header updates, stays collapsed.
        await pumpDetectedMap(
          tester,
          width: width,
          fac: 'Fac_C',
          floor: '1F',
          positionA: 'A31',
          positionAA: 'A31-4',
        );
        await tester.pump();
        expect(tester.getSize(cardFinder).height, lessThan(50));
        expect(find.text('A31-4'), findsWidgets);

        await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
        await pumpTransition(tester);
        expect(tester.takeException(), isNull);
        expect(tester.getSize(cardFinder).height, closeTo(expandedHeight, 1));
        expect(renderedMap(tester).enablePolygonAnimation, isTrue);
        // Same FloorMapWidget state: zoom/pan was not recreated.
        expect(tester.state(find.byType(FloorMapWidget)), same(state));
        expect(mapRect(tester).height, greaterThan(100));
      });
    }
  });
}
