import 'package:chuphinh/fixedAsset/map/floor_map_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('fixed asset floor map metadata', () {
    test('contains five unique layouts and asset references', () {
      expect(fixedAssetFloorMaps, hasLength(5));
      expect(
        fixedAssetFloorMaps.map((map) => map.id).toSet(),
        hasLength(fixedAssetFloorMaps.length),
      );
      expect(fixedAssetFloorMaps.map((map) => map.imageAsset).toSet(), <String>{
        'assets/maps/floor1-press.png',
        'assets/maps/floor1-guide.png',
        'assets/maps/floor1-warehouse.png',
        'assets/maps/floor1-mold.png',
        'assets/maps/floor2-all.png',
      });
    });

    test('has unique in-range zones and polygons', () {
      for (final map in fixedAssetFloorMaps) {
        expect(
          map.zones.map((zone) => zone.code).toSet(),
          hasLength(map.zones.length),
          reason: map.id,
        );
        for (final zone in map.zones) {
          expect(zone.x, inInclusiveRange(0, 100), reason: zone.code);
          expect(zone.y, inInclusiveRange(0, 100), reason: zone.code);
        }
        for (final area in map.areas) {
          for (final point in area.points) {
            expect(point.x, inInclusiveRange(0, 100), reason: area.code);
            expect(point.y, inInclusiveRange(0, 100), reason: area.code);
          }
        }
      }
    });

    test('represents every major area A1 through A43 exactly once', () {
      final codes = fixedAssetFloorMaps
          .expand((map) => map.areas)
          .map((area) => area.code)
          .toList();
      expect(codes.toSet(), hasLength(codes.length));
      expect(codes.toSet(), <String>{for (var i = 1; i <= 43; i++) 'A$i'});
    });
  });

  group('fixed asset floor map resolver', () {
    for (final testCase
        in <
          ({
            String fac,
            String floor,
            String positionA,
            String? positionAA,
            String title,
          })
        >[
          (
            fac: 'Fac_A',
            floor: '1F',
            positionA: 'A1',
            positionAA: null,
            title: 'Floor 1 - Press',
          ),
          (
            fac: 'Fac_B',
            floor: '1F',
            positionA: 'A12',
            positionAA: null,
            title: 'Floor 1 - Guide',
          ),
          (
            fac: 'Fac_C',
            floor: '1F',
            positionA: 'A22',
            positionAA: null,
            title: 'Floor 1 - Warehouse (WH)',
          ),
          (
            fac: 'Fac_C',
            floor: '1F',
            positionA: 'A35',
            positionAA: 'A35-1',
            title: 'Floor 1 - Mold',
          ),
          (
            fac: 'Fac_C',
            floor: '2F',
            positionA: 'A42',
            positionAA: null,
            title: 'Floor 2 - All',
          ),
        ]) {
      test(
        '${testCase.fac} + ${testCase.floor} + ${testCase.positionA} resolves ${testCase.title}',
        () {
          final map = resolveFixedAssetFloorMap(
            fac: testCase.fac,
            floor: testCase.floor,
            positionA: testCase.positionA,
            positionAA: testCase.positionAA,
          );
          expect(map?.title, testCase.title);
        },
      );
    }

    test('unknown PositionA returns null', () {
      expect(
        resolveFixedAssetFloorMap(fac: 'Fac_C', floor: '1F', positionA: 'A99'),
        isNull,
      );
    });

    test('missing floor returns null', () {
      expect(
        resolveFixedAssetFloorMap(fac: 'Fac_C', floor: null, positionA: 'A1'),
        isNull,
      );
    });

    test('unsupported floor returns null', () {
      expect(
        resolveFixedAssetFloorMap(fac: 'Fac_C', floor: '3F', positionA: 'A35'),
        isNull,
      );
    });

    test('does not infer a parent from PositionAA', () {
      expect(
        resolveFixedAssetMapSelection(
          fac: 'Fac_C',
          floor: '1F',
          positionA: null,
          positionAA: 'A35-1',
        ),
        isNull,
      );
    });

    test('selection uses exact parent and child lookups', () {
      final selection = resolveFixedAssetMapSelection(
        fac: 'Fac_B',
        floor: '1F',
        positionA: 'A14',
        positionAA: 'A14-3',
      );
      expect(selection?.parentZoneCode, 'A14');
      expect(selection?.childZoneCode, 'A14-3');
    });
  });
}
