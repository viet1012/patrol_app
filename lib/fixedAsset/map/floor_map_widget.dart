import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'floor_map_data.dart';
import 'floor_map_models.dart';
import 'floor_map_painter.dart';

double normalizedMapRotation(double rotationDeg) {
  final normalized = rotationDeg % 360;
  return normalized < 0 ? normalized + 360 : normalized;
}

bool isQuarterTurnMapRotation(double rotationDeg) {
  final normalized = normalizedMapRotation(rotationDeg);
  return normalized == 90 || normalized == 270;
}

double floorMapDisplayAspectRatio(FloorMapData data) {
  return isQuarterTurnMapRotation(data.rotationDeg)
      ? data.imageHeight / data.imageWidth
      : data.imageWidth / data.imageHeight;
}

bool isMajorMapZone(FloorMapData data, MapZone zone) {
  return data.areas.any((area) => area.code == zone.code);
}

/// Initial viewport matrix that fits the [areaCode] polygon inside
/// [viewport] with [padding] (fraction of the polygon bounds on each side;
/// 0.2 makes the polygon fill roughly 70% of the limiting viewport axis).
///
/// Polygon percentage points are projected through the same logical scene →
/// rotation → display transform the widget renders with, so rotated layouts
/// focus correctly. Returns null when the polygon is missing or the viewport
/// is unusable (caller falls back to the full-floor view).
Matrix4? floorMapFocusMatrix(
  FloorMapData data,
  String? areaCode,
  Size viewport, {
  double padding = 0.2,
  double maxScale = 4,
}) {
  if (areaCode == null || viewport.isEmpty || !viewport.isFinite) return null;
  MapArea? area;
  for (final candidate in data.areas) {
    if (candidate.code == areaCode) {
      area = candidate;
      break;
    }
  }
  if (area == null || area.points.isEmpty) return null;

  // Rendered child: AspectRatio fitted and centred inside the viewport.
  final aspect = floorMapDisplayAspectRatio(data);
  final displayWidth = math.min(viewport.width, viewport.height * aspect);
  final display = Size(displayWidth, displayWidth / aspect);
  final originX = (viewport.width - display.width) / 2;
  final originY = (viewport.height - display.height) / 2;
  final logical = isQuarterTurnMapRotation(data.rotationDeg)
      ? Size(display.height, display.width)
      : display;
  final angle = normalizedMapRotation(data.rotationDeg) * math.pi / 180;
  final cosA = math.cos(angle);
  final sinA = math.sin(angle);

  var minX = double.infinity, minY = double.infinity;
  var maxX = -double.infinity, maxY = -double.infinity;
  for (final point in area.points) {
    // Logical point relative to the scene centre, rotated about the centre
    // (Transform.rotate, clockwise in screen space), then into display space.
    final lx = logical.width * point.x / 100 - logical.width / 2;
    final ly = logical.height * point.y / 100 - logical.height / 2;
    final dx = originX + display.width / 2 + lx * cosA - ly * sinA;
    final dy = originY + display.height / 2 + lx * sinA + ly * cosA;
    minX = math.min(minX, dx);
    maxX = math.max(maxX, dx);
    minY = math.min(minY, dy);
    maxY = math.max(maxY, dy);
  }

  final boundsWidth = math.max(maxX - minX, 1.0) * (1 + 2 * padding);
  final boundsHeight = math.max(maxY - minY, 1.0) * (1 + 2 * padding);
  final scale = math
      .min(viewport.width / boundsWidth, viewport.height / boundsHeight)
      .clamp(1.0, maxScale)
      .toDouble();

  // The viewer's child spans the whole viewport, so keep it covering the view.
  double axisTranslation(double center, double view) {
    return (view / 2 - center * scale)
        .clamp(view - view * scale, 0.0)
        .toDouble();
  }

  final tx = axisTranslation((minX + maxX) / 2, viewport.width);
  final ty = axisTranslation((minY + maxY) / 2, viewport.height);
  return Matrix4.diagonal3Values(scale, scale, 1)..setTranslationRaw(tx, ty, 0);
}

/// Exact code relationship used by focused display: [code] is the parent
/// itself or one of its `parent-*` children. No geometry inference.
bool isFocusRelatedZoneCode(String code, String parentCode) {
  return code == parentCode || code.startsWith('$parentCode-');
}

