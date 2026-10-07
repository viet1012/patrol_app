import 'package:chuphinh/features/fixed_asset/map/floor_map_models.dart';

MapArea rectArea(
  String code,
  double left,
  double top,
  double right,
  double bottom,
) {
  return MapArea(
    code: code,
    points: <MapPoint>[
      MapPoint(x: left, y: top),
      MapPoint(x: right, y: top),
      MapPoint(x: right, y: bottom),
      MapPoint(x: left, y: bottom),
    ],
  );
}

/// Child sub-area rectangle, shrunk by [inset] (percent) on every side so
/// its outline never overlaps the parent outline drawn on the same edge.
MapArea childRectArea(
  String code,
  double left,
  double top,
  double right,
  double bottom, {
  double inset = 0.35,
}) {
  return rectArea(
    code,
    left + inset,
    top + inset,
    right - inset,
    bottom - inset,
  );
}

final List<MapArea> _floor1PressAreas = <MapArea>[
  rectArea('A1', 27.37, 30.97, 46.30, 62.87),
  rectArea('A2', 47.80, 29.12, 70.20, 62.87),
  rectArea('A3', 70.76, 29.58, 94.10, 63.02),
  rectArea('A4', 27.09, 64.71, 46.67, 91.06),
  rectArea('A5', 47.89, 64.71, 70.29, 89.52),
  rectArea('A6', 70.76, 64.71, 93.72, 89.52),
  rectArea('A7', 19.59, 62.87, 25.77, 91.06),
  rectArea('A8', 48.08, 90.14, 63.92, 97.69),
  rectArea('A9', 2.25, 5.70, 19.31, 99.08),
  rectArea('A10', 19.21, 5.70, 99.25, 28.20),
  rectArea('A11', 93.63, 28.20, 99.25, 93.99),
];

/// Child sub-area rectangles (left, top, right, bottom) in image percent,
/// un-inset. Single source for both the drawn and the hit-test polygons.
typedef _ChildRect = (String, double, double, double, double);

const List<_ChildRect> _floor1PressChildRects = <_ChildRect>[
  ('A1-1', 27.37, 30.97, 46.30, 47.78),
  ('A1-2', 27.37, 47.78, 46.30, 62.87),
  ('A2-1', 47.80, 29.12, 70.20, 47.48),
  ('A2-2', 47.80, 47.48, 56.96, 62.87),
  ('A2-3', 56.96, 47.48, 70.20, 62.87),
  ('A3-1', 70.76, 29.58, 94.10, 46.30),
  ('A3-2', 70.76, 46.30, 80.66, 63.02),
  ('A3-3', 80.66, 46.30, 94.10, 63.02),
  ('A4-1', 27.09, 64.71, 37.23, 91.06),
  ('A4-2', 37.23, 64.71, 46.67, 91.06),
  ('A5-1', 47.89, 64.71, 70.29, 78.03),
  ('A5-2', 47.89, 78.03, 70.29, 89.52),
  ('A6-1', 70.76, 64.71, 84.60, 76.94),
  ('A6-2', 84.60, 64.71, 93.72, 76.94),
  ('A6-3', 70.76, 76.94, 84.60, 89.52),
  ('A6-4', 84.60, 76.94, 93.72, 89.52),
];

const double _childInset = 0.35;
const double _edgeTolerance = 0.01;

/// Drawn polygons: only edges lying on the parent outline (coordinate equal
/// to one of the parent's point x/y values, ±[_edgeTolerance]) are inset, so
/// child outlines never overlap the parent outline while shared sibling
/// edges stay a single line. Parent = code before the last '-'; a child
/// whose parent is missing from [parents] is inset on every side.
List<MapArea> _childDrawAreas(
  List<_ChildRect> rects,
  List<MapArea> parents,
) {
  return <MapArea>[
    for (final (code, l, t, r, b) in rects)
      _insetOnParentEdges(code, l, t, r, b, parents),
  ];
}

