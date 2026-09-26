class MapPoint {
  final double x;
  final double y;

  const MapPoint({required this.x, required this.y});
}

class MapArea {
  final String code;
  final List<MapPoint> points;

  const MapArea({required this.code, required this.points});
}

class MapZone {
  final String code;
  final double x;
  final double y;

  /// Render-only pixel nudge; the percentage position remains unchanged.
  final double offsetX;
  final double offsetY;

  const MapZone({
    required this.code,
    required this.x,
    required this.y,
    this.offsetX = 0,
    this.offsetY = 0,
  });
}

class FloorMapData {
  final String id;
  final String title;
  final String imageAsset;
  final double imageWidth;
  final double imageHeight;
  final String floor;
  final List<String> facs;

  /// Exact backend PositionA values owned by this layout.
  final List<String> positionACodes;

  final List<MapZone> zones;
  final List<MapArea> areas;
  final double rotationDeg;

  const FloorMapData({
    required this.id,
    required this.title,
    required this.imageAsset,
    required this.imageWidth,
    required this.imageHeight,
    required this.floor,
    required this.facs,
    required this.positionACodes,
    required this.zones,
    required this.areas,
    this.rotationDeg = 0,
  });
}

class FixedAssetMapSelection {
  final FloorMapData map;
  final String? parentZoneCode;
  final String? childZoneCode;

  const FixedAssetMapSelection({
    required this.map,
    required this.parentZoneCode,
    required this.childZoneCode,
  });
}
