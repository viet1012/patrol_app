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

/// Dashed copy of [source] ([dash] on, [gap] off, in pixels).
Path dashedPath(Path source, {double dash = 4, double gap = 3}) {
  final dashed = Path();
  for (final metric in source.computeMetrics()) {
    var distance = 0.0;
    while (distance < metric.length) {
      final end = (distance + dash).clamp(0.0, metric.length).toDouble();
      dashed.addPath(metric.extractPath(distance, end), Offset.zero);
      distance = end + gap;
    }
  }
  return dashed;
}

/// Static polygon layer (fills + outlines). Repaints only when its inputs
/// change, never per animation frame.
///
/// [raised] (full-floor view): unselected parents are drawn as raised cards
/// (drop shadow, light fill, blue outline) in three passes, so every
/// shadow sits under every card. The selected parent always gets a red
/// glow + 3px red outline, drawn last (plus a faint red fill when raised).
class FloorMapPainter extends CustomPainter {
  final List<MapArea> areas;
  final String? selectedParentZone;
  final String? selectedChildZone;
  final bool raised;

  const FloorMapPainter({
    required this.areas,
    this.selectedParentZone,
    this.selectedChildZone,
    this.raised = false,
  });

  static const Color _normalBlue = Color(0xFF2563EB);
  static const Color _parentRed = Color(0xFFE53935);
  static const Color _cardShadow = Color(0xFF1E3A8A);
  static const Color _cardFill = Color(0xFFEFF6FF);

  @override
  void paint(Canvas canvas, Size size) {
    final paths = <Path>[];
    Path? selectedPath;
    for (final area in areas) {
      if (area.points.isEmpty) continue;
      final path = mapAreaPath(area, size);
      if (isSelectedMapArea(area, selectedParentZone)) {
        // Drawn last so its outline sits above neighbours.
        selectedPath = path;
      } else {
        paths.add(path);
      }
    }

    if (raised) {
      final shadow = Paint()
        ..color = _cardShadow.withValues(alpha: 0.30)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8);
      final fill = Paint()
        ..color = _cardFill.withValues(alpha: 0.55)
        ..style = PaintingStyle.fill;
      final stroke = Paint()
        ..color = _normalBlue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeJoin = StrokeJoin.round;
      for (final path in paths) {
        canvas.drawPath(path.shift(const Offset(0, 1.5)), shadow);
      }
      for (final path in paths) {
        canvas.drawPath(path, fill);
      }
      for (final path in paths) {
        canvas.drawPath(path, stroke);
      }
    } else {
      final fill = Paint()
        ..color = _normalBlue.withValues(alpha: 0.02)
        ..style = PaintingStyle.fill;
      final stroke = Paint()
        ..color = _parentRed
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round;
      for (final path in paths) {
        canvas.drawPath(path, fill);
        canvas.drawPath(path, stroke);
      }
    }

    if (selectedPath == null) return;
    canvas.drawPath(
      selectedPath,
      Paint()
        ..color = _parentRed.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    if (raised) {
      canvas.drawPath(
        selectedPath,
        Paint()
          ..color = _parentRed.withValues(alpha: 0.05)
          ..style = PaintingStyle.fill,
      );
    }
    canvas.drawPath(
      selectedPath,
      Paint()
        ..color = _parentRed
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant FloorMapPainter oldDelegate) {
    return oldDelegate.areas != areas ||
        oldDelegate.selectedParentZone != selectedParentZone ||
        oldDelegate.selectedChildZone != selectedChildZone ||
        oldDelegate.raised != raised;
  }
}

/// Traveling edge highlight for the selected polygon, repainted by
/// [progress] (a repeating linear 0..1 cycle, [loops] trips per cycle)
/// without rebuilding any widget.
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
