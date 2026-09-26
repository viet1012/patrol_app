import 'dart:math' as math;

import 'package:flutter/material.dart';

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
            child: _buildLogicalScene(rotationRadians),
          ),
        ),
      ),
    );
  }

  /// Visible areas/zones; full mode returns the source lists directly.
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
    _visibleZones = focus == null
        ? data.zones
        : data.zones
              .where((zone) => isFocusRelatedZoneCode(zone.code, focus))
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

  Widget _buildLogicalScene(double rotationRadians) {
    _syncVisibleOverlays();
    final areas = _visibleAreas;
    final zones = _visibleZones;
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
        if (highlightArea != null)
          Positioned.fill(
            child: IgnorePointer(
              // Own layer: animation frames repaint only this segment, never
              // the floor image, static polygons or badges.
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _highlightPainterFor(highlightArea),
                ),
              ),
            ),
          ),
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  for (final zone in zones)
                    Positioned(
                      left: constraints.maxWidth * zone.x / 100 + zone.offsetX,
                      top: constraints.maxHeight * zone.y / 100 + zone.offsetY,
                      child: FractionalTranslation(
                        translation: const Offset(-0.5, -0.5),
                        child: Transform.rotate(
                          angle: -rotationRadians,
                          child: _MapZoneBadge(
                            zone: zone,
                            isMajor: isMajorMapZone(widget.data, zone),
                            isActive:
                                zone.code == widget.selectedChildZone ||
                                (widget.selectedChildZone == null &&
                                    zone.code == widget.selectedParentZone),
                            isRelated:
                                widget.selectedChildZone != null &&
                                zone.code == widget.selectedParentZone,
                            onTap: widget.onZoneTap,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MapZoneBadge extends StatefulWidget {
  final MapZone zone;
  final bool isMajor;
  final bool isActive;
  final bool isRelated;

  final ValueChanged<MapZone>? onTap;

  const _MapZoneBadge({
    required this.zone,
    required this.isMajor,
    required this.isActive,
    required this.isRelated,
    required this.onTap,
  });

  @override
  State<_MapZoneBadge> createState() => _MapZoneBadgeState();
}

class _MapZoneBadgeState extends State<_MapZoneBadge> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF2563EB);
    const selectedBlue = Color(0xFF1D4ED8);
    const lightBlue = Color(0xFF3B82F6);
    const paleBlue = Color(0xFFDBEAFE);
    final selected = widget.isActive;
    final parent = !selected && widget.isRelated;

    // Glass badges: low-opacity fill so the drawing underneath stays
    // visible; the border carries the emphasis and a thin text halo keeps
    // the code readable over both light and dark parts of the map.
    final Color fillColor;
    final Color borderColor;
    final double borderWidth;
    final Color textColor;
    final Color haloColor;
    if (selected) {
      // Pale-blue glass (stronger than parent/sibling) keeps the royal-blue
      // label high-contrast while the drawing stays visible underneath.
      fillColor = paleBlue.withValues(alpha: 0.40);
      borderColor = selectedBlue;
      borderWidth = 3.0;
      textColor = selectedBlue;
      haloColor = Colors.white;
    } else if (parent) {
      fillColor = paleBlue.withValues(alpha: 0.12);
      borderColor = blue;
      borderWidth = 2.0;
      textColor = blue;
      haloColor = Colors.white;
    } else {
      fillColor = Colors.white.withValues(alpha: 0.05);
      borderColor = lightBlue;
      borderWidth = widget.isMajor ? 1.8 : 1.5;
      textColor = lightBlue;
      haloColor = Colors.white;
    }
    final scale = selected ? 1.06 : (_hovered ? 1.03 : 1.0);

    return Tooltip(
      message: widget.zone.code,
      child: MouseRegion(
        cursor: widget.onTap == null
            ? MouseCursor.defer
            : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap == null ? null : () => widget.onTap!(widget.zone),
          child: AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: _withSelectionMarks(
              selected: selected,
              badge: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: EdgeInsets.symmetric(
                  horizontal: widget.isMajor ? 8 : 6,
                  vertical: widget.isMajor ? 4 : 3,
                ),
                // No box shadow: it would smear through the translucent fill.
                decoration: BoxDecoration(
                  color: fillColor,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: borderColor, width: borderWidth),
                ),
                child: Text(
                  widget.zone.code,
                  maxLines: 1,
                  style: TextStyle(
                    color: textColor,
                    fontSize: widget.isMajor ? 11.5 : 10,
                    fontWeight: selected || widget.isMajor
                        ? FontWeight.w800
                        : FontWeight.w700,
                    height: 1,
                    shadows: <Shadow>[
                      Shadow(color: haloColor, blurRadius: 2.5),
                      Shadow(color: haloColor.withValues(alpha: 0.7)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const Color _selectionCyan = Color(0xFF22D3EE);

  /// Selected-only emphasis drawn outside the badge bounds (no layout
  /// change, so size and anchor stay identical): a cyan outer ring with an
  /// outside-only glow, plus a small corner dot. The fill stays translucent.
  Widget _withSelectionMarks({required bool selected, required Widget badge}) {
    if (!selected) return badge;
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        badge,
        Positioned(
          left: -3,
          top: -3,
          right: -3,
          bottom: -3,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _selectionCyan.withValues(alpha: 0.85),
                  width: 1.5,
                ),
                boxShadow: <BoxShadow>[
                  // Outer-only blur: nothing smears under the glass fill.
                  BoxShadow(
                    color: _selectionCyan.withValues(alpha: 0.45),
                    blurRadius: 5,
                    blurStyle: BlurStyle.outer,
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -5,
          right: -5,
          child: IgnorePointer(
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _selectionCyan,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