/// Ray-casting point-in-polygon test in map percentage space.
bool mapAreaContains(MapArea area, double x, double y) {
  final points = area.points;
  if (points.length < 3) return false;
  var inside = false;
  for (var i = 0, j = points.length - 1; i < points.length; j = i++) {
    final a = points[i];
    final b = points[j];
    if ((a.y > y) != (b.y > y) &&
        x < (b.x - a.x) * (y - a.y) / (b.y - a.y) + a.x) {
      inside = !inside;
    }
  }
  return inside;
}

class FloorMapWidget extends StatefulWidget {
  final FloorMapData data;
  final String? selectedParentZone;
  final String? selectedChildZone;
  final bool enableZoom;
  final ValueChanged<MapZone>? onZoneTap;

  /// When set, only this parent area and its `parent-*` child zones are
  /// rendered (display filter only; source data is untouched). Null renders
  /// the full floor.
  final String? focusParentZone;

  /// When true, the initial viewport zooms to the selected parent polygon.
  /// Applied once per map/parent change; manual pan/zoom is never reset.
  final bool autoFocusParent;

  /// Upper zoom bound for both gestures and the initial auto-focus.
  final double maxScale;

  /// Traveling edge highlight on the selected polygon. False (e.g. for
  /// low-end devices) keeps only the static selected fill + outline.
  final bool enablePolygonAnimation;

  const FloorMapWidget({
    super.key,
    required this.data,
    this.selectedParentZone,
    this.selectedChildZone,
    this.focusParentZone,
    this.autoFocusParent = false,
    this.maxScale = 4,
    this.enablePolygonAnimation = true,
    this.enableZoom = true,
    this.onZoneTap,
  });

  @override
  State<FloorMapWidget> createState() => _FloorMapWidgetState();
}

