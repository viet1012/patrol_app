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

/// Display aspect of [data] rotated by its own `rotationDeg` plus
/// [extraRotationDeg] (e.g. a fullscreen auto-rotation).
double floorMapDisplayAspectRatio(
  FloorMapData data, {
  double extraRotationDeg = 0,
}) {
  return isQuarterTurnMapRotation(data.rotationDeg + extraRotationDeg)
      ? data.imageHeight / data.imageWidth
      : data.imageWidth / data.imageHeight;
}

bool isMajorMapZone(FloorMapData data, MapZone zone) {
  return data.areas.any((area) => area.code == zone.code);
}

/// Bounding-box area of the [areaCode] parent polygon as a fraction of the
/// whole map (0–1); null when the polygon is missing.
double? floorMapAreaBoundsRatio(FloorMapData data, String? areaCode) {
  final area = findAreaByCode(data, areaCode);
  if (area == null || area.points.isEmpty) return null;
  var minX = double.infinity, minY = double.infinity;
  var maxX = -double.infinity, maxY = -double.infinity;
  for (final point in area.points) {
    minX = math.min(minX, point.x);
    maxX = math.max(maxX, point.x);
    minY = math.min(minY, point.y);
    maxY = math.max(maxY, point.y);
  }
  return (maxX - minX) * (maxY - minY) / (100 * 100);
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
  double extraRotationDeg = 0,
}) {
  if (areaCode == null || viewport.isEmpty || !viewport.isFinite) return null;
  final rotationDeg = data.rotationDeg + extraRotationDeg;
  MapArea? area;
  for (final candidate in data.areas) {
    if (candidate.code == areaCode) {
      area = candidate;
      break;
    }
  }
  if (area == null || area.points.isEmpty) return null;

  // Rendered child: AspectRatio fitted and centred inside the viewport.
  final aspect = floorMapDisplayAspectRatio(
    data,
    extraRotationDeg: extraRotationDeg,
  );
  final displayWidth = math.min(viewport.width, viewport.height * aspect);
  final display = Size(displayWidth, displayWidth / aspect);
  final originX = (viewport.width - display.width) / 2;
  final originY = (viewport.height - display.height) / 2;
  final logical = isQuarterTurnMapRotation(rotationDeg)
      ? Size(display.height, display.width)
      : display;
  final angle = normalizedMapRotation(rotationDeg) * math.pi / 180;
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
  /// low-end devices) keeps only the static selected outline.
  final bool enablePolygonAnimation;

  /// Washes the floor drawing towards white so outlines and badges stand
  /// out (effective 0–0.8, 0 = original image). Overlays are not faded;
  /// while focused, the selected parent polygon keeps the original drawing.
  final double imageFade;

  /// Extra wash outside the selected parent polygon while focused
  /// (effective 0–0.6, 0 = off). Ignored when [focusParentZone] is null.
  final double spotlightFade;

  /// Auto-focus padding around the parent polygon (fraction of its bounds
  /// per side), passed to [floorMapFocusMatrix].
  final double focusPadding;

  /// Added to `data.rotationDeg` for display only (e.g. 90 to fit a portrait
  /// screen). Data, tap hit-testing and zones stay in the logical scene.
  final double extraRotationDeg;

  /// Full-floor mode only: [imageFade] used once zoomed in past
  /// [zoomedInScale]. Null keeps [imageFade] at every zoom.
  final double? zoomedInImageFade;

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
    this.imageFade = 0.40,
    this.spotlightFade = 0.30,
    this.focusPadding = 0.2,
    this.extraRotationDeg = 0,
    this.zoomedInImageFade,
  });

  /// Viewer scale above which the full-floor view counts as zoomed in:
  /// child badges appear and [zoomedInImageFade] applies.
  static const double zoomedInScale = 1.5;

  @override
  State<FloorMapWidget> createState() => _FloorMapWidgetState();
}