MapArea _insetOnParentEdges(
  String code,
  double left,
  double top,
  double right,
  double bottom,
  List<MapArea> parents,
) {
  final parentCode = code.substring(0, code.lastIndexOf('-'));
  MapArea? parent;
  for (final area in parents) {
    if (area.code == parentCode) {
      parent = area;
      break;
    }
  }
  if (parent == null) return childRectArea(code, left, top, right, bottom);

  final xs = parent.points.map((point) => point.x);
  final ys = parent.points.map((point) => point.y);
  bool onParent(Iterable<double> values, double value) =>
      values.any((v) => (v - value).abs() <= _edgeTolerance);
  double inset(Iterable<double> values, double value) =>
      onParent(values, value) ? _childInset : 0;

  return rectArea(
    code,
    left + inset(xs, left),
    top + inset(ys, top),
    right - inset(xs, right),
    bottom - inset(ys, bottom),
  );
}

/// Hit-test polygons: exact rectangles, so the inset gap between sibling
/// children still resolves to a child instead of the parent.
List<MapArea> _childHitAreas(List<_ChildRect> rects) => <MapArea>[
  for (final (code, l, t, r, b) in rects) rectArea(code, l, t, r, b),
];

/// Child polygons per map id. Kept out of [FloorMapData.areas], which holds
/// parent areas only (parent resolution, focus matrix, major zones, painter).
final Map<String, List<MapArea>> _childAreasByMapId = <String, List<MapArea>>{
  'floor1': _childDrawAreas(_floor1PressChildRects, _floor1PressAreas),
  'floor2': _floor1GuideChildAreas,
  'floor4': _floor1MoldChildAreas,
  'floor5': _childDrawAreas(_floor2AllChildRects, _floor2AllAreas),
};

/// Same codes and order as [_childAreasByMapId], without the inset.
final Map<String, List<MapArea>> _childHitAreasByMapId =
    <String, List<MapArea>>{
      'floor1': _childHitAreas(_floor1PressChildRects),
      'floor2': _floor1GuideChildHitAreas,
      'floor4': _floor1MoldChildHitAreas,
      'floor5': _childHitAreas(_floor2AllChildRects),
    };

final List<MapArea> _floor1GuideAreas = <MapArea>[
  rectArea('A12', 23.04, 12.54, 47.57, 49.27),
  rectArea('A13', 48.22, 12.54, 81.44, 49.42),
  rectArea('A14', 23.04, 50.15, 47.57, 88.92),
  rectArea('A15', 48.22, 50.15, 81.44, 88.92),
  rectArea('A16', 82.41, 21.28, 94.09, 88.92),
  rectArea('A17', 0.39, 12.54, 22.32, 98.40),
  rectArea('A18', 0.39, 1.75, 99.48, 11.22),
  rectArea('A19', 82.41, 12.54, 94.09, 20.85),
  rectArea('A20', 94.09, 12.24, 99.55, 88.92),
  rectArea('A21', 23.04, 88.92, 99.48, 98.54),
];

// A18–A21 have no children. A17-4 is an L-shape, declared separately below.
const List<_ChildRect> _floor1GuideChildRects = <_ChildRect>[
  ('A12-1', 23.04, 12.54, 33.07, 49.27),
  ('A12-2', 33.07, 12.54, 47.57, 49.27),
  ('A13-1', 48.22, 12.54, 64.37, 49.42),
  ('A13-2', 64.37, 12.54, 81.44, 49.42),
  ('A14-1', 23.04, 50.15, 33.07, 88.92),
  ('A14-2', 33.07, 50.15, 47.57, 66.55),
  ('A14-3', 33.07, 66.55, 47.57, 88.92),
  ('A15-1', 48.22, 50.15, 64.50, 66.12),
  ('A15-2', 64.50, 50.15, 81.44, 66.12),
  ('A15-3', 48.22, 66.12, 67.42, 88.92),
  ('A15-4', 67.42, 66.12, 81.44, 88.92),
  ('A16-1', 82.41, 21.28, 94.09, 33.12),
  ('A16-2', 82.41, 33.12, 94.09, 88.92),
  ('A17-1', 5.43, 12.54, 18.39, 23.49),
  ('A17-2', 5.43, 23.49, 18.39, 54.89),
  ('A17-3', 5.43, 54.89, 18.39, 70.36),
  ('A17-5', 10.01, 70.36, 18.39, 98.40),
  ('A17-6', 18.39, 12.54, 22.32, 98.40),
];

