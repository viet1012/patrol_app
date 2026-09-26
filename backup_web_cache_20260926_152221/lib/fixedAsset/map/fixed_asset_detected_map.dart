import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'floor_map_data.dart';
import 'floor_map_models.dart';
import 'floor_map_widget.dart';

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

  const FixedAssetDetectedMap({
    super.key,
    this.fac,
    this.floor,
    this.positionA,
    this.positionAA,
    this.enableZoom = true,
    this.enablePolygonAnimation = true,
    this.onZoneTap,
  });

  @override
  State<FixedAssetDetectedMap> createState() => _FixedAssetDetectedMapState();
}

class _FixedAssetDetectedMapState extends State<FixedAssetDetectedMap> {
  /// UI-only: embedded map body hidden, header kept. Survives location
  /// changes (new scans update the header but never force it open).
  bool _collapsed = false;

  static const Duration _collapseDuration = Duration(milliseconds: 260);

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
        final narrow = cardWidth < 600;
        // Edge-to-edge inside the 1 px card border; the card's own clip
        // handles the rounded corners, so no inner map padding is needed.
        const cardBorderWidth = 1.0;
        // Mobile cap scales with screen height so tall-ish floors (e.g.
        // Warehouse, ~1.18:1) still fit the full width on common phones.
        final heightCap = narrow
            ? (viewport.height * 0.42).clamp(300.0, 350.0).toDouble()
            : 460.0;
        // Full card width; height follows the rendered (rotated) aspect and
        // only shrinks the width when the height cap is hit.
        final availableWidth = math.max(0.0, cardWidth - 2 * cardBorderWidth);
        final aspectRatio = floorMapDisplayAspectRatio(selection.map);
        final height = math.min(heightCap, availableWidth / aspectRatio);
        final width = height * aspectRatio;
        final zoneText = selection.childZoneCode ?? selection.parentZoneCode;

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
                      enableZoom: widget.enableZoom,
                      // Hidden map: stop the highlight ticker (no wasted
                      // frames); it resumes when shown again.
                      enablePolygonAnimation:
                          widget.enablePolygonAnimation && !_collapsed,
                      onZoneTap: widget.onZoneTap,
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
  ) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog.fullscreen(
          backgroundColor: const Color(0xFF121826),
          child: _ExpandedMapView(
            selection: selection,
            enablePolygonAnimation: widget.enablePolygonAnimation,
            onZoneTap: widget.onZoneTap,
            onClose: () => Navigator.of(dialogContext).pop(),
          ),
        );
      },
    );
  }
}

/// Fullscreen inspection view. Defaults to the focused parent context
/// (parent polygon + `parent-*` badges, viewport fitted to the parent);
/// "Show all" switches to the whole floor at fit-all scale.
class _ExpandedMapView extends StatefulWidget {
  final FixedAssetMapSelection selection;
  final bool enablePolygonAnimation;
  final ValueChanged<MapZone>? onZoneTap;
  final VoidCallback onClose;

  const _ExpandedMapView({
    required this.selection,
    required this.enablePolygonAnimation,
    required this.onZoneTap,
    required this.onClose,
  });

  @override
  State<_ExpandedMapView> createState() => _ExpandedMapViewState();
}

class _ExpandedMapViewState extends State<_ExpandedMapView> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final selection = widget.selection;
    return SafeArea(
      child: Column(
        children: <Widget>[
          _MapHeader(
            title: selection.map.title,
            zoneText: selection.childZoneCode ?? selection.parentZoneCode,
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
  final VoidCallback? onExpand;
  final VoidCallback? onClose;
  final bool showAll;
  final VoidCallback? onToggleShowAll;
  final bool collapsed;
  final VoidCallback? onToggleCollapsed;

  const _MapHeader({
    required this.title,
    required this.zoneText,
    this.onExpand,
    this.onClose,
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
                child: Text(
                  zoneText!,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Color(0xFF67E8F9),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
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
