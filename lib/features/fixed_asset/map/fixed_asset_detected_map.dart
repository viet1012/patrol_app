import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import 'package:chuphinh/core/models/fixed_asset_zone_progress.dart';
import 'package:chuphinh/features/fixed_asset/map/floor_map_data.dart';
import 'package:chuphinh/features/fixed_asset/map/floor_map_models.dart';
import 'package:chuphinh/features/fixed_asset/map/floor_map_widget.dart';

class FixedAssetDetectedMap extends StatefulWidget {
  final String? fac;
  final String? floor;
  final String? positionA;
  final String? positionAA;
  final bool enableZoom;

  /// Traveling highlight on the selected polygon (embedded + expanded).
  /// False gives the cheaper static highlight.
  final bool enablePolygonAnimation;
  final ValueChanged<MapZone>? onZoneTap;

  /// Called when the fullscreen dialog is opened (e.g. to refresh data).
  final VoidCallback? onExpand;

  /// Audited / total per zone code of this floor. Null = code-only badges.
  final Map<String, ZoneProgress>? zoneProgress;

  const FixedAssetDetectedMap({
    super.key,
    this.fac,
    this.floor,
    this.positionA,
    this.positionAA,
    this.enableZoom = true,
    this.enablePolygonAnimation = true,
    this.onZoneTap,
    this.onExpand,
    this.zoneProgress,
  });

  @override
  State<FixedAssetDetectedMap> createState() => _FixedAssetDetectedMapState();
}

class _FixedAssetDetectedMapState extends State<FixedAssetDetectedMap> {
  /// UI-only: embedded map body hidden, header kept. Survives location
  /// changes (new scans update the header but never force it open).
  bool _collapsed = false;

  /// Fullscreen dialog is open: the card underneath stops its highlight so
  /// only one animation runs at a time.
  bool _expanded = false;

  static const Duration _collapseDuration = Duration(milliseconds: 260);

  /// Latest [FixedAssetDetectedMap.zoneProgress], so an open dialog (built
  /// once) follows reloads too.
  late final ValueNotifier<Map<String, ZoneProgress>?> _zoneProgress =
      ValueNotifier<Map<String, ZoneProgress>?>(widget.zoneProgress);

  @override
  void didUpdateWidget(covariant FixedAssetDetectedMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    _zoneProgress.value = widget.zoneProgress;
  }

  @override
  void dispose() {
    _zoneProgress.dispose();
    super.dispose();
  }

  /// Parent bounding-box / floor area below which the card auto-zooms.
  static const double _autoZoomAreaRatio = 0.25;