/// Drawn child polygons; A17-4 (L-shape wrapping the lower left of A17-3)
/// is already inset by 0.35.
final List<MapArea> _floor1GuideChildAreas = <MapArea>[
  ..._childDrawAreas(_floor1GuideChildRects, _floor1GuideAreas),
  const MapArea(
    code: 'A17-4',
    points: <MapPoint>[
      MapPoint(x: 0.74, y: 60.78),
      MapPoint(x: 5.08, y: 60.78),
      MapPoint(x: 5.08, y: 70.71),
      MapPoint(x: 9.66, y: 70.71),
      MapPoint(x: 9.66, y: 98.05),
      MapPoint(x: 0.74, y: 98.05),
    ],
  ),
];

/// Un-inset hit-test counterpart of [_floor1GuideChildAreas].
final List<MapArea> _floor1GuideChildHitAreas = <MapArea>[
  ..._childHitAreas(_floor1GuideChildRects),
  const MapArea(
    code: 'A17-4',
    points: <MapPoint>[
      MapPoint(x: 0.39, y: 60.43),
      MapPoint(x: 5.43, y: 60.43),
      MapPoint(x: 5.43, y: 70.36),
      MapPoint(x: 10.01, y: 70.36),
      MapPoint(x: 10.01, y: 98.40),
      MapPoint(x: 0.39, y: 98.40),
    ],
  ),
];

final List<MapArea> _floor1WarehouseAreas = <MapArea>[
  rectArea('A22', 16.54, 4.42, 25.07, 38.88),
  rectArea('A23', 25.07, 4.42, 84.75, 10.07),
  // Lower diagonal lies on the upper edge of A29.
  const MapArea(
    code: 'A24',
    points: <MapPoint>[
      MapPoint(x: 25.07, y: 10.07),
      MapPoint(x: 50.25, y: 10.07),
      MapPoint(x: 50.25, y: 53.22),
      MapPoint(x: 26.75, y: 34.56),
      MapPoint(x: 25.07, y: 37.51),
    ],
  ),
  rectArea('A25', 50.25, 10.07, 65.76, 20.43),
  // Lower-left diagonal lies on the upper edge of A29.
  const MapArea(
    code: 'A26',
    points: <MapPoint>[
      MapPoint(x: 52.71, y: 21.80),
      MapPoint(x: 78.49, y: 21.80),
      MapPoint(x: 78.49, y: 64.49),
      MapPoint(x: 64.44, y: 64.49),
      MapPoint(x: 52.71, y: 55.17),
    ],
  ),
  rectArea('A27', 78.49, 21.80, 84.75, 64.49),
  rectArea('A28', 84.75, 4.41, 89.92, 86.75),
  // Diagonal strip; the upper-left end is cut around the A22 corner.
  const MapArea(
    code: 'A29',
    points: <MapPoint>[
      MapPoint(x: 23.59, y: 40.10),
      MapPoint(x: 24.29, y: 38.88),
      MapPoint(x: 25.07, y: 38.88),
      MapPoint(x: 25.07, y: 37.51),
      MapPoint(x: 26.75, y: 34.56),
      MapPoint(x: 83.76, y: 79.83),
      MapPoint(x: 80.60, y: 85.38),
    ],
  ),
];

final List<MapArea> _floor1MoldAreas = <MapArea>[
  rectArea('A30', 23.00, 63.49, 76.57, 72.25),
  rectArea('A31', 9.75, 39.67, 51.21, 63.49),
  rectArea('A32', 9.75, 17.94, 51.21, 39.67),
  rectArea('A33', 9.75, 7.57, 70.03, 17.94),
  rectArea('A34', 51.21, 39.67, 88.42, 63.49),
  // L-shape: the A35 block plus the strip under A38, right of A33.
  const MapArea(
    code: 'A35',
    points: <MapPoint>[
      MapPoint(x: 51.21, y: 39.67),
      MapPoint(x: 51.21, y: 17.94),
      MapPoint(x: 70.03, y: 17.94),
      MapPoint(x: 70.03, y: 7.57),
      MapPoint(x: 88.42, y: 7.57),
      MapPoint(x: 88.42, y: 39.67),
    ],
  ),
  // Follows the diagonal wall; the notch fills the gap beside A31.
  const MapArea(
    code: 'A36',
    points: <MapPoint>[
      MapPoint(x: 1.12, y: 64.38),
      MapPoint(x: 9.75, y: 64.38),
      MapPoint(x: 9.75, y: 63.49),
      MapPoint(x: 23.00, y: 63.49),
      MapPoint(x: 23.00, y: 72.25),
      MapPoint(x: 99.27, y: 72.25),
      MapPoint(x: 99.27, y: 99.97),
      MapPoint(x: 76.24, y: 99.97),
    ],
  ),
  rectArea('A37', 1.12, 7.57, 9.75, 64.38),
  rectArea('A38', 1.12, 0.02, 88.42, 7.57),
  rectArea('A39', 88.42, 0.02, 99.27, 72.25),
];