class _FloorMapWidgetState extends State<FloorMapWidget>
    with TickerProviderStateMixin {
  late final TransformationController _transformationController;

  /// Traveling edge highlight: repeats one linear trip around the highlight
  /// target (selected child with a polygon, else the selected parent) while
  /// a parent is selected and visible. The trip duration follows the
  /// target's on-screen perimeter (see [_applyHighlightDuration]).
  late final AnimationController _highlightController;

  /// Running segment opacity: 0 during pan/zoom, fades back in on release.
  late final AnimationController _highlightVisibility;

  static const Duration _highlightFadeIn = Duration(milliseconds: 150);

  /// On-screen speed of the running segment and the trip-duration bounds.
  static const double _highlightScreenSpeed = 120;
  static const double _highlightMinSeconds = 2;
  static const double _highlightMaxSeconds = 6;

  /// Viewer-scale step at which the trip duration is recomputed.
  static const double _durationScaleStep = 0.25;
  double _durationScaleBucket = 1;

  /// Target perimeter in logical pixels (updated when target or size change).
  double _highlightPerimeter = 0;

  /// `mapId|target` the highlight belongs to. Only a change here restarts
  /// it from the start; rebuilds, pan/zoom and collapse never do.
  String? _highlightKey;

  // Focused-mode filter cache: reused while the source map instance and
  // focusParentZone are unchanged, so rebuilds (child change, controller
  // notifications, pan/zoom) keep identical lists and painters skip repaint.
  FloorMapData? _visibleSource;
  String? _visibleFocus;
  List<MapArea> _visibleAreas = const <MapArea>[];
  List<MapZone> _visibleZones = const <MapZone>[];
  List<MapArea> _visibleChildAreas = const <MapArea>[];

  /// Focused parent's zone (null in full mode); its badge is drawn last,
  /// above its `parent-*` child badges.
  MapZone? _visibleFocusZone;

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

  /// Viewer scale is past [FloorMapWidget.zoomedInScale]. Flips only when
  /// the threshold is crossed, so listeners rebuild once, not per frame.
  final ValueNotifier<bool> _zoomedIn = ValueNotifier<bool>(false);

  /// Viewer scale rounded to [_badgeScaleStep]; badges are drawn at its
  /// inverse so they keep their on-screen size. Only the badge layer
  /// listens, and only once per step.
  final ValueNotifier<double> _viewerScale = ValueNotifier<double>(1);
  static const double _badgeScaleStep = 0.05;

  /// Badge layer rebuild trigger: zoom threshold or badge scale step.
  late final Listenable _badgeLayerListenable = Listenable.merge(
    <Listenable>[_zoomedIn, _viewerScale],
  );

  /// Display rotation: the map's own rotation plus the extra one.
  double get _rotationDeg =>
      widget.data.rotationDeg + widget.extraRotationDeg;

  void _onTransformChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    _zoomedIn.value = scale > FloorMapWidget.zoomedInScale;
    // Rounded DOWN (epsilon absorbs float error at exact steps), so the
    // inverse-scaled badge is never smaller on screen than at 1×: the touch
    // target stays ≥ 24 px.
    _viewerScale.value = math.max(
      _badgeScaleStep,
      (scale / _badgeScaleStep + 1e-6).floorToDouble() * _badgeScaleStep,
    );
    final bucket = _durationBucketFor(scale);
    if (bucket != _durationScaleBucket) {
      _durationScaleBucket = bucket;
      _applyHighlightDuration();
    }
  }

  static double _durationBucketFor(double scale) {
    return math.max(
      _durationScaleStep,
      (scale / _durationScaleStep + 1e-6).floorToDouble() * _durationScaleStep,
    );
  }

  /// One trip = on-screen perimeter / [_highlightScreenSpeed], clamped to
  /// 2–6 s. Recomputed only on target/size change or per 0.25 scale step,
  /// never per frame; a running loop restarts from its current position.
  void _applyHighlightDuration() {
    if (_highlightPerimeter <= 0) return;
    final seconds =
        (_highlightPerimeter * _durationScaleBucket / _highlightScreenSpeed)
            .clamp(_highlightMinSeconds, _highlightMaxSeconds);
    final duration = Duration(microseconds: (seconds * 1e6).round());
    if (duration == _highlightController.duration) return;
    _highlightController.duration = duration;
    if (_highlightController.isAnimating) _highlightController.repeat();
  }

  /// Selected child with its own (visible) polygon: the highlight target
  /// instead of its parent. Same instance as in the cached child list.
  MapArea? get _targetChildArea {
    final child = widget.selectedChildZone;
    if (child == null) return null;
    final focus = widget.focusParentZone;
    if (focus != null && !isFocusRelatedZoneCode(child, focus)) return null;
    for (final area in childAreasFor(widget.data)) {
      if (area.code == child) return area;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController()
      ..addListener(_onTransformChanged);
    _highlightController = AnimationController(
      vsync: this,
      // Linear: constant perimeter speed, no corner easing. Replaced by the
      // perimeter-based duration once the target is laid out.
      duration: const Duration(milliseconds: 3200),
    );
    _highlightVisibility = AnimationController(
      vsync: this,
      duration: _highlightFadeIn,
      value: 1,
    );
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

  /// Static outline only when disabled (e.g. collapsed card, or a card
  /// under the expanded dialog) or under the platform reduce-motion
  /// setting. Otherwise repeats continuously, holding still during pan/zoom
  /// and resuming from the same point.
  void _syncHighlight() {
    final target = _targetChildArea?.code ?? widget.selectedParentZone;
    final key = '${widget.data.id}|$target';
    if (key != _highlightKey) {
      _highlightKey = key;
      _highlightController.reset();
    }
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _highlightActive =
        widget.enablePolygonAnimation &&
        !reduceMotion &&
        _hasVisibleSelectedArea;
    final shouldRun = _highlightActive && !_interacting;
    if (shouldRun) {
      // repeat() continues from the current value, so a paused segment
      // resumes where it stopped.
      if (!_highlightController.isAnimating) _highlightController.repeat();
    } else if (_highlightController.isAnimating) {
      _highlightController.stop();
    }
  }

  // Gesture pause: no rebuild. The running segment is hidden (static
  // outline + glow stay), then fades back in over 150 ms on release and
  // continues from the same point.
  void _onInteractionStart(ScaleStartDetails _) {
    _interacting = true;
    _highlightVisibility.value = 0;
    _syncHighlight();
  }

  void _onInteractionEnd(ScaleEndDetails _) {
    _interacting = false;
    _syncHighlight();
    _highlightVisibility.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant FloorMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // New map or new display rotation: old pan/zoom no longer fits. A
    // focused view is refit by _maybeAutoFocus (its key includes both).
    if (oldWidget.data.id != widget.data.id ||
        oldWidget.extraRotationDeg != widget.extraRotationDeg) {
      _transformationController.value = Matrix4.identity();
    }
    _syncHighlight();
  }

  @override
  void dispose() {
    _highlightController.dispose();
    _highlightVisibility.dispose();
    _transformationController
      ..removeListener(_onTransformChanged)
      ..dispose();
    _zoomedIn.dispose();
    _viewerScale.dispose();
    super.dispose();
  }

  void _maybeAutoFocus(Size viewport) {
    final key = widget.autoFocusParent
        ? '${widget.data.id}|${widget.selectedParentZone}|$_rotationDeg'
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
            padding: widget.focusPadding,
            maxScale: widget.maxScale,
            extraRotationDeg: widget.extraRotationDeg,
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
    final displayAspect = floorMapDisplayAspectRatio(
      widget.data,
      extraRotationDeg: widget.extraRotationDeg,
    );

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
    final quarterTurn = isQuarterTurnMapRotation(_rotationDeg);
    final logicalSize = quarterTurn
        ? Size(displaySize.height, displaySize.width)
        : displaySize;
    final rotationRadians =
        normalizedMapRotation(_rotationDeg) * math.pi / 180;
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
            child: _buildLogicalScene(rotationRadians, logicalSize, labelScale),
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
    // Focused: the parent badge is kept apart (drawn last, at its zone
    // position); _visibleZones holds only its `parent-*` children.
    _visibleZones = focus == null
        ? data.zones
        : data.zones
              .where(
                (zone) =>
                    zone.code != focus &&
                    isFocusRelatedZoneCode(zone.code, focus),
              )
              .toList(growable: false);
    _visibleFocusZone = focus == null ? null : findZoneByCode(data, focus);
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
      // Constant on-screen width/length; repaints (no rebuild) per step.
      viewerScale: _viewerScale,
      visibility: _highlightVisibility,
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
    final focusZone = _visibleFocusZone;
    final childAreas = _visibleChildAreas;
    // Highlight target: the selected child when it has a polygon, else the
    // selected parent.
    final targetChild = _targetChildArea;
    MapArea? targetArea = targetChild;
    if (targetArea == null) {
      for (final area in areas) {
        if (isSelectedMapArea(area, widget.selectedParentZone)) {
          targetArea = area;
          break;
        }
      }
    }
    final highlightArea = _highlightActive ? targetArea : null;
    if (highlightArea != null) {
      final perimeter = SelectedAreaHighlightPainter.perimeterFor(
        highlightArea,
        logicalSize,
      );
      if ((perimeter - _highlightPerimeter).abs() > 0.5) {
        _highlightPerimeter = perimeter;
        _applyHighlightDuration();
      }
    }
    final imageFade = widget.imageFade.clamp(0.0, 0.8).toDouble();
    final spotlightFade = widget.spotlightFade.clamp(0.0, 0.6).toDouble();
    final focused = widget.focusParentZone != null;
    // The selected parent always keeps the original drawing (focus and full
    // floor alike).
    final fadeHole = findAreaByCode(widget.data, widget.selectedParentZone);
    // Full-floor view may use a lighter wash once zoomed in.
    final zoomedFade = widget.zoomedInImageFade?.clamp(0.0, 0.8).toDouble();
    final fadeFollowsZoom =
        !focused && zoomedFade != null && zoomedFade != imageFade;
    final hasFade =
        imageFade > 0 ||
        (fadeFollowsZoom && zoomedFade > 0) ||
        (focused && spotlightFade > 0);
    Widget fadeLayer(double fade) => CustomPaint(
      painter: _FadePainter(
        hole: fadeHole,
        imageFade: fade,
        spotlightFade: spotlightFade,
        focused: focused,
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: <Widget>[
        // Original drawing; any wash is a separate layer above it.
        RepaintBoundary(
          child: Image.asset(widget.data.imageAsset, fit: BoxFit.fill),
        ),
        if (hasFade)
          Positioned.fill(
            child: IgnorePointer(
              // Own layer: changing a fade (or crossing the zoom threshold)
              // repaints only this wash, never the image, outlines or badges.
              child: RepaintBoundary(
                child: fadeFollowsZoom
                    ? ValueListenableBuilder<bool>(
                        valueListenable: _zoomedIn,
                        builder: (context, zoomedIn, _) =>
                            fadeLayer(zoomedIn ? zoomedFade : imageFade),
                      )
                    : fadeLayer(imageFade),
              ),
            ),
          ),
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: FloorMapPainter(
                  areas: areas,
                  selectedParentZone: widget.selectedParentZone,
                  selectedChildZone: widget.selectedChildZone,
                  // Full floor: unselected parents as raised cards.
                  raised: !focused,
                  childTargeted: targetChild != null,
                ),
              ),
            ),
          ),
        ),
        if (childAreas.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _ChildAreaPainter(
                    areas: childAreas,
                    selectedChildZone: widget.selectedChildZone,
                    selectedParentZone: widget.selectedParentZone,
                    raised: !focused,
                  ),
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
        // Badges in their own layer; the only layer that follows zoom (the
        // threshold for child badges and the 0.05-step inverse scale).
        Positioned.fill(
          child: RepaintBoundary(
            child: ListenableBuilder(
              listenable: _badgeLayerListenable,
              builder: (context, _) => _buildBadges(
                zones,
                focusZone,
                rotationRadians,
                logicalSize,
                labelScale,
                showChildren: focused || _zoomedIn.value,
                inverseScale: 1 / _viewerScale.value,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Zone badges. Without [showChildren] (full floor, zoomed out) only
  /// parent badges plus the selected child's badge are shown. [focusZone]
  /// (the focused parent) is drawn last, above child badges.
  ///
  /// Each badge is anchored at its zone point, counter-rotated upright,
  /// nudged by `offsetX/offsetY` along the SCREEN axes, then scaled by
  /// [inverseScale] so it keeps its on-screen size (touch target included)
  /// at any zoom.
  Widget _buildBadges(
    List<MapZone> zones,
    MapZone? focusZone,
    double rotationRadians,
    Size logicalSize,
    double labelScale, {
    required bool showChildren,
    required double inverseScale,
  }) {
    Widget badge(MapZone zone, {required bool isActive}) {
      final isMajor = isMajorMapZone(widget.data, zone);
      return Positioned(
        left: logicalSize.width * zone.x / 100,
        top: logicalSize.height * zone.y / 100,
        child: FractionalTranslation(
          translation: const Offset(-0.5, -0.5),
          child: Transform.rotate(
            angle: -rotationRadians,
            // Upright (screen-aligned) frame from here on.
            child: Transform.translate(
              offset: Offset(zone.offsetX, zone.offsetY),
              child: Transform.scale(
                scale: inverseScale,
                child: _MapZoneLabel(
                  zone: zone,
                  isMajor: isMajor,
                  isActive: isActive,
                  isOtherParent:
                      isMajor && zone.code != widget.selectedParentZone,
                  scale: labelScale,
                  onTap: widget.onZoneTap,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        for (final zone in zones)
          if (showChildren ||
              zone.code == widget.selectedChildZone ||
              isMajorMapZone(widget.data, zone))
            badge(
              zone,
              isActive:
                  zone.code == widget.selectedChildZone ||
                  (widget.selectedChildZone == null &&
                      zone.code == widget.selectedParentZone),
            ),
        // Focused parent badge last, so it sits above child badges and
        // outlines; solid (active) unless a child is selected.
        if (focusZone != null)
          badge(focusZone, isActive: widget.selectedChildZone == null),
      ],
    );
  }
}

/// White wash over the floor drawing: [imageFade] everywhere, or the
/// combined `1 − (1 − imageFade)(1 − spotlightFade)` while [focused]; always
/// except [hole] (the selected parent polygon, even-odd fill), which keeps
/// the original drawing. A white wash, not Opacity, so the dark card
/// background never greys the drawing.
class _FadePainter extends CustomPainter {
  final MapArea? hole;
  final double imageFade;
  final double spotlightFade;
  final bool focused;

  const _FadePainter({
    required this.hole,
    required this.imageFade,
    required this.spotlightFade,
    required this.focused,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final alpha = focused
        ? 1 - (1 - imageFade) * (1 - spotlightFade)
        : imageFade;
    if (alpha <= 0) return;
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size);
    final hole = this.hole;
    if (hole != null && hole.points.isNotEmpty) {
      path.addPath(mapAreaPath(hole, size), Offset.zero);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: alpha)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _FadePainter oldDelegate) {
    return !identical(oldDelegate.hole, hole) ||
        oldDelegate.imageFade != imageFade ||
        oldDelegate.spotlightFade != spotlightFade ||
        oldDelegate.focused != focused;
  }
}

/// Child sub-area outlines, drawn above the parent layer. The selected
/// child is the highlight target (glow + 3px select-blue outline, faint
/// fill when [raised]); the selected parent's other children are purple;
/// with [raised] (full floor) other parents' children are thin dashed grey
/// lines. Repaints only when an input changes.
class _ChildAreaPainter extends CustomPainter {
  final List<MapArea> areas;
  final String? selectedChildZone;
  final String? selectedParentZone;
  final bool raised;

  const _ChildAreaPainter({
    required this.areas,
    this.selectedChildZone,
    this.selectedParentZone,
    this.raised = false,
  });

  static const Color _childPurple = Color(0xFFD63AF9);
  static const Color _dashGrey = Color(0xFF94A3B8);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = _childPurple
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeJoin = StrokeJoin.round;
    final dash = Paint()
      ..color = _dashGrey
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    MapArea? selected;
    for (final area in areas) {
      if (area.points.isEmpty) continue;
      if (area.code == selectedChildZone) {
        // Drawn last so its outline sits above neighbours.
        selected = area;
        continue;
      }
      final path = mapAreaPath(area, size);
      final parent = area.code.substring(0, area.code.lastIndexOf('-'));
      if (raised && parent != selectedParentZone) {
        canvas.drawPath(dashedPath(path), dash);
      } else {
        canvas.drawPath(path, stroke);
      }
    }

    if (selected == null) return;
    paintSelectedTarget(canvas, mapAreaPath(selected, size), fill: raised);
  }

  @override
  bool shouldRepaint(covariant _ChildAreaPainter oldDelegate) {
    return !identical(oldDelegate.areas, areas) ||
        oldDelegate.selectedChildZone != selectedChildZone ||
        oldDelegate.selectedParentZone != selectedParentZone ||
        oldDelegate.raised != raised;
  }
}

/// Zone code on a compact badge. Selected (the highlight target): solid
/// select-blue with a white border and a 1px outer ring. The selected
/// parent while one of its children is selected: white with select-blue
/// text/border. Other parents: neutral grey. Children: purple.
class _MapZoneLabel extends StatelessWidget {
  final MapZone zone;
  final bool isMajor;
  final bool isActive;

  /// A parent other than the selected one: neutral grey style.
  final bool isOtherParent;
  final ValueChanged<MapZone>? onTap;

  /// Multiplier for font size and padding (0.8–1.0, from the map size).
  final double scale;

  const _MapZoneLabel({
    required this.zone,
    required this.isMajor,
    required this.isActive,
    required this.onTap,
    this.isOtherParent = false,
    this.scale = 1,
  });

  static const Color _otherParentText = Color(0xFF334155);
  static const Color _otherParentBorder = Color(0xFFCBD5E1);
  static const Color _childBorder = Color(0xFFD63AF9);
  static const Color _childText = Color(0xFFC026D3);

  static const double _activeBorderWidth = 1.5;
  static const double _minTouchHeight = 24;
  static const Duration _transition = Duration(milliseconds: 120);

  /// Invisible horizontal touch padding on each side of the badge.
  static const double touchPaddingX = 3;

  @override
  Widget build(BuildContext context) {
    final otherParent = isOtherParent && !isActive;
    final textColor = isActive
        ? Colors.white
        : otherParent
        ? _otherParentText
        : (isMajor ? mapSelectColor : _childText);
    final borderColor = isActive
        ? Colors.white
        : otherParent
        ? _otherParentBorder
        : (isMajor ? mapSelectColor : _childBorder);
    final fillColor = isActive
        ? mapSelectColor
        : Colors.white.withValues(
            alpha: otherParent ? 0.95 : (isMajor ? 0.92 : 0.90),
          );
    final borderWidth = isActive ? _activeBorderWidth : (isMajor ? 1.2 : 1.0);
    // Base padding minus the extra border width, so the badge's outer size
    // (and its centred anchor) stays the same when it becomes active.
    final restBorderWidth = isMajor ? 1.2 : 1.0;
    final borderDelta = borderWidth - restBorderWidth;
    final padding = EdgeInsets.symmetric(
      horizontal: (isMajor ? 6.0 : 4.0) * scale - borderDelta,
      vertical: (isMajor ? 2.5 : 1.5) * scale - borderDelta,
    );

    final badge = AnimatedContainer(
      duration: _transition,
      padding: padding,
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(isMajor ? 4 : 3),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: <BoxShadow>[
          // Selected: 1px outer ring in the select colour, drawn outside the
          // box so layout is unchanged; separates the white border from the
          // drawing underneath.
          BoxShadow(
            color: isActive
                ? mapSelectColor
                : mapSelectColor.withValues(alpha: 0),
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
            color: textColor,
            fontSize: (isMajor ? 10.5 : 9.5) * scale,
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
      padding: const EdgeInsets.symmetric(horizontal: touchPaddingX),
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