  @override
  Widget build(BuildContext context) {
    final selection = resolveFixedAssetMapSelection(
      fac: widget.fac,
      floor: widget.floor,
      positionA: widget.positionA,
      positionAA: widget.positionAA,
    );
    if (selection == null) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = MediaQuery.sizeOf(context);
        final viewportWidth = viewport.width;
        final cardWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : viewportWidth;
        // Edge-to-edge inside the 1 px card border; the card's own clip
        // handles the rounded corners, so no inner map padding is needed.
        const cardBorderWidth = 1.0;
        // Always the full card width, height from the rendered (rotated)
        // aspect: the drawing fills the card with no side bands.
        final width = math.max(0.0, cardWidth - 2 * cardBorderWidth);
        final aspectRatio = floorMapDisplayAspectRatio(selection.map);
        final height = width / aspectRatio;
        final zoneText = selection.childZoneCode ?? selection.parentZoneCode;
        // Small parents (bounds < 25% of the floor) start zoomed in; larger
        // ones keep the full-card view.
        final parentRatio = floorMapAreaBoundsRatio(
          selection.map,
          selection.parentZoneCode,
        );
        final zoomToParent =
            parentRatio != null && parentRatio < _autoZoomAreaRatio;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.14),
              width: cardBorderWidth,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _MapHeader(
                title: selection.map.title,
                zoneText: zoneText,
                progress: widget.zoneProgress?[zoneText],
                onExpand: () => _showExpandedMap(context, selection),
                collapsed: _collapsed,
                onToggleCollapsed: () =>
                    setState(() => _collapsed = !_collapsed),
              ),
              // The map stays mounted while collapsed (height animates to 0),
              // so its zoom/pan state and selection survive the toggle.
              ClipRect(
                child: AnimatedAlign(
                  alignment: Alignment.topCenter,
                  heightFactor: _collapsed ? 0 : 1,
                  duration: _collapseDuration,
                  curve: Curves.easeInOutCubic,
                  child: SizedBox(
                    width: width,
                    height: height,
                    child: FloorMapWidget(
                      data: selection.map,
                      selectedParentZone: selection.parentZoneCode,
                      selectedChildZone: selection.childZoneCode,
                      // Embedded view shows only the resolved parent context;
                      // the expanded dialog keeps the full floor.
                      focusParentZone: selection.parentZoneCode,
                      // Fitted once per map/parent; manual pan/zoom kept.
                      autoFocusParent: zoomToParent,
                      focusPadding: 0.35,
                      enableZoom: widget.enableZoom,
                      // Hidden map, or covered by the dialog: stop the
                      // highlight ticker (no wasted frames); it resumes
                      // when shown again.
                      enablePolygonAnimation:
                          widget.enablePolygonAnimation &&
                          !_collapsed &&
                          !_expanded,
                      onZoneTap: widget.onZoneTap,
                      imageFade: 0.40,
                      spotlightFade: 0.30,
                      zoneProgress: widget.zoneProgress,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showExpandedMap(
    BuildContext context,
    FixedAssetMapSelection selection,
  ) async {
    setState(() => _expanded = true);
    widget.onExpand?.call();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog.fullscreen(
          backgroundColor: const Color(0xFF121826),
          child: _ExpandedMapView(
            selection: selection,
            zoneProgress: _zoneProgress,
            enablePolygonAnimation: widget.enablePolygonAnimation,
            onZoneTap: widget.onZoneTap,
            onClose: () => Navigator.of(dialogContext).pop(),
          ),
        );
      },
    );
    if (mounted) setState(() => _expanded = false);
  }
}

/// Fullscreen inspection view. Defaults to the focused parent context
/// (parent polygon + `parent-*` badges, viewport fitted to the parent);
/// "Show all" switches to the whole floor at fit-all scale.
class _ExpandedMapView extends StatefulWidget {
  final FixedAssetMapSelection selection;
  final ValueListenable<Map<String, ZoneProgress>?> zoneProgress;
  final bool enablePolygonAnimation;
  final ValueChanged<MapZone>? onZoneTap;
  final VoidCallback onClose;

  const _ExpandedMapView({
    required this.selection,
    required this.zoneProgress,
    required this.enablePolygonAnimation,
    required this.onZoneTap,
    required this.onClose,
  });

  @override
  State<_ExpandedMapView> createState() => _ExpandedMapViewState();
}

class _ExpandedMapViewState extends State<_ExpandedMapView> {
  bool _showAll = false;

  /// Faded drawing + spotlight; dialog-local, reopening starts faded.
  bool _faded = true;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, ZoneProgress>?>(
      valueListenable: widget.zoneProgress,
      builder: (context, zoneProgress, _) => _build(context, zoneProgress),
    );
  }

  Widget _build(
    BuildContext context,
    Map<String, ZoneProgress>? zoneProgress,
  ) {
    final selection = widget.selection;
    final zoneText = selection.childZoneCode ?? selection.parentZoneCode;
    return SafeArea(
      child: Column(
        children: <Widget>[
          _MapHeader(
            title: selection.map.title,
            zoneText: zoneText,
            progress: zoneProgress?[zoneText],
            faded: _faded,
            onToggleFaded: () => setState(() => _faded = !_faded),
            showAll: _showAll,
            onToggleShowAll: () => setState(() => _showAll = !_showAll),
            onClose: widget.onClose,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: ColoredBox(
                  color: Colors.white.withValues(alpha: 0.04),
                  // Viewport spans all remaining space; the floor is centred
                  // inside and the initial zoom frames the parent polygon.
                  child: SizedBox.expand(
                    child: FloorMapWidget(
                      data: selection.map,
                      selectedParentZone: selection.parentZoneCode,
                      selectedChildZone: selection.childZoneCode,
                      focusParentZone: _showAll
                          ? null
                          : selection.parentZoneCode,
                      autoFocusParent: !_showAll,
                      maxScale: 8,
                      enableZoom: true,
                      enablePolygonAnimation: widget.enablePolygonAnimation,
                      onZoneTap: widget.onZoneTap,
                      // Show all: heavier wash zoomed out (0.68), lighter
                      // once zoomed in (0.50); focus keeps 0.50.
                      imageFade: _faded ? (_showAll ? 0.68 : 0.50) : 0,
                      zoomedInImageFade: _faded && _showAll ? 0.50 : null,
                      // Spotlight needs a focus parent, so "Show all" turns
                      // it off on its own.
                      spotlightFade: _faded ? 0.30 : 0,
                      // Same orientation as the card (data rotation only);
                      // the user zooms/pans by hand.
                      extraRotationDeg: 0,
                      zoneProgress: zoneProgress,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapHeader extends StatelessWidget {
  final String title;
  final String? zoneText;

  /// Progress of the target zone (selected child, else parent): shown as a
  /// small `audited/total máy · %` line under [zoneText].
  final ZoneProgress? progress;
  final VoidCallback? onExpand;
  final VoidCallback? onClose;
  final bool faded;
  final VoidCallback? onToggleFaded;
  final bool showAll;
  final VoidCallback? onToggleShowAll;
  final bool collapsed;
  final VoidCallback? onToggleCollapsed;

  const _MapHeader({
    required this.title,
    required this.zoneText,
    this.progress,
    this.onExpand,
    this.onClose,
    this.faded = false,
    this.onToggleFaded,
    this.showAll = false,
    this.onToggleShowAll,
    this.collapsed = false,
    this.onToggleCollapsed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: Padding(
        padding: const EdgeInsets.only(left: 10),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'LAYOUT',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.52),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
            if (zoneText?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      zoneText!,
                      maxLines: 1,
                      style: const TextStyle(
                        color: Color(0xFF67E8F9),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (progress != null && progress!.total > 0)
                      Text(
                        '${progress!.audited}/${progress!.total} máy · '
                        '${progress!.percent}%',
                        maxLines: 1,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 11,
                          height: 1.1,
                        ),
                      ),
                  ],
                ),
              ),
            if (onToggleFaded != null)
              _HeaderAction(
                tooltip: faded ? 'Show original' : 'Fade drawing',
                icon: Icons.contrast_rounded,
                onPressed: onToggleFaded,
              ),
            if (onToggleShowAll != null)
              _HeaderAction(
                tooltip: showAll ? 'Focus selected area' : 'Show all',
                icon: showAll
                    ? Icons.center_focus_strong_rounded
                    : Icons.layers_rounded,
                onPressed: onToggleShowAll,
              ),
            _HeaderAction(
              tooltip: onClose == null ? 'Expand map' : 'Close map',
              icon: onClose == null
                  ? Icons.open_in_full_rounded
                  : Icons.close_rounded,
              onPressed: onClose ?? onExpand,
            ),
            if (onToggleCollapsed != null)
              _HeaderAction(
                tooltip: collapsed ? 'Show map' : 'Hide map',
                icon: collapsed
                    ? Icons.keyboard_arrow_down_rounded
                    : Icons.keyboard_arrow_up_rounded,
                onPressed: onToggleCollapsed,
              ),
          ],
        ),
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  const _HeaderAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: 42,
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          color: Colors.white70,
          splashRadius: 20,
        ),
      ),
    );
  }
}