// A30, A33, A36–A39 have no children. A35-2 is an L-shape, declared
// separately below.
const List<_ChildRect> _floor1MoldChildRects = <_ChildRect>[
  ('A31-1', 9.75, 53.98, 30.73, 63.49),
  ('A31-2', 9.75, 39.67, 30.73, 53.98),
  ('A31-3', 30.73, 53.98, 51.21, 63.49),
  ('A31-4', 30.73, 39.67, 51.21, 53.98),
  ('A32-1', 9.75, 29.03, 51.21, 39.67),
  ('A32-2', 9.75, 17.94, 51.21, 29.03),
  ('A34-1', 51.21, 51.60, 76.57, 63.49),
  ('A34-2', 51.21, 39.67, 76.57, 51.60),
  ('A34-3', 78.73, 39.67, 88.42, 58.27),
  ('A35-1', 51.21, 28.74, 88.42, 39.67),
];

/// Drawn child polygons; A35-2 (right half of A35 plus the strip under
/// A38) is inset by 0.35 on the A35 outline only, not on the A35-1 edge.
final List<MapArea> _floor1MoldChildAreas = <MapArea>[
  ..._childDrawAreas(_floor1MoldChildRects, _floor1MoldAreas),
  const MapArea(
    code: 'A35-2',
    points: <MapPoint>[
      MapPoint(x: 51.56, y: 28.74),
      MapPoint(x: 51.56, y: 18.29),
      MapPoint(x: 70.38, y: 18.29),
      MapPoint(x: 70.38, y: 7.92),
      MapPoint(x: 88.07, y: 7.92),
      MapPoint(x: 88.07, y: 28.74),
    ],
  ),
];

/// Un-inset hit-test counterpart of [_floor1MoldChildAreas].
final List<MapArea> _floor1MoldChildHitAreas = <MapArea>[
  ..._childHitAreas(_floor1MoldChildRects),
  const MapArea(
    code: 'A35-2',
    points: <MapPoint>[
      MapPoint(x: 51.21, y: 28.74),
      MapPoint(x: 51.21, y: 17.94),
      MapPoint(x: 70.03, y: 17.94),
      MapPoint(x: 70.03, y: 7.57),
      MapPoint(x: 88.42, y: 7.57),
      MapPoint(x: 88.42, y: 28.74),
    ],
  ),
];

final List<MapArea> _floor2AllAreas = <MapArea>[
  rectArea('A40', 2.89, 10.32, 29.14, 68.80),
  rectArea('A41', 29.14, 34.41, 56.52, 42.17),
  rectArea('A42', 56.52, 18.15, 95.98, 52.40),
  rectArea('A43', 57.89, 61.17, 65.00, 90.61),
];

// A41 and A43 have no children.
const List<_ChildRect> _floor2AllChildRects = <_ChildRect>[
  ('A40-1', 2.89, 10.32, 29.14, 34.73),
  ('A40-2', 2.89, 34.73, 29.14, 59.97),
  ('A40-3', 2.89, 59.97, 12.95, 68.80),
  ('A40-4', 12.95, 59.97, 29.14, 68.80),
  ('A42-1', 56.52, 18.15, 72.62, 33.75),
  ('A42-2', 72.62, 18.15, 75.70, 33.75),
  ('A42-3', 75.70, 18.15, 87.02, 33.75),
  ('A42-4', 56.52, 33.75, 75.70, 52.40),
  ('A42-5', 75.70, 33.75, 87.02, 52.40),
  ('A42-6', 87.02, 18.15, 95.98, 52.40),
];