class _FloorMapWidgetState extends State<FloorMapWidget>
    with SingleTickerProviderStateMixin {
  late final TransformationController _transformationController;

  /// Short attention effect: one forward run covering
  /// [highlightLoops] trips around the selected parent polygon, then the
  /// ticker stops for good (static outline stays).
  late final AnimationController _highlightController;

  static const int highlightLoops = 3;
  static const Duration _highlightLoopDuration = Duration(milliseconds: 3200);

  /// `mapId|parent` the highlight belongs to. Only a change here restarts
  /// it; child changes, rebuilds, pan/zoom and collapse never do.
  String? _highlightKey;

  /// All loops finished for [_highlightKey].
  bool _highlightDone = false;

  // Focused-mode filter cache: reused while the source map instance and
  // focusParentZone are unchanged, so rebuilds (child change, controller
  // notifications, pan/zoom) keep identical lists and painters skip repaint.
  FloorMapData? _visibleSource;
  String? _visibleFocus;
  List<MapArea> _visibleAreas = const <MapArea>[];
  List<MapZone> _visibleZones = const <MapZone>[];
  List<MapArea> _visibleChildAreas = const <MapArea>[];

  /// Un-inset tap targets for [_visibleChildAreas], same focus filter.
  List<MapArea> _visibleChildHitAreas = const <MapArea>[];

  /// Reused while the highlighted area is the same instance, so its cached
  /// path metric survives rebuilds.
  SelectedAreaHighlightPainter? _highlightPainter;

  /// `mapId|parent` last auto-focused (null = full-floor view), so the
  /// viewport is refit only when that changes, never on ordinary rebuilds.
  String? _autoFocusKey;

  /// Highlight layer is shown (selection visible, animation allowed).
  bool _highlightActive = false;

  /// Pan/zoom gesture in progress: the highlight holds its position.
  bool _interacting = false;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _highlightController = AnimationController(
      vsync: this,
      // Linear: constant perimeter speed, no corner easing.
      duration: _highlightLoopDuration * highlightLoops,
    )..addStatusListener(_onHighlightStatus);
  }

  /// One setState at the end (not per frame) to drop the highlight layer.
  void _onHighlightStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    setState(() {
      _highlightDone = true;
      _highlightActive = false;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncHighlight();
  }

  bool get _hasVisibleSelectedArea {
    final parent = widget.selectedParentZone;
    if (parent == null) return false;
    final focus = widget.focusParentZone;
    if (focus != null && !isFocusRelatedZoneCode(parent, focus)) return false;
    return widget.data.areas.any((area) => area.code == parent);
  }

  /// Static outline only when disabled, finished, or under the platform
  /// reduce-motion setting. Otherwise runs (holding still during pan/zoom or
  /// while disabled e.g. collapsed) and resumes from the same point.
  void _syncHighlight() {
    final key = '${widget.data.id}|${widget.selectedParentZone}';
    if (key != _highlightKey) {
      _highlightKey = key;
      _highlightDone = false;
      _highlightController.reset();
    }
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _highlightActive =
        !_highlightDone &&
        widget.enablePolygonAnimation &&
        !reduceMotion &&
        _hasVisibleSelectedArea;
    final shouldRun = _highlightActive && !_interacting;
    if (shouldRun) {
      if (!_highlightController.isAnimating) _highlightController.forward();
    } else if (_highlightController.isAnimating) {
      _highlightController.stop();
    }
  }

  // Gesture pause only toggles the ticker; no rebuild, the segment freezes
  // in place and resumes from the same point.
  void _onInteractionStart(ScaleStartDetails _) {
    _interacting = true;
    _syncHighlight();
  }

  void _onInteractionEnd(ScaleEndDetails _) {
    _interacting = false;
    _syncHighlight();
  }

  @override
  void didUpdateWidget(covariant FloorMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.id != widget.data.id) {
      _transformationController.value = Matrix4.identity();
    }
    _syncHighlight();
  }

  @override
  void dispose() {
    _highlightController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _maybeAutoFocus(Size viewport) {
    final key = widget.autoFocusParent
        ? '${widget.data.id}|${widget.selectedParentZone}'
        : null;
    if (key == _autoFocusKey) return;
    if (key != null && (viewport.isEmpty || !viewport.isFinite)) return;
    _autoFocusKey = key;
    final matrix = key == null
        ? null
        : floorMapFocusMatrix(
            widget.data,
            widget.selectedParentZone,
            viewport,
            maxScale: widget.maxScale,
          );
    // Controller changes notify InteractiveViewer; defer past this build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _transformationController.value = matrix ?? Matrix4.identity();
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _maybeAutoFocus(constraints.biggest);
        return _buildViewer();
      },
    );
  }

  Widget _buildViewer() {
    final displayAspect = floorMapDisplayAspectRatio(widget.data);

    return InteractiveViewer(
      transformationController: _transformationController,
      minScale: 1,
      maxScale: widget.maxScale,
      boundaryMargin: const EdgeInsets.all(80),
      panEnabled: widget.enableZoom,
      scaleEnabled: widget.enableZoom,
      clipBehavior: Clip.hardEdge,
      onInteractionStart: _onInteractionStart,
      onInteractionEnd: _onInteractionEnd,
      // Floor is fitted and centred in the full viewport, so a viewport with a
      // different aspect (fullscreen) shows no dead band at the edges once
      // zoomed.
      child: RepaintBoundary(
        child: Center(
          child: AspectRatio(
            aspectRatio: displayAspect,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return _buildRotationFrame(
                  displaySize: Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRotationFrame({required Size displaySize}) {
    final quarterTurn = isQuarterTurnMapRotation(widget.data.rotationDeg);
    final logicalSize = quarterTurn
        ? Size(displaySize.height, displaySize.width)
        : displaySize;
    final rotationRadians =
        normalizedMapRotation(widget.data.rotationDeg) * math.pi / 180;
    // Badges shrink on small (embedded) maps; full size from 900px up.
    final labelReference = quarterTurn
        ? displaySize.longestSide
        : displaySize.width;
    final labelScale = (labelReference / 900).clamp(0.8, 1.0).toDouble();

    // OverflowBox lets the swapped (quarter-turn) scene keep its true size;
    // a plain Center would clamp it to the display box and squash the image.
    return ClipRect(
      child: OverflowBox(
        minWidth: logicalSize.width,
        maxWidth: logicalSize.width,
        minHeight: logicalSize.height,
        maxHeight: logicalSize.height,
        child: Transform.rotate(
          angle: rotationRadians,
          child: SizedBox(
            width: logicalSize.width,
            height: logicalSize.height,
            child: _buildLogicalScene(
              rotationRadians,
              logicalSize,
              labelScale,
            ),
          ),
        ),
      ),
    );
  }

  /// Visible areas/zones/child areas; full mode returns the source lists
  /// directly.
  void _syncVisibleOverlays() {
    final data = widget.data;
    final focus = widget.focusParentZone;
    if (identical(data, _visibleSource) && focus == _visibleFocus) return;
    _visibleSource = data;
    _visibleFocus = focus;
    _visibleAreas = focus == null
        ? data.areas
        : data.areas
              .where((area) => isFocusRelatedZoneCode(area.code, focus))
              .toList(growable: false);
    if (focus == null) {
      _visibleZones = data.zones;
    } else {
      final related = data.zones
          .where((zone) => isFocusRelatedZoneCode(zone.code, focus))
          .toList(growable: false);
      // A focused parent with visible children drops its own badge: the
      // children label the area and the parent badge would sit on their
      // shared dividers.
      final hasChildLabel = related.any((zone) => zone.code != focus);
      _visibleZones = hasChildLabel
          ? related
                .where((zone) => zone.code != focus)
                .toList(growable: false)
          : related;
    }
    _visibleChildAreas = _focusFiltered(childAreasFor(data), focus);
    _visibleChildHitAreas = _focusFiltered(childHitAreasFor(data), focus);
  }

  static List<MapArea> _focusFiltered(List<MapArea> areas, String? focus) {
    if (focus == null || areas.isEmpty) return areas;
    return areas
        .where((area) => isFocusRelatedZoneCode(area.code, focus))
        .toList(growable: false);
  }

  SelectedAreaHighlightPainter _highlightPainterFor(MapArea area) {
    final cached = _highlightPainter;
    if (cached != null && identical(cached.area, area)) return cached;
    return _highlightPainter = SelectedAreaHighlightPainter(
      area: area,
      progress: _highlightController,
      loops: highlightLoops,
    );
  }

  /// Smallest visible polygon (child or parent) containing the tap, so a
  /// tap inside A1-1 resolves to A1-1 rather than A1. Children are tested
  /// with their un-inset hit areas, so the drawn gap between siblings still
  /// resolves to a child. [local] is in the unrotated logical scene, so
  /// rotated layouts need no extra mapping.
  void _handleSceneTap(Offset local, Size logicalSize) {
    final onZoneTap = widget.onZoneTap;
    if (onZoneTap == null || logicalSize.isEmpty) return;
    final x = local.dx / logicalSize.width * 100;
    final y = local.dy / logicalSize.height * 100;

    MapArea? best;
    var bestBoxSize = double.infinity;
    for (final candidates in <List<MapArea>>[
      _visibleChildHitAreas,
      _visibleAreas,
    ]) {
      for (final area in candidates) {
        if (!mapAreaContains(area, x, y)) continue;
        var minX = double.infinity, minY = double.infinity;
        var maxX = -double.infinity, maxY = -double.infinity;
        for (final point in area.points) {
          minX = math.min(minX, point.x);
          maxX = math.max(maxX, point.x);
          minY = math.min(minY, point.y);
          maxY = math.max(maxY, point.y);
        }
        final boxSize = (maxX - minX) * (maxY - minY);
        if (boxSize < bestBoxSize) {
          bestBoxSize = boxSize;
          best = area;
        }
      }
    }

    final code = best?.code;
    if (code == null) return;
    onZoneTap(
      findZoneByCode(widget.data, code) ?? MapZone(code: code, x: x, y: y),
    );
  }

  Widget _buildLogicalScene(
    double rotationRadians,
    Size logicalSize,
    double labelScale,
  ) {
    _syncVisibleOverlays();
    final areas = _visibleAreas;
    final zones = _visibleZones;
    final childAreas = _visibleChildAreas;
    MapArea? highlightArea;
    if (_highlightActive) {
      for (final area in areas) {
        if (isSelectedMapArea(area, widget.selectedParentZone)) {
          highlightArea = area;
          break;
        }
      }
    }

    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: <Widget>[
        Image.asset(widget.data.imageAsset, fit: BoxFit.fill),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: FloorMapPainter(
                areas: areas,
                selectedParentZone: widget.selectedParentZone,
                selectedChildZone: widget.selectedChildZone,
              ),
            ),
          ),
        ),
        if (childAreas.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _ChildAreaPainter(
                  areas: childAreas,
                  selectedChildZone: widget.selectedChildZone,
                ),
              ),
            ),
          ),
        if (highlightArea != null)
          Positioned.fill(
            child: IgnorePointer(
              // Own layer: animation frames repaint only this segment, never
              // the floor image, static polygons or labels.
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _highlightPainterFor(highlightArea),
                ),
              ),
            ),
          ),
        if (widget.onZoneTap != null)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapUp: (details) =>
                  _handleSceneTap(details.localPosition, logicalSize),
            ),
          ),
        for (final zone in zones)
          Positioned(
            left: logicalSize.width * zone.x / 100 + zone.offsetX,
            top: logicalSize.height * zone.y / 100 + zone.offsetY,
            child: FractionalTranslation(
              translation: const Offset(-0.5, -0.5),
              child: Transform.rotate(
                angle: -rotationRadians,
                child: _MapZoneLabel(
                  zone: zone,
                  isMajor: isMajorMapZone(widget.data, zone),
                  isActive:
                      zone.code == widget.selectedChildZone ||
                      (widget.selectedChildZone == null &&
                          zone.code == widget.selectedParentZone),
                  scale: labelScale,
                  onTap: widget.onZoneTap,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Child sub-area outlines, drawn above the parent layer. Repaints only when
/// the (cached) area list instance or the selected child changes.
class _ChildAreaPainter extends CustomPainter {
  final List<MapArea> areas;
  final String? selectedChildZone;

  const _ChildAreaPainter({required this.areas, this.selectedChildZone});

  static const Color _childPurple = Color(0xFFD63AF9);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = _childPurple
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeJoin = StrokeJoin.round;

    MapArea? selected;
    for (final area in areas) {
      if (area.points.isEmpty) continue;
      if (area.code == selectedChildZone) {
        // Drawn last so its outline sits above neighbours.
        selected = area;
        continue;
      }
      canvas.drawPath(mapAreaPath(area, size), stroke);
    }

    if (selected == null) return;
    final path = mapAreaPath(selected, size);
    canvas.drawPath(
      path,
      Paint()
        ..color = _childPurple.withValues(alpha: 0.16)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(path, stroke..strokeWidth = 2.6);
  }

  @override
  bool shouldRepaint(covariant _ChildAreaPainter oldDelegate) {
    return !identical(oldDelegate.areas, areas) ||
        oldDelegate.selectedChildZone != selectedChildZone;
  }
}

/// Zone code on a compact white badge: red for parents, purple for children
/// (matching their outlines); the selected label turns solid.
class _MapZoneLabel extends StatelessWidget {
  final MapZone zone;
  final bool isMajor;
  final bool isActive;
  final ValueChanged<MapZone>? onTap;

  /// Multiplier for font size and padding (0.8–1.0, from the map size).
  final double scale;

  const _MapZoneLabel({
    required this.zone,
    required this.isMajor,
    required this.isActive,
    required this.onTap,
    this.scale = 1,
  });

  static const Color _parentRed = Color(0xFFE53935);
  static const Color _childBorder = Color(0xFFD63AF9);
  static const Color _childText = Color(0xFFC026D3);

  static const double _activeBorderWidth = 1.5;
  static const double _minTouchHeight = 24;
  static const Duration _transition = Duration(milliseconds: 120);

  @override
  Widget build(BuildContext context) {
    final accent = isMajor ? _parentRed : _childText;
    final borderWidth = isActive
        ? _activeBorderWidth
        : (isMajor ? 1.2 : 1.0);
    // Base padding minus the extra border width, so the badge's outer size
    // (and its centred anchor) stays the same when it becomes active.
    final restBorderWidth = isMajor ? 1.2 : 1.0;
    final borderDelta = borderWidth - restBorderWidth;
    final padding = EdgeInsets.symmetric(
      horizontal: (isMajor ? 6.0 : 4.0) * scale - borderDelta,
      vertical: (isMajor ? 2.5 : 1.5) * scale - borderDelta,
    );
    final fillColor = isActive
        ? accent
        : Colors.white.withValues(alpha: isMajor ? 0.92 : 0.90);

    final badge = AnimatedContainer(
      duration: _transition,
      padding: padding,
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(isMajor ? 4 : 3),
        border: Border.all(
          color: isActive
              ? Colors.white
              : (isMajor ? _parentRed : _childBorder),
          width: borderWidth,
        ),
        boxShadow: <BoxShadow>[
          // Selected: 1px outer ring in the fill colour, drawn outside the
          // box so layout is unchanged; separates the white border from the
          // drawing underneath.
          BoxShadow(
            color: isActive ? accent : accent.withValues(alpha: 0),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: AnimatedDefaultTextStyle(
        duration: _transition,
        style: DefaultTextStyle.of(context).style.merge(
          TextStyle(
            color: isActive ? Colors.white : accent,
            fontSize: (isMajor ? 12.5 : 9.5) * scale,
            fontWeight: isActive
                ? FontWeight.w900
                : (isMajor ? FontWeight.w800 : FontWeight.w700),
            height: 1,
          ),
        ),
        child: Text(zone.code, maxLines: 1, softWrap: false),
      ),
    );

    // Invisible touch area around the badge (no fill); the badge itself
    // stays centred, so the anchor is unchanged.
    final label = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _minTouchHeight),
        child: Center(widthFactor: 1, heightFactor: 1, child: badge),
      ),
    );

    final tap = onTap;
    if (tap == null) return IgnorePointer(child: label);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        // Opaque so the padding counts as part of the target.
        behavior: HitTestBehavior.opaque,
        onTap: () => tap(zone),
        child: label,
      ),
    );
  }
}
