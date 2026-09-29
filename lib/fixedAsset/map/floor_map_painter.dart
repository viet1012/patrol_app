import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/foundation.dart' show ValueListenable;
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

/// Selection colours: [mapSelectColor] for outlines and the solid badge,
/// [mapSelectLightColor] for the running highlight and glows.
const Color mapSelectColor = Color(0xFF0284C7);
const Color mapSelectLightColor = Color(0xFF0EA5E9);

/// Glow + outline (+ optional faint fill) of the highlight target — the
/// selected child if it has a polygon, otherwise the selected parent.
void paintSelectedTarget(Canvas canvas, Path path, {required bool fill}) {
  canvas.drawPath(
    path,
    Paint()
      ..color = mapSelectLightColor.withValues(alpha: 0.40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
  );
  if (fill) {
    canvas.drawPath(
      path,
      Paint()
        ..color = mapSelectColor.withValues(alpha: 0.06)
        ..style = PaintingStyle.fill,
    );
  }
  canvas.drawPath(
    path,
    Paint()
      ..color = mapSelectColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round,
  );
}

/// Static polygon layer (fills + outlines). Repaints only when its inputs
/// change, never per animation frame.
///
/// [raised] (full-floor view): unselected parents are drawn as grey raised
/// cards (drop shadow, light fill, slate outline) in three passes, so every
/// shadow sits under every card. The selected parent is drawn last: as the
/// highlight target (glow + 3px outline, faint fill when raised), or with a
/// plain 2px outline when [childTargeted] (a child of it is the target).
class FloorMapPainter extends CustomPainter {
  final List<MapArea> areas;
  final String? selectedParentZone;
  final String? selectedChildZone;
  final bool raised;

  /// The selected child (with its own polygon) is the highlight target.
  final bool childTargeted;

  const FloorMapPainter({
    required this.areas,
    this.selectedParentZone,
    this.selectedChildZone,
    this.raised = false,
    this.childTargeted = false,
  });

  static const Color _normalBlue = Color(0xFF2563EB);
  static const Color _parentRed = Color(0xFFE53935);
  static const Color _cardShadow = Color(0xFF0F172A);
  static const Color _cardFill = Color(0xFFF8FAFC);
  static const Color _cardOutline = Color(0xFF64748B);

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
        ..color = _cardShadow.withValues(alpha: 0.22)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8);
      final fill = Paint()
        ..color = _cardFill.withValues(alpha: 0.55)
        ..style = PaintingStyle.fill;
      final stroke = Paint()
        ..color = _cardOutline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
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
      // Focus view: unselected parents keep the plain red outline (not a
      // selection state).
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
    if (childTargeted) {
      canvas.drawPath(
        selectedPath,
        Paint()
          ..color = mapSelectColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round,
      );
    } else {
      paintSelectedTarget(canvas, selectedPath, fill: raised);
    }
  }

  @override
  bool shouldRepaint(covariant FloorMapPainter oldDelegate) {
    return oldDelegate.areas != areas ||
        oldDelegate.selectedParentZone != selectedParentZone ||
        oldDelegate.selectedChildZone != selectedChildZone ||
        oldDelegate.raised != raised ||
        oldDelegate.childTargeted != childTargeted;
  }
}

/// Static glow around the highlight target for the lite ("breathing")
/// level: two solid select-light strokes (w + 8 px at 0.12, w + 4 px at
/// 0.20) plus a select-blue outline of w = [coreScreenWidth] screen px.
/// Widths follow [viewerScale] (constant on screen), so it repaints only on
/// a scale step; the breathing itself is an opacity animation applied when
/// compositing (e.g. FadeTransition), with no repaint.
class SelectedAreaGlowPainter extends CustomPainter {
  final MapArea area;
  final ValueListenable<double>? viewerScale;

  SelectedAreaGlowPainter({required this.area, this.viewerScale})
    : super(repaint: viewerScale);

  /// On-screen width of the outline; the halo strokes are +4 / +8 px.
  static const double coreScreenWidth = 3;

  Size? _cachedSize;
  Path? _path;

  final Paint _haloOuterPaint = _strokePaint(
    mapSelectLightColor.withValues(alpha: 0.12),
  );
  final Paint _haloInnerPaint = _strokePaint(
    mapSelectLightColor.withValues(alpha: 0.20),
  );
  final Paint _outlinePaint = _strokePaint(mapSelectColor);

  static Paint _strokePaint(Color color) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    if (area.points.isEmpty) return;
    if (size != _cachedSize) {
      _cachedSize = size;
      _path = mapAreaPath(area, size);
    }
    final path = _path!;
    final scale = viewerScale?.value ?? 1;
    final px = 1 / (scale <= 0 ? 1 : scale); // one screen pixel, logical
    final width = coreScreenWidth * px;
    canvas.drawPath(path, _haloOuterPaint..strokeWidth = width + 8 * px);
    canvas.drawPath(path, _haloInnerPaint..strokeWidth = width + 4 * px);
    canvas.drawPath(path, _outlinePaint..strokeWidth = width);
  }

  @override
  bool shouldRepaint(covariant SelectedAreaGlowPainter oldDelegate) {
    return oldDelegate.area != area || oldDelegate.viewerScale != viewerScale;
  }
}