const List<String> _factory2 = <String>['Factory 2'];

final List<FloorMapData> fixedAssetFloorMaps = <FloorMapData>[
  FloorMapData(
    id: 'floor1',
    title: 'Floor 1 - Press',
    imageAsset: 'assets/maps/floor1-press.png',
    imageWidth: 1226,
    imageHeight: 718,
    floor: '1F',
    facs: _factory2,
    positionACodes: const <String>[
      'A1',
      'A2',
      'A3',
      'A4',
      'A5',
      'A6',
      'A7',
      'A8',
      'A9',
      'A10',
      'A11',
    ],
    zones: const <MapZone>[
      MapZone(code: 'A1', x: 36.67, y: 46.47),
      MapZone(code: 'A1-1', x: 31.01, y: 33.87),
      MapZone(code: 'A1-2', x: 40.25, y: 59.63),
      MapZone(code: 'A2', x: 56.71, y: 46.61),
      MapZone(code: 'A2-1', x: 67.55, y: 44.0),
      MapZone(code: 'A2-2', x: 52.3, y: 55.1),
      MapZone(code: 'A2-3', x: 65.05, y: 55.1),
      MapZone(code: 'A3', x: 80.13, y: 45.98),
      MapZone(code: 'A3-1', x: 80.89, y: 38.15),
      MapZone(code: 'A3-2', x: 75.14, y: 47.8, offsetX: -14, offsetY: 6),
      MapZone(code: 'A3-3', x: 82.67, y: 58.34),
      MapZone(code: 'A4', x: 37.02, y: 76.35),
      MapZone(code: 'A4-1', x: 33.8, y: 88.42),
      MapZone(code: 'A4-2', x: 44.03, y: 88.0),
      MapZone(code: 'A5-2', x: 50.31, y: 86.39),
      MapZone(code: 'A5-1', x: 66.53, y: 71.11),
      MapZone(code: 'A5', x: 59.4, y: 77.25),
      MapZone(code: 'A6', x: 84.36, y: 77.47),
      MapZone(code: 'A6-1', x: 73.46, y: 66.33),
      MapZone(code: 'A6-2', x: 91.17, y: 75.18),
      MapZone(code: 'A6-3', x: 74.18, y: 81.91),
      MapZone(code: 'A6-4', x: 91.17, y: 87.09),
      MapZone(code: 'A8', x: 61.22, y: 93.74),
      MapZone(code: 'A7', x: 22.72, y: 72.73),
      MapZone(code: 'A9', x: 12.36, y: 52.94),
      MapZone(code: 'A10', x: 67.65, y: 21.71),
      MapZone(code: 'A11', x: 96.69, y: 61.02),
    ],
    areas: _floor1PressAreas,
  ),
  FloorMapData(
    id: 'floor2',
    title: 'Floor 1 - Guide',
    imageAsset: 'assets/maps/floor1-guide.png',
    imageWidth: 1178,
    imageHeight: 509,
    floor: '1F',
    facs: _factory2,
    positionACodes: const <String>[
      'A12',
      'A13',
      'A14',
      'A15',
      'A16',
      'A17',
      'A18',
      'A19',
      'A20',
      'A21',
    ],
    zones: const <MapZone>[
      MapZone(code: 'A12-1', x: 25.37, y: 15.27),
      MapZone(code: 'A12-2', x: 43.02, y: 19.55),
      MapZone(code: 'A12', x: 33.44, y: 30.29),
      MapZone(code: 'A13', x: 64.76, y: 30.02),
      MapZone(code: 'A13-1', x: 57.12, y: 22.77),
      MapZone(code: 'A13-2', x: 68.12, y: 22.97),
      MapZone(code: 'A19', x: 91.64, y: 15.53),
      MapZone(code: 'A16', x: 88.98, y: 32.85),
      MapZone(code: 'A16-1', x: 88.07, y: 23.13),
      MapZone(code: 'A16-2', x: 85.84, y: 38.45, offsetY: 6),
      MapZone(code: 'A14', x: 33.16, y: 67.06),
      MapZone(code: 'A14-1', x: 26.34, y: 76.96),
      MapZone(code: 'A14-2', x: 44.24, y: 53.19),
      MapZone(code: 'A14-3', x: 43.26, y: 87.1),
      MapZone(code: 'A15', x: 65.96, y: 67.06),
      MapZone(code: 'A15-1', x: 55.76, y: 63.47),
      MapZone(code: 'A15-2', x: 78.9, y: 58.35),
      MapZone(code: 'A15-3', x: 56.76, y: 76.96),
      MapZone(code: 'A15-4', x: 70.81, y: 86.66),
      MapZone(code: 'A18', x: 46.18, y: 4.44),
      MapZone(code: 'A20', x: 97.56, y: 42.65),
      MapZone(code: 'A21', x: 63.74, y: 96.02),
      MapZone(code: 'A17-1', x: 11.89, y: 17.14),
      MapZone(code: 'A17-2', x: 11.75, y: 29.38),
      MapZone(code: 'A17-4', x: 5.26, y: 83.06),
      MapZone(code: 'A17-5', x: 13.09, y: 94.99),
      MapZone(code: 'A17', x: 11.92, y: 55.1),
      MapZone(code: 'A17-3', x: 10.59, y: 63.65),
      MapZone(code: 'A17-6', x: 20.38, y: 55.9),
    ],
    areas: _floor1GuideAreas,
  ),
  FloorMapData(
    id: 'floor3',
    title: 'Floor 1 - Warehouse (WH)',
    imageAsset: 'assets/maps/floor1-warehouse.png',
    imageWidth: 890,
    imageHeight: 754,
    floor: '1F',
    facs: _factory2,
    positionACodes: const <String>[
      'A22',
      'A23',
      'A24',
      'A25',
      'A26',
      'A27',
      'A28',
      'A29',
    ],
    zones: const <MapZone>[
      MapZone(code: 'A22', x: 20.49, y: 30.83),
      MapZone(code: 'A23', x: 62.26, y: 7.05),
      MapZone(code: 'A25', x: 61.77, y: 18.03),
      MapZone(code: 'A24', x: 40.65, y: 22.69),
      MapZone(code: 'A26', x: 72.8, y: 42.8),
      MapZone(code: 'A27', x: 81.35, y: 42.8),
      MapZone(code: 'A28', x: 87.94, y: 42.8),
      MapZone(code: 'A29', x: 54.69, y: 61.24),
    ],
    areas: _floor1WarehouseAreas,
  ),
  FloorMapData(
    id: 'floor4',
    title: 'Floor 1 - Mold',
    imageAsset: 'assets/maps/floor1-mold.png',
    imageWidth: 467,
    imageHeight: 737,
    floor: '1F',
    facs: _factory2,
    positionACodes: const <String>[
      'A30',
      'A31',
      'A32',
      'A33',
      'A34',
      'A35',
      'A36',
      'A37',
      'A38',
      'A39',
    ],
    zones: const <MapZone>[
      MapZone(code: 'A30', x: 52.80, y: 67.23),
      MapZone(code: 'A31', x: 30.48, y: 53.73),
      MapZone(code: 'A31-1', x: 12.60, y: 57.99),
      MapZone(code: 'A31-2', x: 12.35, y: 46.91),
      MapZone(code: 'A31-3', x: 42.40, y: 58.88),
      MapZone(code: 'A31-4', x: 42.78, y: 46.66),
      MapZone(code: 'A32', x: 30.48, y: 28.91),
      MapZone(code: 'A32-1', x: 36.31, y: 33.57),
      MapZone(code: 'A32-2', x: 19.32, y: 22.96),
      MapZone(code: 'A33', x: 45.18, y: 12.52),
      MapZone(code: 'A34', x: 64.34, y: 52.21),
      MapZone(code: 'A34-1', x: 54.95, y: 59.20),
      MapZone(code: 'A34-2', x: 54.95, y: 47.55),
      MapZone(code: 'A34-3', x: 83.86, y: 51.56),
      MapZone(code: 'A35', x: 67.63, y: 29.31),
      MapZone(code: 'A35-1', x: 78.66, y: 35.01),
      MapZone(code: 'A35-2', x: 72.82, y: 15.41),
      MapZone(code: 'A36', x: 60.79, y: 83.54),
      MapZone(code: 'A37', x: 4.61, y: 39.19),
      MapZone(code: 'A38', x: 51.39, y: 3.84),
      MapZone(code: 'A39', x: 94.51, y: 32.44),
    ],
    areas: _floor1MoldAreas,
    rotationDeg: 90,
  ),
  FloorMapData(
    id: 'floor5',
    title: 'Floor 2 - All',
    imageAsset: 'assets/maps/floor2-all.png',
    imageWidth: 1228,
    imageHeight: 717,
    floor: '2F',
    facs: _factory2,
    positionACodes: const <String>['A40', 'A41', 'A42', 'A43'],
    zones: const <MapZone>[
      MapZone(code: 'A40', x: 16.69, y: 35.26),
      MapZone(code: 'A40-1', x: 15.89, y: 20.91),
      MapZone(code: 'A40-2', x: 21.26, y: 47.69),
      MapZone(code: 'A40-3', x: 7.09, y: 65.31),
      MapZone(code: 'A40-4', x: 26.86, y: 63.26),
      MapZone(code: 'A41', x: 31.87, y: 37.89),
      MapZone(code: 'A42', x: 77.40, y: 34.16),
      MapZone(code: 'A42-1', x: 67.37, y: 20.85),
      MapZone(code: 'A42-2', x: 74.24, y: 28.06),
      MapZone(code: 'A42-3', x: 81.18, y: 25.57),
      MapZone(code: 'A42-4', x: 62.17, y: 36.94),
      MapZone(code: 'A42-5', x: 80.95, y: 46.65),
      MapZone(code: 'A42-6', x: 91.60, y: 40.68),
      MapZone(code: 'A43', x: 60.63, y: 81.91),
    ],
    areas: _floor2AllAreas,
  ),
];

