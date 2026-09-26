import 'dart:ui';

import 'package:flutter/material.dart' hide Canvas, Offset, Size;

import 'package:chuphinh/fixedAsset/map/floor_map_data.dart';
import 'package:chuphinh/fixedAsset/map/floor_map_models.dart';
import 'package:chuphinh/fixedAsset/map/floor_map_painter.dart';
import 'package:chuphinh/fixedAsset/map/floor_map_widget.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FloorMapPainter', () {
    test('converts percentage points into scene coordinates', () {
      final offset = mapPointToOffset(
        const MapPoint(x: 25, y: 75),
        const Size(400, 200),
      );

      expect(offset, const Offset(100, 150));
    });

    test('selects only the exact parent polygon', () {
      final area = fixedAssetFloorMaps.first.areas.first;

      expect(isSelectedMapArea(area, area.code), isTrue);
      expect(isSelectedMapArea(area, '${area.code}-1'), isFalse);
      expect(isSelectedMapArea(area, null), isFalse);
    });

    test('painting does not mutate source area data', () {
      final map = fixedAssetFloorMaps.first;
      final before = <String>[
        for (final area in map.areas)
          for (final point in area.points) '${area.code}:${point.x}:${point.y}',
      ];
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      FloorMapPainter(
        areas: map.areas,
        selectedParentZone: 'A1',
        selectedChildZone: 'A1-1',
      ).paint(canvas, const Size(1226, 718));
      recorder.endRecording();

      final after = <String>[
        for (final area in map.areas)
          for (final point in area.points) '${area.code}:${point.x}:${point.y}',
      ];
      expect(after, before);
    });
  });

  group('FloorMapWidget helpers', () {
    test('uses original aspect for unrotated layouts', () {
      final press = fixedAssetFloorMaps.first;
      expect(
        floorMapDisplayAspectRatio(press),
        press.imageWidth / press.imageHeight,
      );
    });

    test('swaps display aspect for the rotated Mold layout', () {
      final mold = fixedAssetFloorMaps.firstWhere(
        (map) => map.title == 'Floor 1 - Mold',
      );
      expect(isQuarterTurnMapRotation(mold.rotationDeg), isTrue);
      expect(
        floorMapDisplayAspectRatio(mold),
        mold.imageHeight / mold.imageWidth,
      );
    });

    test('focus relationship uses exact parent code prefix', () {
      expect(isFocusRelatedZoneCode('A35', 'A35'), isTrue);
      expect(isFocusRelatedZoneCode('A35-1', 'A35'), isTrue);
      expect(isFocusRelatedZoneCode('A35-12', 'A35'), isTrue);
      expect(isFocusRelatedZoneCode('A351', 'A35'), isFalse);
      expect(isFocusRelatedZoneCode('A3', 'A35'), isFalse);
      expect(isFocusRelatedZoneCode('A36', 'A35'), isFalse);
      expect(isFocusRelatedZoneCode('A31-2', 'A35'), isFalse);
    });

    test('identifies major markers by exact area membership', () {
      final press = fixedAssetFloorMaps.first;
      final parent = press.zones.firstWhere((zone) => zone.code == 'A1');
      final child = press.zones.firstWhere((zone) => zone.code == 'A1-1');

      expect(isMajorMapZone(press, parent), isTrue);
      expect(isMajorMapZone(press, child), isFalse);
    });
  });

  group('Expanded auto-focus', () {
    FloorMapData mapFor(String code) =>
        fixedAssetFloorMaps.firstWhere((m) => m.positionACodes.contains(code));

    test('falls back to full floor without a parent polygon', () {
      final map = mapFor('A35');
      expect(floorMapFocusMatrix(map, null, const Size(400, 600)), isNull);
      expect(floorMapFocusMatrix(map, 'A99', const Size(400, 600)), isNull);
      expect(floorMapFocusMatrix(map, 'A35', Size.zero), isNull);
    });

    for (final code in <String>['A35', 'A31', 'A42']) {
      testWidgets('$code opens zoomed onto its rendered polygon', (
        tester,
      ) async {
        final map = mapFor(code);
        const viewport = Size(390, 700);
        await tester.binding.setSurfaceSize(viewport);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final aspect = floorMapDisplayAspectRatio(map);
        final width = viewport.width;
        final height = width / aspect;

        await tester.pumpWidget(
          MaterialApp(
            home: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                height: height,
                child: FloorMapWidget(
                  data: map,
                  selectedParentZone: code,
                  autoFocusParent: true,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final matrix = tester
            .widget<InteractiveViewer>(find.byType(InteractiveViewer))
            .transformationController!
            .value;
        expect(matrix.getMaxScaleOnAxis(), greaterThan(1.0));

        // The parent badge sits inside its polygon: after focus it must be
        // on-screen, validating the rotation/projection against real layout.
        final badge = tester.getCenter(find.text(code));
        expect(badge.dx, inInclusiveRange(0, width));
        expect(badge.dy, inInclusiveRange(0, height));
        // Parent badges sit at their polygon centre, so a correct focus puts
        // them near the viewport centre (unless clamped at a floor edge).
        expect(badge.dx, closeTo(width / 2, width * 0.1));
        expect(badge.dy, closeTo(height / 2, height * 0.1));

        // Rebuilds with the same parent do not reset a manual transform.
        final controller = tester
            .widget<InteractiveViewer>(find.byType(InteractiveViewer))
            .transformationController!;
        controller.value = Matrix4.identity();
        await tester.pumpWidget(
          MaterialApp(
            home: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                height: height,
                child: FloorMapWidget(
                  data: map,
                  selectedParentZone: code,
                  selectedChildZone: '$code-1',
                  autoFocusParent: true,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(controller.value, Matrix4.identity());
      });
    }
  });

  group('Selected polygon highlight', () {
    final press = fixedAssetFloorMaps.first;

    Future<bool> animating(
      WidgetTester tester, {
      String? parent,
      bool reduceMotion = false,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduceMotion),
            child: SizedBox(
              width: 400,
              height: 240,
              child: FloorMapWidget(data: press, selectedParentZone: parent),
            ),
          ),
        ),
      );
      return tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<SelectedAreaHighlightPainter>()
          .isNotEmpty;
    }

    testWidgets('animates only when a parent polygon is selected', (
      tester,
    ) async {
      expect(await animating(tester, parent: 'A1'), isTrue);
      expect(await animating(tester), isFalse);
      expect(await animating(tester, parent: 'A99'), isFalse);
    });

    testWidgets('respects reduced motion', (tester) async {
      expect(
        await animating(tester, parent: 'A1', reduceMotion: true),
        isFalse,
      );
    });
  });
}