/// Running highlight around the highlight target, repainted by [progress]
/// (a repeating linear 0..1 cycle, [loops] trips per cycle) without
/// rebuilding any widget.
///
/// With [progressValue] the painter reads and repaints on that notifier
/// instead of [progress] (optional; FloorMapWidget repaints on every
/// controller tick).
/// With [viewerScale] (the InteractiveViewer scale) every stroke width and
/// the segment length are divided by the scale, so on screen the segment
/// is always [segmentScreenLength] px long and [coreScreenWidth] px thick,
/// at any zoom and for any polygon size. [visibility] (0..1) fades the
/// segment in and out, e.g. hidden during pan/zoom. [simplified] drops the
/// trail and the halo (white underlay + core only).
///
/// No blur: the halo is two solid strokes. The contour (traced twice, so a
/// segment crossing the start corner stays one continuous stroke) and its
/// metric are computed once per painter (one per area) and size; a frame
/// only extracts the segment (and trail) and strokes it.
class SelectedAreaHighlightPainter extends CustomPainter {
  final MapArea area;
  final Animation<double> progress;

  /// Trips around the perimeter over one 0..1 run of [progress].
  final int loops;

  final ValueListenable<double>? progressValue;
  final ValueListenable<double>? viewerScale;
  final Animation<double>? visibility;
  final bool simplified;

  SelectedAreaHighlightPainter({
    required this.area,
    required this.progress,
    this.loops = 1,
    this.progressValue,
    this.viewerScale,
    this.visibility,
    this.simplified = false,
  }) : super(
         repaint: Listenable.merge(<Listenable?>[
           progressValue ?? progress,
           viewerScale,
           visibility,
         ]),
       );

  /// Segment length as a fraction of the perimeter, used only without
  /// [viewerScale].
  static const double segmentFraction = 0.2;

  /// On-screen length of the running segment and of the faint trail
  /// behind it.
  static const double segmentScreenLength = 90;
  static const double trailScreenLength = 60;

  /// On-screen width of the segment core (the white underlay is +2 px).
  static const double coreScreenWidth = 3;

  Size? _cachedSize;
  PathMetric? _loopMetric;
  double _perimeter = 0;

  // Reused every frame; only colour alpha and width change.
  final Paint _trailPaint = _strokePaint();
  final Paint _haloOuterPaint = _strokePaint();
  final Paint _haloInnerPaint = _strokePaint();
  final Paint _underlayPaint = _strokePaint();
  final Paint _corePaint = _strokePaint();

  static Paint _strokePaint() => Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  /// Perimeter of [area] in logical pixels at [size].
  static double perimeterFor(MapArea area, Size size) {
    if (area.points.length < 2) return 0;
    var length = 0.0;
    for (var i = 0; i < area.points.length; i++) {
      final a = mapPointToOffset(area.points[i], size);
      final b = mapPointToOffset(
        area.points[(i + 1) % area.points.length],
        size,
      );
      length += (b - a).distance;
    }
    return length;
  }

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
    final opacity = (visibility?.value ?? 1).clamp(0.0, 1.0);
    if (opacity <= 0) return;
    final metric = _metricFor(size);
    if (metric == null) return;

    final scale = viewerScale?.value ?? 1;
    final px = 1 / (scale <= 0 ? 1 : scale); // one screen pixel, logical
    final segment = viewerScale == null
        ? _perimeter * segmentFraction
        : math.min(segmentScreenLength * px, _perimeter);
    final width = coreScreenWidth * px;

    // Head position; the trail and segment sit behind it. Offsetting by one
    // perimeter keeps every extract range inside [0, 2·perimeter].
    final t = progressValue?.value ?? progress.value;
    final head = ((t * loops) % 1.0) * _perimeter + _perimeter;
    final segmentStart = head - segment;

    if (!simplified) {
      final trail = math.min(trailScreenLength * px, _perimeter - segment);
      if (trail > 0) {
        canvas.drawPath(
          metric.extractPath(segmentStart - trail, segmentStart),
          _trailPaint
            ..color = mapSelectLightColor.withValues(alpha: 0.25 * opacity)
            ..strokeWidth = width,
        );
      }
    }
    final path = metric.extractPath(segmentStart, head);
    if (!simplified) {
      // Halo as two solid strokes (no MaskFilter on the animated layer).
      canvas.drawPath(
        path,
        _haloOuterPaint
          ..color = mapSelectLightColor.withValues(alpha: 0.12 * opacity)
          ..strokeWidth = width + 8 * px,
      );
      canvas.drawPath(
        path,
        _haloInnerPaint
          ..color = mapSelectLightColor.withValues(alpha: 0.20 * opacity)
          ..strokeWidth = width + 4 * px,
      );
    }
    canvas.drawPath(
      path,
      _underlayPaint
        ..color = Colors.white.withValues(alpha: opacity)
        ..strokeWidth = width + 2 * px,
    );
    canvas.drawPath(
      path,
      _corePaint
        ..color = mapSelectLightColor.withValues(alpha: opacity)
        ..strokeWidth = width,
    );
  }

  @override
  bool shouldRepaint(covariant SelectedAreaHighlightPainter oldDelegate) {
    return oldDelegate.area != area ||
        oldDelegate.progress != progress ||
        oldDelegate.loops != loops ||
        oldDelegate.progressValue != progressValue ||
        oldDelegate.viewerScale != viewerScale ||
        oldDelegate.visibility != visibility ||
        oldDelegate.simplified != simplified;
  }
}