String? normalizeFixedAssetMapFloor(String? floor) {
  switch (floor?.trim().toUpperCase()) {
    case '1F':
      return '1F';
    case '2F':
      return '2F';
    default:
      return null;
  }
}

FloorMapData? resolveFixedAssetFloorMap({
  required String? fac,
  required String? floor,
  required String? positionA,
  String? positionAA,
}) {
  final normalizedFloor = normalizeFixedAssetMapFloor(floor);
  final parentCode = positionA?.trim();

  if (normalizedFloor == null || parentCode == null || parentCode.isEmpty) {
    return null;
  }

  for (final map in fixedAssetFloorMaps) {
    if (map.floor == normalizedFloor &&
        map.positionACodes.contains(parentCode)) {
      return map;
    }
  }
  return null;
}

MapZone? findZoneByCode(FloorMapData data, String? code) {
  final exactCode = code?.trim();
  if (exactCode == null || exactCode.isEmpty) return null;
  for (final zone in data.zones) {
    if (zone.code == exactCode) return zone;
  }
  return null;
}

MapArea? findAreaByCode(FloorMapData data, String? code) {
  final exactCode = code?.trim();
  if (exactCode == null || exactCode.isEmpty) return null;
  for (final area in data.areas) {
    if (area.code == exactCode) return area;
  }
  return null;
}

/// Child sub-area polygons of [data]; empty when the map defines none.
/// Returns the same list instance on every call (safe for identity caches).
List<MapArea> childAreasFor(FloorMapData data) {
  return _childAreasByMapId[data.id] ?? const <MapArea>[];
}

/// Tap hit-test counterpart of [childAreasFor]: the same children without
/// the drawing inset. Same list instance on every call.
List<MapArea> childHitAreasFor(FloorMapData data) {
  return _childHitAreasByMapId[data.id] ?? const <MapArea>[];
}

FixedAssetMapSelection? resolveFixedAssetMapSelection({
  required String? fac,
  required String? floor,
  required String? positionA,
  required String? positionAA,
}) {
  final map = resolveFixedAssetFloorMap(
    fac: fac,
    floor: floor,
    positionA: positionA,
    positionAA: positionAA,
  );
  if (map == null) return null;

  final parent = findAreaByCode(map, positionA)?.code;
  if (parent == null) return null;

  return FixedAssetMapSelection(
    map: map,
    parentZoneCode: parent,
    childZoneCode: findZoneByCode(map, positionAA)?.code,
  );
}
