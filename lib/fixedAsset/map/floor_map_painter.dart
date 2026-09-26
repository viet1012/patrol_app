import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import 'floor_map_models.dart';

Offset mapPointToOffset(MapPoint point, Size size) {
  return Offset(size.width * point.x / 100, size.height * point.y / 100);
}

bool isSelectedMapArea(MapArea area, String? selectedParentZone) {
  return selectedParentZone != null && area.code == selectedParentZone;
}

Path mapAreaPath(MapArea area, Size size) {
  final path = Path();
  final first = mapPointToOffset(area.points.first, size);
  path.moveTo(first.dx, first.dy);
  for (final point in area.points.skip(1)) {
    final offset = mapPointToOffset(point, size);
    path.lineTo(offset.dx, offset.dy);
  }
  return path..close();
}

/// Static polygon layer (fills + outlines). Repaints only when its inputs
/// change, never per animation frame.
class FloorMapPainter extends CustomPainter {
  final List<MapArea> areas;
  final String? selectedParentZone;
  final String? selectedChildZone;

  const FloorMapPainter({
    required this.areas,
    this.selectedParentZone,
    this.selectedChildZone,
  });

  static const Color _normalBlue = Color(0xFF2563EB);
  static const Color _selectedBlue = Color(0xFF1D4ED8);

  @override
  void paint(Canvas canvas, Size size) {
    final normalFill = Paint()
      ..color = _normalBlue.withValues(alpha: 0.02)
      ..style = PaintingStyle.fill;
    final normalStroke = Paint()
      ..color = _normalBlue.withValues(alpha: 0.70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round;
    final selectedFill = Paint()
      ..color = _normalBlue.withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;
    final selectedStroke = Paint()
      ..color = _selectedBlue.withValues(alpha: 0.92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    Path? selectedPath;
    for (final area in areas) {
      if (area.points.isEmpty) continue;
      final path = mapAreaPath(area, size);
      if (isSelectedMapArea(area, selectedParentZone)) {
        // Drawn last so its outline sits above neighbours.
        selectedPath = path;
        continue;
      }
      canvas.drawPath(path, normalFill);
      canvas.drawPath(path, normalStroke);
    }

    if (selectedPath == null) return;
    canvas.drawPath(selectedPath, selectedFill);
    canvas.drawPath(selectedPath, selectedStroke);
  }

  @override
  bool shouldRepaint(covariant FloorMapPainter oldDelegate) {
    return oldDelegate.areas != areas ||
        oldDelegate.selectedParentZone != selectedParentZone ||
        oldDelegate.selectedChildZone != selectedChildZone;
  }
}

/// Traveling edge highlight for the selected polygon, repainted by
/// [progress] (one linear 0..1 run spanning [loops] trips) without rebuilding any widget.
///
/// Per frame: one `extractPath` and two `drawPath` calls. The contour
/// (traced twice, so a segment crossing the start corner stays one
/// continuous stroke) and its metric are cached until the size changes.
class SelectedAreaHighlightPainter extends CustomPainter {
  final MapArea area;
  final Animation<double> progress;

  /// Trips around the perimeter over one 0..1 run of [progress].
  final int loops;

  SelectedAreaHighlightPainter({
    required this.area,
    required this.progress,
    this.loops = 1,
  }) : super(repaint: progress);

  /// Fraction of the perimeter covered by the moving segment.
  static const double segmentFraction = 0.2;

  static const Color _highlightCyan = Color(0xFF38BDF8);

  // Wide, low-opacity stroke instead of a Gaussian blur: cheap halo.
  static final Paint _glow = Paint()
    ..color = _highlightCyan.withValues(alpha: 0.22)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 6
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  static final Paint _core = Paint()
    ..color = _highlightCyan.withValues(alpha: 0.95)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  Size? _cachedSize;
  PathMetric? _loopMetric;
  double _perimeter = 0;

  PathMetric? _metricFor(Size size) {
    if (size == _cachedSize) return _loopMetric;
    _cachedSize = size;
    _loopMetric = null;
    if (area.points.length < 2) return null;

    final points = <Offset>[
      for (final point in area.points) mapPointToOffset(point, size),
    ];
    // Open contour: the polygon traced twice, ending back at the start.
    final loop = Path()..moveTo(points.first.dx, points.first.dy);
    for (var lap = 0; lap < 2; lap++) {
      for (final point in points.skip(1)) {
        loop.lineTo(point.dx, point.dy);
      }
      loop.lineTo(points.first.dx, points.first.dy);
    }
    final metrics = loop.computeMetrics().toList(growable: false);
    if (metrics.isEmpty || metrics.first.length <= 0) return null;
    _loopMetric = metrics.first;
    _perimeter = _loopMetric!.length / 2;
    return _loopMetric;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final metric = _metricFor(size);
    if (metric == null) return;
    // start ∈ [0, perimeter), end ≤ 2·perimeter: never needs wrapping, so
    // progress 1.0 → 0.0 lands on the identical segment (seamless loop).
    final start = ((progress.value * loops) % 1.0) * _perimeter;
    final segment = metric.extractPath(
      start,
      start + _perimeter * segmentFraction,
    );
    canvas.drawPath(segment, _glow);
    canvas.drawPath(segment, _core);
  }

  @override
  bool shouldRepaint(covariant SelectedAreaHighlightPainter oldDelegate) {
    return oldDelegate.area != area ||
        oldDelegate.progress != progress ||
        oldDelegate.loops != loops;
  }
}
